FROM python:3.12-slim

ARG REPO_PATH="unison-network-vpn"
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools iproute2 iptables ca-certificates iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY ${REPO_PATH}/requirements.txt ./requirements.txt
COPY ${REPO_PATH}/constraints.txt ./constraints.txt
RUN pip install --no-cache-dir -c ./constraints.txt -r requirements.txt

COPY ${REPO_PATH}/src ./src
COPY ${REPO_PATH}/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONPATH=/app/src \
    VPN_HEALTH_PORT=8084 \
    WIREGUARD_INTERFACE=wg0

EXPOSE 8084
CMD ["/entrypoint.sh"]
