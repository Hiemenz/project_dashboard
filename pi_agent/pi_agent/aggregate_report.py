"""Builds the single combined status page from every Pi's latest snapshot.

Run once a day, after all Pis have uploaded (see pi-aggregate.timer), on the
one Pi designated as the aggregator. Reads reports/<hostname>/latest.json for
every hostname under reports/ in the bucket, renders one HTML page, and
uploads it to reports/index.html. If the bucket has static website hosting
enabled, that page is reachable at the bucket's website endpoint.

A Pi is flagged stale if its latest snapshot is older than STALE_HOURS -
that's the main signal something has gone wrong (agent crashed, Pi is off,
network down) since nobody is watching this passively.
"""
import html
import os
from datetime import datetime, timezone

import boto3
from dotenv import load_dotenv

load_dotenv()

REPORT_BUCKET = os.environ.get("PI_REPORT_BUCKET")
STALE_HOURS = float(os.environ.get("PI_REPORT_STALE_HOURS", "36"))


def list_hostnames(s3) -> list[str]:
    paginator = s3.get_paginator("list_objects_v2")
    hostnames = set()
    for page in paginator.paginate(Bucket=REPORT_BUCKET, Prefix="reports/", Delimiter="/"):
        for prefix in page.get("CommonPrefixes", []):
            # prefix looks like "reports/<hostname>/"
            hostname = prefix["Prefix"].split("/")[1]
            hostnames.add(hostname)
    return sorted(hostnames)


def fetch_latest(s3, hostname: str) -> dict | None:
    import json

    try:
        obj = s3.get_object(Bucket=REPORT_BUCKET, Key=f"reports/{hostname}/latest.json")
        return json.loads(obj["Body"].read())
    except s3.exceptions.NoSuchKey:
        return None


def format_bytes(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"


def render_html(snapshots: list[dict]) -> str:
    now = datetime.now(timezone.utc)
    rows = []
    for snap in snapshots:
        hostname = html.escape(str(snap.get("hostname", "unknown")))
        generated_at = snap.get("generated_at")
        age_hours = None
        stale = False
        if generated_at:
            age_hours = (now - datetime.fromisoformat(generated_at)).total_seconds() / 3600
            stale = age_hours > STALE_HOURS

        row_class = "stale" if stale else "ok"
        temp = snap.get("cpu_temp_c")
        mem = snap.get("memory", {})
        disk = snap.get("disk", {})

        rows.append(f"""
        <tr class="{row_class}">
          <td>{hostname}{' <span class="badge">STALE</span>' if stale else ''}</td>
          <td>{age_hours:.1f}h ago</td>
          <td>{snap.get('cpu_percent', '-')}%</td>
          <td>{temp if temp is not None else '-'}&deg;C</td>
          <td>{mem.get('percent', '-')}% ({format_bytes(mem.get('used', 0))} / {format_bytes(mem.get('total', 0))})</td>
          <td>{disk.get('percent', '-')}% ({format_bytes(disk.get('used', 0))} / {format_bytes(disk.get('total', 0))})</td>
        </tr>""")

    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Pi Fleet Report</title>
<style>
  body {{ font-family: system-ui, sans-serif; margin: 2rem; background: #111; color: #eee; }}
  h1 {{ font-size: 1.3rem; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ text-align: left; padding: 0.5rem 1rem; border-bottom: 1px solid #333; }}
  tr.stale {{ background: #3a1a1a; }}
  .badge {{ background: #a33; color: #fff; padding: 0.1rem 0.4rem; border-radius: 4px; font-size: 0.75rem; }}
  .meta {{ color: #888; font-size: 0.85rem; margin-bottom: 1rem; }}
</style>
</head>
<body>
  <h1>Pi Fleet Daily Report</h1>
  <div class="meta">Generated {now.isoformat()}</div>
  <table>
    <tr><th>Host</th><th>Last report</th><th>CPU</th><th>Temp</th><th>Memory</th><th>Disk</th></tr>
    {''.join(rows) if rows else '<tr><td colspan="6">No reports found.</td></tr>'}
  </table>
</body>
</html>
"""


def main():
    if not REPORT_BUCKET:
        raise RuntimeError(
            "PI_REPORT_BUCKET is not set. Add it to .env (see .env.example)."
        )

    s3 = boto3.client("s3")
    hostnames = list_hostnames(s3)
    snapshots = [s for s in (fetch_latest(s3, h) for h in hostnames) if s is not None]

    page = render_html(snapshots)
    s3.put_object(
        Bucket=REPORT_BUCKET,
        Key="reports/index.html",
        Body=page.encode("utf-8"),
        ContentType="text/html",
    )
    print(f"Published report for {len(snapshots)} host(s) to s3://{REPORT_BUCKET}/reports/index.html")


if __name__ == "__main__":
    main()
