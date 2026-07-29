import os
import time

import psutil
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException

load_dotenv()

AUTH_TOKEN = os.environ.get("PI_AGENT_TOKEN")
if not AUTH_TOKEN:
    raise RuntimeError(
        "PI_AGENT_TOKEN is not set. Create a .env file (see .env.example) "
        "with a long random token before starting the agent."
    )

app = FastAPI(title="pi-agent")

_boot_time = psutil.boot_time()


def require_token(authorization: str = Header(default="")):
    expected = f"Bearer {AUTH_TOKEN}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Invalid or missing token")


def read_cpu_temp_c() -> float | None:
    # Standard Raspberry Pi OS thermal zone path.
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            return round(int(f.read().strip()) / 1000, 1)
    except (FileNotFoundError, ValueError):
        pass
    temps = psutil.sensors_temperatures() if hasattr(psutil, "sensors_temperatures") else {}
    for entries in temps.values():
        if entries:
            return round(entries[0].current, 1)
    return None


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/stats", dependencies=[Depends(require_token)])
def stats():
    cpu_percent = psutil.cpu_percent(interval=0.3)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    load1, load5, load15 = os.getloadavg()

    return {
        "hostname": os.uname().nodename,
        "timestamp": time.time(),
        "uptime_seconds": time.time() - _boot_time,
        "cpu_percent": cpu_percent,
        "cpu_count": psutil.cpu_count(),
        "load_avg": {"1m": load1, "5m": load5, "15m": load15},
        "cpu_temp_c": read_cpu_temp_c(),
        "memory": {
            "total": mem.total,
            "used": mem.used,
            "available": mem.available,
            "percent": mem.percent,
        },
        "disk": {
            "total": disk.total,
            "used": disk.used,
            "free": disk.free,
            "percent": disk.percent,
        },
    }


@app.get("/processes", dependencies=[Depends(require_token)])
def processes(limit: int = 50, sort_by: str = "cpu"):
    procs = []
    for p in psutil.process_iter(
        ["pid", "name", "username", "status", "cpu_percent", "memory_percent"]
    ):
        info = p.info
        procs.append(
            {
                "pid": info["pid"],
                "name": info["name"],
                "user": info["username"],
                "status": info["status"],
                "cpu_percent": info["cpu_percent"] or 0.0,
                "memory_percent": round(info["memory_percent"] or 0.0, 2),
            }
        )

    key = "memory_percent" if sort_by == "memory" else "cpu_percent"
    procs.sort(key=lambda x: x[key], reverse=True)
    return {"count": len(procs), "processes": procs[:limit]}
