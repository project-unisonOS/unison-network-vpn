from __future__ import annotations

import asyncio
import os
import subprocess
import time
from typing import Dict, Optional

import httpx
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel

INTERFACE = os.getenv("WIREGUARD_INTERFACE", "wg0")
VPN_HEALTH_PORT = int(os.getenv("VPN_HEALTH_PORT", "8084"))
VPN_IP_ECHO_URL = os.getenv("VPN_IP_ECHO_URL")
HANDSHAKE_TTL = int(os.getenv("VPN_READY_HANDSHAKE_TTL", "180"))
REQUIRE_VPN = os.getenv("WIREGUARD_REQUIRED", "true").lower() == "true"

app = FastAPI(title="unison-network-vpn", version="0.1.0")


class VpnStatus(BaseModel):
    interface: str
    interface_up: bool
    latest_handshake: Optional[int] = None
    exit_ip: Optional[str] = None
    config_path: Optional[str] = None
    ready: bool = False


def _wg_quick_status() -> Dict[str, str]:
    try:
        out = subprocess.check_output(["wg", "show", INTERFACE], text=True, stderr=subprocess.STDOUT)
        return {"output": out}
    except subprocess.CalledProcessError as exc:
        return {"output": exc.output}
    except FileNotFoundError:
        return {"output": ""}


def _latest_handshake() -> Optional[int]:
    try:
        out = subprocess.check_output(
            ["bash", "-c", f"wg show {INTERFACE} latest-handshakes | awk '{{print $2}}'"], text=True
        )
        out = out.strip()
        if not out:
            return None
        # wg prints seconds since epoch; zero means no handshake
        value = int(out.splitlines()[0])
        return value if value > 0 else None
    except Exception:
        return None


async def _egress_ip() -> Optional[str]:
    if not VPN_IP_ECHO_URL:
        return None
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(VPN_IP_ECHO_URL)
            resp.raise_for_status()
            return resp.text.strip()
    except Exception:
        return None


def _interface_up() -> bool:
    try:
        subprocess.check_call(["ip", "link", "show", INTERFACE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False


async def current_status(include_ip: bool = False) -> VpnStatus:
    latest = _latest_handshake()
    interface_up = _interface_up()
    exit_ip = await _egress_ip() if include_ip else None
    config_path = os.getenv("WIREGUARD_CONFIG_PATH", f"/etc/wireguard/{INTERFACE}.conf")
    ready = (interface_up and latest is not None and (int(time.time()) - latest) < HANDSHAKE_TTL) or not REQUIRE_VPN
    return VpnStatus(
        interface=INTERFACE,
        interface_up=interface_up,
        latest_handshake=latest,
        exit_ip=exit_ip,
        config_path=config_path if os.path.exists(config_path) else None,
        ready=ready,
    )


@app.get("/healthz")
async def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.get("/readyz")
async def ready() -> JSONResponse:
    status = await current_status(include_ip=False)
    content = {"ready": status.ready, "interface": status.interface, "interface_up": status.interface_up}
    return JSONResponse(status_code=200, content=content)


@app.get("/status", response_model=VpnStatus)
async def status() -> VpnStatus:
    return await current_status(include_ip=False)


@app.get("/ip")
async def ip() -> Dict[str, Optional[str]]:
    exit_ip = await current_status(include_ip=True)
    return {"exit_ip": exit_ip.exit_ip}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=VPN_HEALTH_PORT, reload=False)
