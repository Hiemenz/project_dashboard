"""Uploads one daily stats snapshot for this Pi to S3.

Run once a day (see pi-report.timer). Reads system stats the same way
main.py's /stats endpoint does, then writes:
  s3://<bucket>/reports/<hostname>/<YYYY-MM-DD>.json
  s3://<bucket>/reports/<hostname>/latest.json   (overwritten each run)
"""
import json
import os
import socket
import time
from datetime import datetime, timezone

import boto3
import psutil
from dotenv import load_dotenv

load_dotenv()

REPORT_BUCKET = os.environ.get("PI_REPORT_BUCKET")
REPORT_HOSTNAME = os.environ.get("PI_REPORT_HOSTNAME") or socket.gethostname()


def read_cpu_temp_c() -> float | None:
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


def collect_snapshot() -> dict:
    cpu_percent = psutil.cpu_percent(interval=0.3)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    load1, load5, load15 = os.getloadavg()

    return {
        "hostname": REPORT_HOSTNAME,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": time.time() - psutil.boot_time(),
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


def main():
    if not REPORT_BUCKET:
        raise RuntimeError(
            "PI_REPORT_BUCKET is not set. Add it to .env (see .env.example)."
        )

    snapshot = collect_snapshot()
    body = json.dumps(snapshot, indent=2).encode("utf-8")
    today = datetime.now(timezone.utc).date().isoformat()

    s3 = boto3.client("s3")
    for key in (f"reports/{REPORT_HOSTNAME}/{today}.json", f"reports/{REPORT_HOSTNAME}/latest.json"):
        s3.put_object(Bucket=REPORT_BUCKET, Key=key, Body=body, ContentType="application/json")

    print(f"Uploaded snapshot for {REPORT_HOSTNAME} to s3://{REPORT_BUCKET}/reports/{REPORT_HOSTNAME}/")


if __name__ == "__main__":
    main()
