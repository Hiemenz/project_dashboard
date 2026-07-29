# Pi Dashboard

Monitor CPU, memory, disk, temperature, and running processes on your
Raspberry Pis from a Flutter app, including from outside your home network —
no port forwarding required.

Two pieces:

- **`pi_agent/`** — a small FastAPI service that runs on each Raspberry Pi
  and exposes system stats over HTTP, protected by a bearer token.
- **`pi_dashboard/`** — the Flutter app (phone/desktop/web) that talks to
  each Pi's agent and shows a live dashboard.

Remote access is handled by **Tailscale**: it puts your phone and every Pi
on the same private mesh network over WireGuard, so the app can reach
`http://100.x.x.x:8765` from anywhere with internet, without exposing
anything to the public internet or configuring your router.

## 1. Set up Tailscale

On each Raspberry Pi:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

On your phone, install the Tailscale app from the App/Play Store and log
into the same Tailscale account/network.

Once both are connected, run `tailscale ip -4` on each Pi to get its stable
`100.x.x.x` address — that's what the Flutter app will connect to.

## 2. Install the agent on each Pi

```bash
# on the Pi
git clone <this-repo> ~/pi_dashboard_src   # or copy the pi_agent/ folder over
cd ~/pi_dashboard_src/pi_agent

curl -sSL https://install.python-poetry.org | python3 -
poetry install

cp .env.example .env
# put a real secret in .env — generate one with:
openssl rand -hex 32
# then edit .env and set PI_AGENT_TOKEN=<that value>
```

Use a **different token per Pi** so you can revoke one without affecting
the others.

Run it manually to test:

```bash
poetry run uvicorn pi_agent.main:app --host 0.0.0.0 --port 8765
```

From your Mac, confirm it's reachable:

```bash
curl http://<pi-tailscale-ip>:8765/health
curl -H "Authorization: Bearer <token>" http://<pi-tailscale-ip>:8765/stats
```

### Run it on boot (systemd)

```bash
# adjust User/paths in pi-agent.service if your username/home differ
sudo cp pi-agent.service /etc/systemd/system/pi-agent.service
sudo systemctl daemon-reload
sudo systemctl enable --now pi-agent
sudo systemctl status pi-agent
```

Repeat steps 2 for every Pi you want to monitor.

## 3. Run the Flutter app

```bash
cd pi_dashboard
flutter pub get
flutter run   # pick your phone, or Chrome, or macOS
```

In the app, tap **Add Pi** for each Raspberry Pi and enter:

- **Name** — whatever you want to call it (e.g. "media-pi")
- **Agent URL** — `http://<tailscale-ip>:8765`
- **Auth token** — the token you put in that Pi's `.env`

The dashboard list refreshes every 10s; the per-Pi detail screen (tap a
Pi) refreshes every 5s and shows CPU/mem/disk/temp plus the top processes
sorted by CPU or memory.

To install on your phone: connect it via USB and run `flutter run -d
<device-id>` (see `flutter devices`), or build a release APK/IPA with
`flutter build apk` / `flutter build ios`.

## 4. Daily fleet report (S3)

On top of the live dashboard, each Pi can upload one stats snapshot a day to
S3, and one designated Pi builds a single combined status page from all of
them and publishes it as a plain webpage — useful for a quick "is everything
still alive" check without opening the app.

### 4.1 Create the bucket and IAM policies (once)

```bash
aws s3api create-bucket --bucket your-pi-reports-bucket --region us-east-1
```

Keep the bucket private overall — raw per-Pi JSON snapshots aren't meant to
be public. Give each Pi write-only access to just its own folder:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::your-pi-reports-bucket/reports/<hostname>/*"
  }]
}
```

The aggregator Pi needs broader access — list/read everything under
`reports/`, plus write the combined page:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::your-pi-reports-bucket",
      "Condition": {"StringLike": {"s3:prefix": "reports/*"}}
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::your-pi-reports-bucket/reports/*"
    }
  ]
}
```

Create an IAM user per role above (or per Pi), generate access keys, and put
them in each Pi's environment (`~/.aws/credentials` via `aws configure`, or
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in `.env`) — `boto3` picks either
up automatically.

Only the combined report should be public. Turn on static website hosting
and scope public read to that one object, not the whole bucket:

```bash
aws s3api put-bucket-website --bucket your-pi-reports-bucket \
  --website-configuration '{"IndexDocument": {"Suffix": "index.html"}}'
aws s3api put-public-access-block --bucket your-pi-reports-bucket \
  --public-access-block-configuration BlockPublicPolicy=false,RestrictPublicBuckets=false,BlockPublicAcls=true,IgnorePublicAcls=true
```

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::your-pi-reports-bucket/reports/index.html"
  }]
}
```

Apply it with `aws s3api put-bucket-policy --bucket your-pi-reports-bucket
--policy file://policy.json`. The page will then be reachable at
`http://your-pi-reports-bucket.s3-website-<region>.amazonaws.com/reports/index.html`
(HTTP only — put CloudFront in front if you want HTTPS).

### 4.2 Set up every Pi

Add `PI_REPORT_BUCKET` (and AWS credentials) to each Pi's `.env` — see
`.env.example`. Then install and enable the snapshot timer:

```bash
sudo cp pi-report.service pi-report.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pi-report.timer
```

Test it immediately rather than waiting for 06:00:

```bash
sudo systemctl start pi-report.service
sudo journalctl -u pi-report.service -n 20
```

### 4.3 Set up the aggregator (one Pi only)

Pick one Pi to be the aggregator (any one that's reliably on). It needs the
broader IAM policy from 4.1. Install its timer too:

```bash
sudo cp pi-aggregate.service pi-aggregate.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pi-aggregate.timer
sudo systemctl start pi-aggregate.service   # test now
```

It runs at 06:20, 20 minutes after the per-Pi snapshot timers, so every Pi
has had a chance to upload first.

## Notes / next steps

- Process `cpu_percent` from `psutil` needs two samples to be accurate —
  the very first `/processes` call after the agent starts may show 0%
  for everything; it self-corrects within a few seconds.
- The agent binds to `0.0.0.0:8765` but is only reachable over the
  Tailscale interface in practice, since nothing forwards that port from
  your router. Don't expose 8765 to the public internet.
- If you'd rather not install Tailscale, the alternative is a WireGuard
  server you run yourself, or an SSH reverse tunnel — both need more
  manual setup and certificate/key management than Tailscale's zero-config
  mesh.
- The combined S3 report (`reports/index.html`) is publicly reachable to
  anyone with the URL — there's no auth on S3 static website hosting. It
  only contains CPU/mem/disk/temp numbers, no hostnames-as-secrets or
  process lists, but don't share the URL if you'd rather it stayed private;
  swap the public bucket policy for presigned URLs if that matters to you.
- A Pi shows as `STALE` on the combined report if its last snapshot is
  older than `PI_REPORT_STALE_HOURS` (default 36h) — that's the signal an
  agent crashed, the Pi is off, or it lost network before its daily upload.
