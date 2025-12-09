FROM debian:12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools iproute2 iptables python3 python3-pip ca-certificates iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY unison-network-vpn/requirements.txt ./requirements.txt
COPY unison-network-vpn/constraints.txt ./constraints.txt
RUN pip install --no-cache-dir -c ./constraints.txt -r requirements.txt

COPY unison-network-vpn/src ./src
COPY unison-network-vpn/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONPATH=/app/src \
    VPN_HEALTH_PORT=8084 \
    WIREGUARD_INTERFACE=wg0 \
    PIP_BREAK_SYSTEM_PACKAGES=1

EXPOSE 8084
CMD ["/entrypoint.sh"]
