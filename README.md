# Astroarch Interface

> **Full remote control of an AstroArch astronomical observatory from your Android smartphone.**
> Mobile-friendly clone of KStars/Ekos with all the essential features for an astrophotography session.

[![Version](https://img.shields.io/badge/version-0.2.14-f5a623?style=flat-square)](https://github.com/Johannes1979I/astroarch-interface/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Android-8.0%2B-green?style=flat-square&logo=android)](#)
[![Backend](https://img.shields.io/badge/Backend-Python%203.11%2B-blue?style=flat-square&logo=python)](#)

**Author**: Zarletti-Osservatorio Jupiter
**Targets**: AstroArch (Arch Linux ARM) on Raspberry Pi 5 + Android smartphone

---

## What it is

Astroarch Interface consists of two parts:

| | |
|---|---|
| 🖥️ **Backend** (`backend/astroarch_bridge`) | A Python daemon (FastAPI + WebSocket) installed on the Raspberry Pi 5. It connects to the INDI server, PHD2 and Ekos via DBus, exposing a REST API + two WebSocket streams. **Zero changes** to the existing Ekos setup. |
| 📱 **Android app** (`android_app`) | A Flutter app with 14 dedicated screens, one for each Ekos module cloned for mobile use. Communicates with the backend over Tailscale. |

The app **does NOT replace Ekos**: it works alongside it. Ekos keeps running on the AstroArch desktop, the app reads its state via DBus and INDI and sends commands that Ekos executes as usual. When Ekos captures an image, the app receives it in real time via INDI BLOB intercept (parallel client, non-invasive).

---

## Full feature list

### 📊 Dashboard
- Live connection status (INDI · PHD2 · WebSocket state · WebSocket frames)
- Active target coordinates (RA/Dec) with mount status
- **Last frame preview** auto-stretched, with HFR and star count
- 4 live cards: Mount tracking · Camera temp/cooler · Guide RMS · Focuser pos
- Observatory telemetry: weather, dome, weather-safe flag

### 🔭 Mount
- Live RA/Dec coordinates streamed via WebSocket
- **Built-in SIMBAD search** (type "M 31" → automatic RA/Dec via astropy)
- One-tap GoTo + Track / Slew / Sync
- Manual N/S/E/W slew joypad with rate selection (Guide / Centering / Find / Max)
- Park / Unpark / Sync / Emergency Stop
- Tracking mode chips: Sidereal / Lunar / Solar / Off
- Pier side, accuracy, settle time

### 🎯 Align (Plate Solve + Polar Align)
**Plate Solve** — exact clone of the Ekos Align module:
- Live FITS preview (pinch-zoom) **stretched identically to Ekos** (ZScale + asinh MTF algorithm)
- Configurable Exposure, Gain, Binning — applied to the camera before the solve
- Solver action: GoTo / Sync / Slew to target / Nothing
- Solver mode: StellarSolver / Remote (INDI)
- Live telescope coordinates + solution (RA · DEC · Err · PA · Pixel scale · FOV · Focal length · F-ratio)
- History of recent solves with color-coded dRA/dDEC errors (green<50″, yellow<150″, red beyond)
- **Target plot** Ekos-style with concentric 50/100/150″ rings
- Expandable Ekos Align log

**Polar Align** — drift-based 3-step routine:
- Capture + plate-solve at 3 different RA positions
- AZ/ALT error computation from Dec drift
- Suggested screw adjustments

### 📷 Capture (Ekos-style)
- **Persistent multi-job sequencer** — full Ekos model
- Each job has: filter, count, exposure, gain, offset, binning, frame type, transfer format (FITS/NATIVE/XISF), capture format (RAW/RGB), delay, dither flag, target name
- Drag-and-drop reorderable job list, edit/duplicate/remove
- **Save/Load JSON presets** locally (e.g. "M31 LRGB night 1")
- 3 execution modes:
  - ⭐ **FULL OBSERVATION** — 10-stage pre-flight pipeline (resolve target → slew → tracking → plate solve → sync → autofocus → guide calibrate → guide start → capture)
  - **VIA EKOS** — jobs are loaded into the Ekos Capture queue via DBus + start
  - **DIRECT** — straight INDI driver commands (Ekos bypassed)

### 🎯 Guide (PHD2)
- Live RMS Total · SNR · RMS RA · RMS DEC
- RA/DEC tracking error chart (last 120 samples)
- Buttons: Start / Stop / Dither / Find Star / Calibrate / Clear cal / Pause
- PHD2 equipment info (version, pixel scale, calibrated, settling)

### 🎛️ Focus
- Manual movement ±10/100/1000 steps
- Absolute position numeric field
- **Iterative autofocus** on the bridge: N steps × ±step_size, exposure, HFR computation, find minimum, move to best
- **Live V-curve plot** with colored points and vertical line on the best position

### 🌡️ Cooler
- ON/OFF toggle with visual state (green when ON, neutral when OFF)
- Editable target temperature, live sensor reading
- Cooler power % bar
- Stuck-driver detection (e.g. ToupTek toupbase) with **RECONNECT DRIVER** button to recover

### 🌐 Observatory
- Weather card with all parameters (temp, humidity, wind, sky)
- Dome shutter open/close (handles both standard DOME_SHUTTER and DOME_PARK scripting/roll-off)
- Dust cap park/unpark
- Flat panel toggle + 0-255 intensity slider
- Candidate drivers with inline CONNECT/DISCONNECT buttons

### 📅 Scheduler
- Sky-state card with twilight phase (day/civil/nautical/astronomical/night)
- Live sun/moon altitude (lat/lon auto-detected from the mount via INDI)
- Persistent multi-target job list
- **+ NEW JOB** form with automatic SIMBAD resolution
- Live condition checks (twilight required, target altitude, weather safe)

### ⚙️ Setup / Profiles
- Reads Ekos profiles from `~/.local/share/kstars/userdb.sqlite`
- Active INDI driver list with Connect/Disconnect toggle

### 🎛️ INDI Panel
**Exact clone** of the KStars/Ekos INDI Control Panel:
- List of all connected devices
- Tap a device → all its properties grouped by Group
- Switch / Number / Text editable in real time
- Light read-only with colored state
- Live two-way propagation (you change here → Ekos sees it; you change in Ekos → you see it here)

### 📁 Files
- FITS browser for `~/Pictures/Ekos/`
- Recent files list with auto-stretched thumbnails
- Tap → fullscreen preview with pinch-zoom
- **Multi-select** via long-press
- **Batch delete** with confirmation (frees space on the RPi without occupying your phone)
- RPi storage card: colored GB used/total bar, FITS count

### 📈 Analyze
- Session counters: WS events, total properties, devices
- Last frame info (object, filter, exposure, HFR, stars, size)
- Historical PHD2 RMS chart (RA/DEC)
- INDI message stream

### 🔬 Activity Log
- **Every API call** the app makes to the backend, with millisecond timestamp, color-coded status code, duration, body
- Tap for details + copy → very fast debugging

---

## Architecture

```
       Android app                 Tailscale (WireGuard)         Raspberry Pi 5 (AstroArch)
   ┌─────────────────┐                                       ┌──────────────────────────────┐
   │                 │ ─────HTTPS / WSS───────────────────► │  astroarch-bridge :8765      │
   │  Astroarch      │                                       │   ├─ REST   /api/*           │
   │  Interface      │ ◄────── live snapshots ──────────── │   ├─ WS     /ws/state        │
   │  (Flutter)      │                                       │   └─ WS     /ws/frames       │
   │                 │                                       │                              │
   │  14 screens     │                                       │   ┌─ INDI client TCP :7624  │
   │  Provider       │                                       │   │  + enableBLOB (parallel │
   │  WebSocket      │                                       │   │    to Ekos, no impact)  │
   │                 │                                       │   ├─ PHD2 client TCP :4400  │
   │                 │                                       │   ├─ Ekos via DBus          │
   └─────────────────┘                                       │   └─ FITS watcher           │
                                                             │                              │
                                                             │  KStars/Ekos (untouched)     │
                                                             │  PHD2 (untouched)            │
                                                             │  ~/Pictures/Ekos/            │
                                                             └──────────────────────────────┘
```

**Key design choice**: the bridge is a *secondary INDI client* that does not modify Ekos's setup. It receives the camera BLOBs via `enableBLOB Also` in parallel with Ekos, processes them in memory, and forwards them to the app — **zero files written to disk**, **zero interference** with Ekos's workflow.

---

## Installation

See [DEPLOY.md](DEPLOY.md) for full instructions.

**Quick start**:

```bash
# 1. On the Raspberry Pi
scp -r backend/ astronaut@RPI_IP:/tmp/
ssh astronaut@RPI_IP
cd /tmp/backend
sudo bash deploy/install.sh --user astronaut
# prints URL and token

# 2. Download the APK from the GitHub Releases page and install it on the phone
# https://github.com/Johannes1979I/astroarch-interface/releases/latest

# 3. Open the app, tap "SCAN QR FROM DASHBOARD" and frame the QR shown on the AstroArch desktop
#    (or enter host/port/token manually)
```

---

## Documentation

- 📄 [User manual PDF](AstroarchInterface_Manual.pdf) — complete printable guide (13 pages)
- 🔧 [DEPLOY.md](DEPLOY.md) — step-by-step installation
- 🎨 [mockups.html](mockups.html) — UI preview (open in a browser)

---

## Tech stack

| | |
|---|---|
| **Backend** | Python 3.11+, FastAPI, uvicorn, WebSocket, asyncio |
| | astropy (FITS, SIMBAD, AltAz), Pillow, numpy, watchdog |
| | Custom incremental INDI XML protocol parser |
| | PHD2 JSON-RPC, Ekos DBus (qdbus6) |
| **App** | Flutter 3.32 / Dart 3.5 |
| | provider, http, web_socket_channel, fl_chart, mobile_scanner |
| **Deploy** | systemd user service, install.sh, optional PKGBUILD |
| **Connectivity** | Tailscale (WireGuard) — no router port forwarding required |

---

## Known limitations

- iOS not supported (Android only, by design)
- Plate solving requires `solve-field` (astrometry.net) installed on the RPi
- Polar align is a simplified drift-based routine (3 steps); not a replacement for tools like SharpCap Polar Align

---

## Roadmap

- [ ] Mosaic planner
- [ ] Push notifications (frame done, sequence finished, weather alert)
- [ ] Possible upstream contribution to the [devDucks/astroarch](https://github.com/devDucks/astroarch) project

---

## License

[MIT](LICENSE) — feel free to use, modify, distribute. Please keep the attribution to Zarletti-Osservatorio Jupiter.

---

## Credits

- **AstroArch** — ArchLinux ARM distribution for astrophotography [github.com/devDucks/astroarch](https://github.com/devDucks/astroarch)
- **KStars / Ekos** — the de-facto open source astrophotography suite [edu.kde.org/kstars](https://edu.kde.org/kstars/)
- **PHD2** — autoguider [openphdguiding.org](https://openphdguiding.org/)
- **astrometry.net** — offline plate solving [astrometry.net](https://astrometry.net/)

---

🌙 **Clear skies!** — Zarletti-Osservatorio Jupiter
