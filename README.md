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
