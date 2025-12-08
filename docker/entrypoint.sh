#!/usr/bin/env bash
set -euo pipefail

INTERFACE="${WIREGUARD_INTERFACE:-wg0}"
CONFIG_PATH="${WIREGUARD_CONFIG_PATH:-/etc/wireguard/${INTERFACE}.conf}"
CONFIG_B64="${WIREGUARD_CONFIG_B64:-}"
WIREGUARD_REQUIRED="${WIREGUARD_REQUIRED:-true}"
ENFORCE_IPV6="${ENFORCE_IPV6:-true}"

mkdir -p /etc/wireguard
if [[ -n "$CONFIG_B64" ]]; then
  echo "$CONFIG_B64" | base64 -d > "$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH"
fi

if [[ -f "$CONFIG_PATH" ]]; then
  echo "[vpn] bringing up WireGuard interface $INTERFACE"
  wg-quick up "$INTERFACE"
else
  echo "[vpn] WARNING: no WireGuard config found at $CONFIG_PATH; running without VPN" >&2
fi

if [[ "${WIREGUARD_REQUIRED,,}" == "true" && -f "$CONFIG_PATH" ]]; then
  ENDPOINT_HOST=$(grep -m1 '^Endpoint' "$CONFIG_PATH" | awk '{print $3}' | cut -d':' -f1 || true)
  ENDPOINT_PORT=$(grep -m1 '^Endpoint' "$CONFIG_PATH" | awk '{print $3}' | cut -d':' -f2 || true)
  echo "[vpn] enforcing fail-closed egress (allow loopback, WireGuard, and endpoint ${ENDPOINT_HOST}:${ENDPOINT_PORT})"
  iptables -P OUTPUT DROP
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A OUTPUT -o "$INTERFACE" -j ACCEPT
  if [[ -n "$ENDPOINT_HOST" && -n "$ENDPOINT_PORT" ]]; then
    ENDPOINT_IP=$(getent ahostsv4 "$ENDPOINT_HOST" | awk '{print $1}' | head -n1 || true)
    if [[ -n "$ENDPOINT_IP" ]]; then
      iptables -A OUTPUT -p udp -d "$ENDPOINT_IP" --dport "$ENDPOINT_PORT" -j ACCEPT
    fi
  fi
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  if [[ "${ENFORCE_IPV6,,}" == "true" ]]; then
    ip6tables -P OUTPUT DROP || true
    ip6tables -A OUTPUT -o lo -j ACCEPT || true
    ip6tables -A OUTPUT -o "$INTERFACE" -j ACCEPT || true
    ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
  fi
fi

exec python -m src.main
