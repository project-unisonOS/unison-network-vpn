FROM debian:12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools iproute2 iptables python3 python3-pip ca-certificates iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./requirements.txt
COPY constraints.txt ./constraints.txt
RUN pip install --no-cache-dir -c ./constraints.txt -r requirements.txt

COPY src ./src
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONPATH=/app/src \
    VPN_HEALTH_PORT=8084 \
    WIREGUARD_INTERFACE=wg0

EXPOSE 8084
CMD ["/entrypoint.sh"]
