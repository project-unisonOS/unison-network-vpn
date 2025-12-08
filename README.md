# unison-network-vpn

WireGuard-based VPN sidecar for Unison VDI workloads. Provides a small FastAPI control plane for health/status and hosts the network namespace that `unison-agent-vdi` shares for fail-closed egress.

## Features
- Boots a WireGuard interface from a mounted config or base64 env (`WIREGUARD_CONFIG_B64`).
- Optional fail-closed egress when `WIREGUARD_REQUIRED=true` (drops non-VPN traffic except handshake + loopback).
- Health endpoints: `/healthz`, `/readyz`, `/status`, `/ip`.

## Run locally
```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -c ../constraints.txt -r requirements.txt
WIREGUARD_CONFIG_B64=$(base64 -w0 ./wg0.conf) \
WIREGUARD_REQUIRED=true \
python -m src.main
```

## Environment
- `WIREGUARD_INTERFACE` (default `wg0`)
- `WIREGUARD_CONFIG_PATH` (default `/etc/wireguard/${WIREGUARD_INTERFACE}.conf`)
- `WIREGUARD_CONFIG_B64` (optional inline config)
- `WIREGUARD_REQUIRED` (default `true`) — drop non-VPN egress when enabled.
- `VPN_HEALTH_PORT` (default `8084`)
- `VPN_IP_ECHO_URL` (optional IP echo endpoint, e.g. `https://api.ipify.org`)
- `VPN_READY_HANDSHAKE_TTL` (seconds, default `180`)

## Docker
```bash
docker build -t unison-network-vpn .
docker run --cap-add=NET_ADMIN --device=/dev/net/tun -p 8084:8084 \
  -e WIREGUARD_CONFIG_B64=... \
  unison-network-vpn
```
