"""Generate the Astroarch Interface user manual PDF (English).

Author: Zarletti-Osservatorio Jupiter
"""
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                 PageBreak, Table, TableStyle,
                                 ListFlowable, ListItem)
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from datetime import datetime

OUTPUT = r"C:/Users/Zarletti/Desktop/AstroArch_Mobile/AstroarchInterface_Manual.pdf"

# Palette
ACCENT = colors.HexColor("#c98612")
ACCENT_LIGHT = colors.HexColor("#f5a623")
TEXT_DARK = colors.HexColor("#1a1d24")
MUTED = colors.HexColor("#6b7280")
PANEL = colors.HexColor("#f6f7fa")
LINE = colors.HexColor("#e0e3e8")
OK = colors.HexColor("#1f8b62")
ERR = colors.HexColor("#b3303f")

styles = getSampleStyleSheet()


def make_styles():
    styles.add(ParagraphStyle(
        name="DocTitle", fontSize=28, leading=32, alignment=TA_CENTER,
        textColor=TEXT_DARK, spaceAfter=8, fontName="Helvetica-Bold"))
    styles.add(ParagraphStyle(
        name="DocSubtitle", fontSize=14, leading=18, alignment=TA_CENTER,
        textColor=MUTED, spaceAfter=4, fontName="Helvetica"))
    styles.add(ParagraphStyle(
        name="ChapterTitle", fontSize=20, leading=26, textColor=ACCENT,
        spaceBefore=18, spaceAfter=10, fontName="Helvetica-Bold",
        borderPadding=(0, 0, 6, 0)))
    styles.add(ParagraphStyle(
        name="SectionTitle", fontSize=14, leading=18, textColor=TEXT_DARK,
        spaceBefore=12, spaceAfter=6, fontName="Helvetica-Bold"))
    styles.add(ParagraphStyle(
        name="SubSection", fontSize=12, leading=15, textColor=ACCENT,
        spaceBefore=8, spaceAfter=4, fontName="Helvetica-Bold"))
    styles.add(ParagraphStyle(
        name="Body", fontSize=10, leading=14, textColor=TEXT_DARK,
        alignment=TA_JUSTIFY, spaceAfter=6, fontName="Helvetica"))
    styles.add(ParagraphStyle(
        name="Mono", fontSize=9, leading=12, textColor=TEXT_DARK,
        fontName="Courier", backColor=PANEL, borderColor=LINE,
        borderWidth=0.5, borderPadding=6, spaceAfter=8))
    styles.add(ParagraphStyle(
        name="Note", fontSize=9.5, leading=13, textColor=TEXT_DARK,
        backColor=colors.HexColor("#fff7e6"),
        borderColor=ACCENT_LIGHT, borderWidth=0.6, borderPadding=8,
        leftIndent=0, rightIndent=0, spaceBefore=6, spaceAfter=8,
        fontName="Helvetica"))
    styles.add(ParagraphStyle(
        name="Warning", fontSize=9.5, leading=13, textColor=TEXT_DARK,
        backColor=colors.HexColor("#fff0f3"),
        borderColor=ERR, borderWidth=0.6, borderPadding=8,
        leftIndent=0, rightIndent=0, spaceBefore=6, spaceAfter=8,
        fontName="Helvetica"))


def page_layout(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(2 * cm, 1 * cm, "Astroarch Interface - User Manual")
    canvas.drawCentredString(w / 2, 1 * cm, "Zarletti-Osservatorio Jupiter")
    canvas.drawRightString(w - 2 * cm, 1 * cm, f"Page {doc.page}")
    if doc.page > 1:
        canvas.setStrokeColor(LINE)
        canvas.line(2 * cm, h - 1.5 * cm, w - 2 * cm, h - 1.5 * cm)
        canvas.setFont("Helvetica-Bold", 8)
        canvas.setFillColor(ACCENT)
        canvas.drawString(2 * cm, h - 1.2 * cm, "ASTROARCH INTERFACE")
        canvas.setFillColor(MUTED)
        canvas.setFont("Helvetica", 8)
        canvas.drawRightString(w - 2 * cm, h - 1.2 * cm, "v0.2.14")
    canvas.restoreState()


def cover_layout(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setFillColor(colors.HexColor("#0a0d12"))
    canvas.rect(0, 0, w, h, stroke=0, fill=1)
    canvas.setFillColor(ACCENT_LIGHT)
    canvas.rect(0, h - 0.8 * cm, w, 0.8 * cm, stroke=0, fill=1)
    canvas.setFont("Helvetica-Bold", 38)
    canvas.setFillColor(colors.white)
    canvas.drawCentredString(w / 2, h - 6 * cm, "Astroarch")
    canvas.setFillColor(ACCENT_LIGHT)
    canvas.drawCentredString(w / 2, h - 7.5 * cm, "Interface")
    canvas.setFont("Helvetica", 14)
    canvas.setFillColor(colors.HexColor("#8a93a6"))
    canvas.drawCentredString(w / 2, h - 9 * cm,
                              "Remote control of an AstroArch observatory from Android")
    canvas.setStrokeColor(ACCENT_LIGHT)
    canvas.setLineWidth(2)
    canvas.circle(w / 2, h - 13 * cm, 1.8 * cm, stroke=1, fill=0)
    canvas.setFont("Helvetica-Bold", 28)
    canvas.setFillColor(ACCENT_LIGHT)
    canvas.drawCentredString(w / 2, h - 13.4 * cm, "*")
    canvas.setFont("Helvetica", 11)
    canvas.setFillColor(colors.HexColor("#e6eaf2"))
    canvas.drawCentredString(w / 2, 4 * cm, "User Manual & Installation Guide")
    canvas.setFont("Helvetica", 10)
    canvas.setFillColor(colors.HexColor("#8a93a6"))
    canvas.drawCentredString(w / 2, 3.3 * cm, "Version 0.2.14")
    canvas.drawCentredString(w / 2, 2.7 * cm, "Author: Zarletti-Osservatorio Jupiter")
    canvas.drawCentredString(w / 2, 2.1 * cm,
                              datetime.now().strftime("%B %d, %Y"))
    canvas.setFillColor(ACCENT_LIGHT)
    canvas.rect(0, 0, w, 0.8 * cm, stroke=0, fill=1)
    canvas.restoreState()


make_styles()


def H1(t): return Paragraph(t, styles["ChapterTitle"])
def H2(t): return Paragraph(t, styles["SectionTitle"])
def H3(t): return Paragraph(t, styles["SubSection"])
def P(t): return Paragraph(t, styles["Body"])
def CODE(t):
    safe = t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    safe = safe.replace("\n", "<br/>")
    return Paragraph(f'<font face="Courier">{safe}</font>', styles["Mono"])
def NOTE(t): return Paragraph(f"<b>Note:</b> {t}", styles["Note"])
def WARN(t): return Paragraph(f"<b>Warning:</b> {t}", styles["Warning"])


def kv_table(rows, widths=None):
    widths = widths or [4 * cm, 12 * cm]
    t = Table(rows, colWidths=widths, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), PANEL),
        ("TEXTCOLOR", (0, 0), (0, -1), MUTED),
        ("FONT", (0, 0), (0, -1), "Helvetica-Bold", 9),
        ("FONT", (1, 0), (1, -1), "Helvetica", 9.5),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LINEBELOW", (0, 0), (-1, -2), 0.5, LINE),
        ("BOX", (0, 0), (-1, -1), 0.5, LINE),
    ]))
    return t


def grid_table(header, rows, col_widths=None):
    data = [header] + rows
    t = Table(data, colWidths=col_widths, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), ACCENT_LIGHT),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#1a1305")),
        ("FONT", (0, 0), (-1, 0), "Helvetica-Bold", 9),
        ("FONT", (0, 1), (-1, -1), "Helvetica", 9),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, LINE),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PANEL]),
        ("BOX", (0, 0), (-1, -1), 0.5, LINE),
    ]))
    return t


# ============================================================================
# DOCUMENT
# ============================================================================

story = []

# Cover
story.append(Spacer(1, 24 * cm))
story.append(PageBreak())

# 1. INTRODUCTION
story.append(H1("1. Introduction"))
story.append(P(
    "<b>Astroarch Interface</b> is an Android application that lets you fully "
    "control an astronomical observatory based on the <b>AstroArch</b> "
    "distribution (Arch Linux for Raspberry Pi with KStars/Ekos/INDI) running "
    "on a Raspberry Pi 5. The app connects to the Raspberry Pi via Tailscale "
    "and mirrors all Ekos features in real time using a mobile-friendly UI."))
story.append(P("The project is split in two parts:"))
story.append(ListFlowable([
    ListItem(P("<b>astroarch-bridge backend</b>: a Python daemon (FastAPI + "
               "WebSocket) installed on the Raspberry Pi 5. It talks to the "
               "INDI server, PHD2 and Ekos via DBus, exposing a REST API + "
               "two WebSocket streams to the app.")),
    ListItem(P("<b>Android app</b>: written in Flutter, with 14 dedicated "
               "screens covering all the Ekos modules cloned for mobile use.")),
], bulletType="bullet", leftIndent=20))

story.append(H2("1.1 What you can do"))
story.append(ListFlowable([
    ListItem(P("Real-time view of mount, camera, focuser, filter wheel, "
               "dome and weather state (live telemetry over WebSocket)")),
    ListItem(P("Plan and run multi-job capture sequences just like in Ekos")),
    ListItem(P("Run a full pre-flight pipeline: slew → plate solve → "
               "sync → guide → autofocus → capture, in one tap")),
    ListItem(P("Search objects by name (SIMBAD) and GoTo with one tap")),
    ListItem(P("Control PHD2 (calibration, guiding, dither) with a live RMS chart")),
    ListItem(P("Control the focuser manually or trigger an iterative autofocus "
               "with a live V-curve plot")),
    ListItem(P("Run plate solving via solve-field/astrometry.net and sync the "
               "mount on the result")),
    ListItem(P("View captured images live (FITS auto-stretched to JPEG over WebSocket)")),
    ListItem(P("Edit any INDI property from the panel that clones the Ekos "
               "INDI Control Panel")),
    ListItem(P("Plan scheduler jobs with twilight/altitude/weather conditions")),
], bulletType="bullet", leftIndent=20))

story.append(H2("1.2 Architecture"))
story.append(P("High-level data flow:"))
story.append(CODE(
    "Android app  --Tailscale (WireGuard)-->  Raspberry Pi 5\n"
    "                                          |- astroarch-bridge :8765\n"
    "                                          |   |- REST  /api/*\n"
    "                                          |   |- WS    /ws/state  (live clone)\n"
    "                                          |   |- WS    /ws/frames (JPEG live)\n"
    "                                          |- INDI server :7624\n"
    "                                          |- PHD2 :4400 (JSON-RPC)\n"
    "                                          |- KStars/Ekos (DBus)\n"
    "                                          |- ~/Pictures/Ekos (FITS storage)"))
story.append(NOTE("Tailscale provides end-to-end WireGuard encryption. There is "
                  "no need to set up HTTPS on top: port 8765 is exposed in "
                  "cleartext but the Tailscale tunnel makes the traffic "
                  "inaccessible to anyone outside your tailnet."))

story.append(PageBreak())

# 2. INSTALLATION
story.append(H1("2. Installation"))

story.append(H2("2.1 Prerequisites"))
story.append(P("On the Raspberry Pi (server side):"))
story.append(ListFlowable([
    ListItem(P("AstroArch (Arch Linux for Raspberry Pi) distribution")),
    ListItem(P("Python 3.11+ with pip")),
    ListItem(P("Tailscale installed and active")),
    ListItem(P("KStars/Ekos installed with a configured INDI profile")),
    ListItem(P("PHD2 installed (optional, for guiding)")),
    ListItem(P("astrometry.net + index files in <font face='Courier'>"
               "~/.local/share/kstars/astrometry/</font> (optional, for plate solving)")),
], bulletType="bullet", leftIndent=20))
story.append(P("On the Android phone (client side):"))
story.append(ListFlowable([
    ListItem(P("Android 8.0 (API 26) or later")),
    ListItem(P("Tailscale app installed and connected to the same tailnet as the Raspberry Pi")),
    ListItem(P("~50 MB of free space")),
], bulletType="bullet", leftIndent=20))

story.append(H2("2.2 Backend installation on the Raspberry Pi"))
story.append(H3("Step 1 - Transfer the backend"))
story.append(P("From the computer where you have the <i>backend/</i> folder of the "
               "Astroarch Interface distribution:"))
story.append(CODE("scp -r backend/ astronaut@100.74.22.40:/tmp/"))
story.append(P("(Replace <font face='Courier'>100.74.22.40</font> with the "
               "Tailscale IP of your Raspberry Pi)"))

story.append(H3("Step 2 - Install the service"))
story.append(P("SSH into the Raspberry Pi and run:"))
story.append(CODE("ssh astronaut@100.74.22.40\n"
                  "cd /tmp/backend\n"
                  "sudo bash deploy/install.sh --user astronaut"))
story.append(P("The installer:"))
story.append(ListFlowable([
    ListItem(P("Creates/uses the specified user (default: <i>astroarch</i>; "
               "pass <font face='Courier'>--user astronaut</font> to use your own)")),
    ListItem(P("Installs the Python dependencies (FastAPI, uvicorn, astropy, "
               "Pillow, watchdog, pydantic, websockets, numpy)")),
    ListItem(P("Installs the <font face='Courier'>astroarch_bridge</font> package")),
    ListItem(P("Creates the <font face='Courier'>astroarch-bridge.service</font> "
               "systemd unit")),
    ListItem(P("Enables auto-start on boot")),
    ListItem(P("Starts the daemon")),
], bulletType="bullet", leftIndent=20))
story.append(P("At the end the script prints the URL and the auto-generated "
               "<b>Bearer token</b>. Save it: you will need it to connect from the app."))
story.append(CODE("==> astroarch-bridge installed and running\n"
                  "    URL:   http://100.74.22.40:8765\n"
                  "    Token: kJ3xSn9mZ7TqW...   (example)"))

story.append(H3("Step 3 - Verify the service"))
story.append(CODE("systemctl --user status astroarch-bridge\n"
                  "journalctl --user -u astroarch-bridge -f\n"
                  "curl http://localhost:8765/healthz"))
story.append(P("The healthz output should show:"))
story.append(CODE('{"ok":true,"version":"0.1.0","indi":"...","phd2":"..."}'))

story.append(H2("2.3 Desktop dashboard installation"))
story.append(P("A small Tk dashboard is installed on the AstroArch desktop to "
               "monitor the bridge state and generate the QR code for the app:"))
story.append(CODE("scp -r desktop_dashboard/ astronaut@100.74.22.40:/home/astronaut/astroarch-bridge-dashboard\n"
                  "scp desktop_dashboard/AstroarchBridge.desktop \\\n"
                  "    astronaut@100.74.22.40:/home/astronaut/Desktop/\n"
                  "ssh astronaut@100.74.22.40 'chmod +x ~/Desktop/AstroarchBridge.desktop'"))
story.append(P("On the AstroArch desktop you will see the <b>Astroarch Bridge</b> "
               "icon. It opens a window with service status, Ekos info, "
               "URL/Token, a QR code for the app, and Connect/Disconnect buttons."))

story.append(H2("2.4 APK installation on Android"))
story.append(P("On the phone:"))
story.append(ListFlowable([
    ListItem(P("Transfer the <font face='Courier'>"
               "AstroarchInterface-v0.2.14.apk</font> file to the phone "
               "(USB / Drive / Tailscale Drop)")),
    ListItem(P("Open the file from the file manager. Android will ask you to "
               'enable "Install apps from unknown sources" for the file '
               "manager: confirm.")),
    ListItem(P("Tap <b>Install</b> → the app shows up in the launcher as "
               '<b>"Astroarch Interface"</b>')),
], bulletType="bullet", leftIndent=20))

story.append(H2("2.5 First connection"))
story.append(P("Open the app:"))
story.append(ListFlowable([
    ListItem(P("Tap <b>SCAN QR FROM DASHBOARD</b> and frame the QR code shown "
               "on the desktop dashboard of the Raspberry Pi: host, port and "
               "token will be filled in automatically.")),
    ListItem(P("Or fill them in manually:")),
], bulletType="bullet", leftIndent=20))
story.append(kv_table([
    ["HOST", "Tailscale IP of the Raspberry Pi (e.g. 100.74.22.40)"],
    ["PORT", "8765"],
    ["TOKEN", "The one printed by the installer or read with cat ~/.config/astroarch-bridge/token"],
]))
story.append(P("Tap <b>CONNECT</b>. If the connection works you go straight to "
               "the Dashboard. If it fails, tap <b>TEST</b> for step-by-step diagnostics."))

story.append(WARN("If the connection fails with a timeout, make sure Tailscale "
                  "is active on the phone. Some Android devices (Xiaomi/MIUI, "
                  "OnePlus, Samsung) need battery optimization disabled for "
                  "Tailscale, otherwise the VPN gets killed in the background."))

story.append(PageBreak())

# 3. MAIN SCREENS
story.append(H1("3. Main screens"))
story.append(P("The app uses a 5-tab <b>bottom navigation</b> always visible "
               "(Dashboard, Mount, Align, Capture, Guide) and a <b>side drawer</b> "
               "with the advanced screens, opened from the menu icon in the AppBar."))

story.append(H2("3.1 Dashboard"))
story.append(P("The first screen after login. Shows in real time:"))
story.append(ListFlowable([
    ListItem(P("<b>Connection banner</b> at the top with INDI / PHD2 / WS "
               "state / WS frames (green=ok, yellow=connecting, red=fail)")),
    ListItem(P("<b>Active target</b> with RA/Dec coordinates and mount status")),
    ListItem(P("<b>Last captured image preview</b> auto-stretched, tap for "
               "full-screen Live View")),
    ListItem(P("4 status cards: Mount (tracking), Camera (temperature), Guide "
               "(PHD2 RMS), Focuser (position)")),
    ListItem(P("Observatory telemetry: weather, dome, weather safe")),
], bulletType="bullet", leftIndent=20))

story.append(H2("3.2 Mount"))
story.append(P("Full telescope control:"))
story.append(ListFlowable([
    ListItem(P("<b>Live RA/Dec</b> updated in real time, pier side, current "
               "mount status")),
    ListItem(P("<b>SIMBAD search</b>: type a name (M 31, NGC 7000, Vega) and "
               "tap SEARCH. RA/Dec resolved via astropy. Buttons: GOTO+TRACK "
               "/ SLEW / SYNC")),
    ListItem(P("<b>Manual GoTo</b> with RA (hours) and Dec (degrees) fields")),
    ListItem(P("<b>N/S/E/W slew joypad</b> with rate selection "
               "(GUIDE / CENTERING / FIND / MAX depending on the driver)")),
    ListItem(P("Quick Park/Unpark/Sync/Stop")),
    ListItem(P("<b>Tracking mode</b> chips: Sidereal / Lunar / Solar / Off")),
], bulletType="bullet", leftIndent=20))

story.append(H2("3.3 Align (Plate Solve + Polar Align)"))
story.append(P("<b>Plate Solve</b> tab — exact clone of Ekos Align:"))
story.append(ListFlowable([
    ListItem(P("Live FITS preview (pinch zoom) <b>stretched identically to Ekos</b>")),
    ListItem(P("Configurable Exposure / Gain / Binning, applied to the camera "
               "before the solve")),
    ListItem(P("Solver action chips: GoTo / Sync / Slew to target / Nothing")),
    ListItem(P("Solver mode chips: StellarSolver / Remote (INDI)")),
    ListItem(P("Live telescope coordinates and solution: RA, DEC, Err, PA, "
               "Pixel scale, FOV, Focal length, F-ratio")),
    ListItem(P("Solve history with color-coded dRA/dDEC (green<50\", yellow<150\", red beyond)")),
    ListItem(P("Ekos-style target plot with concentric 50/100/150\" rings")),
    ListItem(P("Expandable Ekos Align log")),
], bulletType="bullet", leftIndent=20))

story.append(P("<b>Polar Align</b> tab — drift-based 3-step routine:"))
story.append(ListFlowable([
    ListItem(P("Capture + plate solve at 3 different RA positions")),
    ListItem(P("AZ/ALT error computation from Dec drift")),
    ListItem(P("Suggested screw adjustments")),
], bulletType="bullet", leftIndent=20))

story.append(H2("3.4 Capture"))
story.append(P("Multi-job sequencer in Ekos style:"))
story.append(ListFlowable([
    ListItem(P("<b>Cooler panel</b> with live sensor temperature, editable "
               "target, power % bar, visual ON/OFF toggle (green when ON), "
               "and a RECONNECT DRIVER button for stuck driver recovery (e.g. ToupTek)")),
    ListItem(P("<b>Job list</b> drag-and-drop reorderable, with context menu "
               "(Edit / Duplicate / Remove)")),
    ListItem(P("Each job has: filter, count, exposure, gain, offset, binning, "
               "frame type (Light/Dark/Flat/Bias), transfer format "
               "(FITS/NATIVE/XISF), capture format (RAW/RGB), delay, dither "
               "flag, target name")),
    ListItem(P("<b>+ NEW JOB</b>: full form with all parameters")),
    ListItem(P("<b>Presets</b>: save/load JSON sequences (e.g. 'M31 LRGB night 1')")),
    ListItem(P("<b>START SEQUENCE</b>: dialog with 3 options - see chapter 4")),
], bulletType="bullet", leftIndent=20))

story.append(H2("3.5 Guide"))
story.append(P("Full PHD2 control:"))
story.append(ListFlowable([
    ListItem(P("Cards: RMS Total, SNR, RMS RA, RMS Dec")),
    ListItem(P("Live RA/Dec tracking error chart (history of the last ~120 samples)")),
    ListItem(P("Buttons: START / STOP / DITHER / FIND STAR / CALIBRATE / CLEAR CAL / PAUSE")),
    ListItem(P("PHD2 equipment: version, pixel scale, calibrated, settling")),
], bulletType="bullet", leftIndent=20))

story.append(PageBreak())

# 4. PRE-FLIGHT PIPELINE
story.append(H1("4. Pre-flight pipeline"))
story.append(P("When you tap <b>START SEQUENCE</b> in Capture a dialog appears "
               "with <b>three execution modes</b>:"))

story.append(H2("4.1 FULL OBSERVATION (recommended)"))
story.append(P("Runs an orchestrated 10-stage pipeline that reproduces what "
               "Ekos Scheduler does:"))
story.append(grid_table(
    ["#", "Stage", "Description", "Skip"],
    [
        ["1", "resolve_target", "Resolves the name via SIMBAD/astropy → RA/Dec", "-"],
        ["2", "slew", "Mount goto+track to the target", "-"],
        ["3", "tracking", "Waits for the mount to be Ok (max 5 min)", "-"],
        ["4", "plate_solve", "solve-field on the last frame with ±5° hint", "opt"],
        ["5", "sync_mount", "Syncs the mount on the solve, re-enables tracking", "auto"],
        ["6", "autofocus", "Iterative HFR loop with V-curve", "opt"],
        ["7", "guide_calibrate", "PHD2 clear+recalibrate, wait for Guiding (4 min)", "opt"],
        ["8", "guide_start", "PHD2 start guiding, wait for settle (3 min)", "opt"],
        ["9", "capture_load", "Loads the .esq into Ekos via DBus", "-"],
        ["10", "capture_started", "Starts the Ekos queue", "-"],
    ],
    col_widths=[1 * cm, 3 * cm, 9 * cm, 1.5 * cm]))
story.append(P("Capture only starts after every stage has succeeded. The app "
               "shows a <b>live timeline</b> with colored stage states "
               "(grey=pending, amber=running, green=done, red=failed)."))

story.append(NOTE("Optional stages can be enabled in the Observation screen. "
                  "For the first night I suggest enabling everything. On "
                  "later cycles you can disable plate solve and calibrate "
                  "(the slowest ones) for a faster start."))

story.append(H2("4.2 VIA EKOS (loadSequenceQueue)"))
story.append(P("Generates an <font face='Courier'>.esq</font> file from the "
               "Flutter jobs and loads it into the Ekos Capture queue via "
               "DBus, then starts. The sequence appears <b>inside</b> the "
               "Ekos Capture window on the desktop. Ekos handles dither, "
               "autofocus on filter change, FITS naming, meridian flip - "
               "all of its native workflow."))

story.append(H2("4.3 DIRECT (via INDI)"))
story.append(P("The app drives the INDI drivers directly without going "
               "through Ekos. Faster but Ekos won't see the sequence in its UI."))

story.append(WARN("In DIRECT mode the app does NOT modify Ekos's setup. The "
                  "bridge intercepts BLOBs as a parallel INDI client via "
                  "enableBLOB Also, so files are not saved to disk by the "
                  "bridge - everything stays in RAM."))

story.append(PageBreak())

# 5. ADVANCED SCREENS
story.append(H1("5. Advanced screens"))
story.append(P("All available from the side drawer (tap the menu icon)."))

story.append(H2("5.1 Live View"))
story.append(P("Full-screen viewer for the last captured frame, with pinch "
               "zoom and metadata (HFR, stars, exposure, filter)."))

story.append(H2("5.2 Focus"))
story.append(P("Focuser control with iterative autofocus:"))
story.append(ListFlowable([
    ListItem(P("Manual movement ±10/100/1000 steps in/out")),
    ListItem(P("Absolute position with numeric field")),
    ListItem(P("<b>Iterative autofocus</b>: set step size, n steps (odd), "
               "exposure → START. The bridge takes N shots at "
               "different positions, computes HFR for each, finds the "
               "minimum, moves to the best position.")),
    ListItem(P("<b>Live V-curve plot</b> with colored points and a dashed "
               "vertical line on the best position")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.3 Align (Plate Solve)"))
story.append(P("Plate solving via solve-field astrometry.net:"))
story.append(ListFlowable([
    ListItem(P("Shows the last captured frame and its metadata")),
    ListItem(P("Tap <b>PLATE SOLVE</b> → the backend launches "
               "<font face='Courier'>solve-field</font> with hints from the "
               "current mount (5° radius), polls status every 2s")),
    ListItem(P("When done, shows RA/Dec/scale extracted via "
               "<font face='Courier'>astropy.wcs.WCS</font> from the .wcs file")),
    ListItem(P("<b>SYNC MOUNT</b> button: syncs the mount on the solve result")),
    ListItem(P("Full solve-field output expandable for debug")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.4 Observatory"))
story.append(P("Dome, dust cap, flat panel, weather control:"))
story.append(ListFlowable([
    ListItem(P("Weather card with all parameters (temp, humidity, wind, sky)")),
    ListItem(P("Dome shutter Open/Close")),
    ListItem(P("Dust cap Park/Unpark")),
    ListItem(P("Flat panel toggle + 0-255 intensity slider")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.5 Scheduler"))
story.append(P("Multi-target nightly planner:"))
story.append(ListFlowable([
    ListItem(P("Sky-state card: twilight phase (day/civil/nautical/"
               "astronomical/night), sun/moon altitude, lat/lon "
               "(auto-detected from the mount)")),
    ListItem(P("Persistent jobs list with RA/Dec, minimum altitude, time window")),
    ListItem(P("+NEW JOB: form with automatic SIMBAD target resolution")),
    ListItem(P("For each job: tap ✓ to live-check conditions (twilight "
               "required, current altitude, weather safe) → dialog with "
               "the list of issues")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.6 Setup / Profiles"))
story.append(P("Active INDI driver list with <b>CONNECT/DISCONNECT</b> "
               "toggle (useful to enable drivers like XAGYL Wheel or Weather "
               "Watcher when Ekos loaded but did not connect them)."))

story.append(H2("5.7 INDI Panel"))
story.append(P("Exact clone of the KStars/Ekos INDI Control Panel:"))
story.append(ListFlowable([
    ListItem(P("List of every connected device")),
    ListItem(P("Tap a device → all its properties grouped by Group "
               "(Main Control, Options, etc.)")),
    ListItem(P("Interactive Switches (ChipToggle), editable Numbers, editable "
               "Texts, read-only Lights with colored state")),
    ListItem(P("Live two-way propagation: change here → Ekos sees it; "
               "change in Ekos → it appears here")),
    ListItem(P("CONNECT/DISCONNECT button at the top for each device")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.8 Files"))
story.append(P("Browser for FITS files in <font face='Courier'>"
               "~/Pictures/Ekos/</font>:"))
story.append(ListFlowable([
    ListItem(P("Recent files list with auto-stretched thumbnails")),
    ListItem(P("Tap → full-screen preview with zoom")),
    ListItem(P("Light/Dark/Flat/Bias/All filters")),
    ListItem(P("Multi-select with long-press and batch delete")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.9 Logs / Activity Log"))
story.append(P("Two distinct screens:"))
story.append(ListFlowable([
    ListItem(P("<b>INDI Logs</b>: live INDI/Ekos message stream, filterable "
               "by module")),
    ListItem(P("<b>Activity Log</b>: every HTTP request the app makes to the "
               "bridge, with millisecond timestamp, color-coded status code, "
               "duration, body. Tap for details + copy. Crucial for debugging.")),
], bulletType="bullet", leftIndent=20))

story.append(H2("5.10 Analyze"))
story.append(P("Current session timeline:"))
story.append(ListFlowable([
    ListItem(P("Counters: WS events, total properties, devices")),
    ListItem(P("Last frame info (object, filter, exposure, HFR, stars, size)")),
    ListItem(P("Historical PHD2 RMS chart (RA in amber, Dec in cyan)")),
    ListItem(P("INDI message stream, last 20 lines")),
], bulletType="bullet", leftIndent=20))

story.append(PageBreak())

# 6. TROUBLESHOOTING
story.append(H1("6. Troubleshooting"))
story.append(grid_table(
    ["Symptom", "Likely cause", "Fix"],
    [
        ["App: 'unreachable' on login",
         "Tailscale not active on the phone or the RPi is offline",
         "Check the Tailscale app shows Connected; ping 100.74.22.40 from the phone browser"],
        ["App: 'auth_failed'",
         "Wrong token",
         "cat ~/.config/astroarch-bridge/token on the RPi"],
        ["App sees 0 devices",
         "Ekos profile not started",
         "Open Ekos on the desktop and start the INDI profile"],
        ["Cooler not working (POWER 0%)",
         "toupbase driver stuck after fast on/off",
         "Tap RECONNECT DRIVER on Capture"],
        ["Sequence does not start in Ekos",
         "UPLOAD_MODE in CLIENT (driver default)",
         "Auto-forced to BOTH from app v0.2.2+"],
        ["Plate solve fails",
         "Astrometry index files missing or wrong scope",
         "Check ~/.local/share/kstars/astrometry/, scale hint"],
        ["WS frames does not refresh",
         "WS state disconnected (red banner)",
         "Manual refresh (Dashboard icon) or reconnect"],
        ["FITS files not saved",
         "UPLOAD_DIR misspelt or directory missing",
         "App auto-creates /Pictures/Ekos/AstroarchInterface/"],
        ["Multi-camera 409 error",
         "Bridge does not know which camera to use",
         "Use the Camera dropdown in Capture (default = primary)"],
    ],
    col_widths=[5 * cm, 4.5 * cm, 6 * cm]))

story.append(H2("6.1 Diagnostic commands on the Raspberry Pi"))
story.append(CODE("# Bridge service status\n"
                  "systemctl --user status astroarch-bridge\n\n"
                  "# Live log\n"
                  "journalctl --user -u astroarch-bridge -f\n\n"
                  "# Endpoint test\n"
                  "curl http://localhost:8765/healthz\n\n"
                  "# Unstuck a frozen INDI driver\n"
                  "indi_setprop 'CAMERA_NAME.CONNECTION.DISCONNECT=On'\n"
                  "sleep 2\n"
                  "indi_setprop 'CAMERA_NAME.CONNECTION.CONNECT=On'\n\n"
                  "# Inspect cooler state\n"
                  "indi_getprop 'CAMERA_NAME.CCD_TEMPERATURE.CCD_TEMPERATURE_VALUE'\n"
                  "indi_getprop 'CAMERA_NAME.CCD_COOLER_POWER.COOLER_POWER'"))

story.append(H2("6.2 Diagnostics inside the app"))
story.append(P("On the Login screen there is a <b>TEST</b> button that opens "
               "the Diagnostics screen with 7 sequential steps:"))
story.append(ListFlowable([
    ListItem(P("Host resolution (DNS / Tailscale)")),
    ListItem(P("HTTP GET /healthz")),
    ListItem(P("HTTP GET /api/system/info (auth Bearer)")),
    ListItem(P("HTTP GET /api/system/snapshot (payload check)")),
    ListItem(P("WebSocket /ws/state (open)")),
    ListItem(P("WebSocket - first message within 5s")),
    ListItem(P("WebSocket - chunked property_def reception")),
], bulletType="bullet", leftIndent=20))
story.append(P("Each step shows the duration in milliseconds and the error "
               "details on failure. It solves 95% of issues at first try."))

story.append(PageBreak())

# 7. APPENDIX - REST API
story.append(H1("7. Appendix - REST API"))
story.append(P("All requests need the header "
               "<font face='Courier'>Authorization: Bearer &lt;token&gt;</font> "
               "(except /healthz). Responses are always JSON."))

story.append(H2("7.1 System"))
story.append(grid_table(
    ["Endpoint", "Method", "Description"],
    [
        ["/healthz", "GET", "Health (no auth)"],
        ["/api/system/info", "GET", "Bridge info (version, author)"],
        ["/api/system/snapshot", "GET", "Global state (devices, properties, phd2, last_frame)"],
        ["/api/system/connections", "GET", "INDI/PHD2 connection state"],
        ["/api/system/devices", "GET", "INDI device list"],
        ["/api/system/camera_roles", "GET", "Identifies primary vs guide camera via PHD2"],
        ["/api/system/simbad", "GET", "?name=M31 -> RA/Dec via SIMBAD"],
    ],
    col_widths=[6.5 * cm, 1.5 * cm, 7.5 * cm]))

story.append(H2("7.2 Mount, Camera, Focuser, Filter, Guide"))
story.append(grid_table(
    ["Endpoint", "Method", "Description"],
    [
        ["/api/mount/status, /goto, /park, /track, /slew, /slew_rate, /abort", "GET/POST", "Telescope control"],
        ["/api/camera/status, /expose, /abort, /cooler, /gain, /offset, /binning, /frame_type, /transfer_format, /capture_format, /upload_setup", "GET/POST", "Camera control"],
        ["/api/focuser/status, /abs, /rel, /abort, /autofocus, /autofocus/{id}", "GET/POST", "Focuser + iterative autofocus"],
        ["/api/filter_wheel/status, /select", "GET/POST", "Filter wheel"],
        ["/api/guide/status, /start, /stop, /dither, /loop, /clear_calibration, /pause, /find_star, /calibrate, /profile", "GET/POST", "PHD2 guide"],
    ],
    col_widths=[8 * cm, 1.5 * cm, 6 * cm]))

story.append(H2("7.3 Align, Capture/Ekos, Observation, Scheduler, Setup"))
story.append(grid_table(
    ["Endpoint", "Description"],
    [
        ["/api/align/status, /solve, /solve/{id}/sync_mount, /capture_and_solve, /ekos_capture_and_solve, /ekos_full_status", "Plate solving + Ekos Align clone"],
        ["/api/capture/ekos_alive, /ekos_run, /ekos_status, /ekos_abort, /ekos_clear", "Capture via Ekos DBus"],
        ["/api/observation/run, /{id}, /{id}/abort", "Pre-flight pipeline 10 stages"],
        ["/api/scheduler/sky_state, /jobs, /jobs/{id}/check_conditions, /weather_safe", "Time scheduler"],
        ["/api/setup/profiles, /active_drivers", "Ekos profiles + active drivers"],
        ["/api/observatory/status, /dome/shutter, /dust_cap, /flat_panel", "Dome + flat panel"],
        ["/api/files/recent, /preview, /download, /file (DELETE), /delete_many, /disk_usage", "FITS browser"],
    ],
    col_widths=[9.5 * cm, 6 * cm]))

story.append(H2("7.4 INDI panel (control panel clone)"))
story.append(grid_table(
    ["Endpoint", "Description"],
    [
        ["GET /api/indi/devices", "Device list"],
        ["GET /api/indi/devices/{dev}/properties", "All device properties"],
        ["GET /api/indi/devices/{dev}/properties/{name}", "Single property"],
        ["POST /api/indi/devices/{dev}/properties/{name}", "Set values (Switch/Number/Text)"],
        ["POST /api/indi/devices/{dev}/connect, /disconnect", "Connect/disconnect driver"],
        ["POST /api/indi/refresh", "Force getProperties"],
    ],
    col_widths=[9.5 * cm, 6 * cm]))

story.append(H2("7.5 WebSocket"))
story.append(grid_table(
    ["URL", "What it pushes"],
    [
        ["GET /ws/state?token=...",
         "snapshot_begin -> N property_def -> snapshot_end (init), then "
         "property_def, property_set, property_del, indi_message, "
         "phd2_event, phd2_live, frame_meta, connection"],
        ["GET /ws/frames?token=...",
         "For each frame: JSON header {type:frame_meta, size, hfr, ...} "
         "followed by JPEG bytes"],
    ],
    col_widths=[5.5 * cm, 10 * cm]))

story.append(PageBreak())

# 8. CHANGELOG
story.append(H1("8. Changelog"))
story.append(grid_table(
    ["Version", "Highlights"],
    [
        ["0.1.0", "First release: 13 base screens, live WebSocket clone, Tailscale auth"],
        ["0.1.4", "Chunked WebSocket snapshot (fix 200KB Android payload)"],
        ["0.1.5-6", "HTTP/WS cleartext fix + step-by-step diagnostics"],
        ["0.1.7", "Camera primary/guide auto-detection via PHD2"],
        ["0.1.8-10", "Cooler robust toggle + capture sequence + Activity Log"],
        ["0.2.0", "Full Ekos clone: 8 modules + multi-job + SIMBAD + autofocus V-curve"],
        ["0.2.1", "Plate solving via solve-field + Time scheduler + sky_state"],
        ["0.2.3", "Capture via Ekos DBus (loadSequenceQueue + start)"],
        ["0.2.4", "FULL OBSERVATION pipeline with 10 pre-flight stages"],
        ["0.2.7", "Plate solve clone Ekos (full status + bin/gain configurable)"],
        ["0.2.10", "Plate solve UI redesign (live preview, big action button)"],
        ["0.2.11", "BLOB intercept zero-invasive (parallel INDI client)"],
        ["0.2.12", "Auto-stretch identical to KStars/Ekos (ZScale + asinh MTF)"],
        ["0.2.14", "Fix Ekos AlignSolverAction enum mapping (Sync/Slew/Nothing)"],
    ],
    col_widths=[2.5 * cm, 13 * cm]))

story.append(Spacer(1, 1 * cm))
story.append(H2("Future roadmap"))
story.append(ListFlowable([
    ListItem(P("Mosaic planner")),
    ListItem(P("Push notifications (frame done, sequence finished, weather alert)")),
    ListItem(P("Possible upstream contribution to "
               "<font face='Courier'>devDucks/astroarch</font>")),
], bulletType="bullet", leftIndent=20))

story.append(Spacer(1, 1.5 * cm))
story.append(P('<para alignment="center"><font color="#8a93a6">'
               "- Clear skies -<br/>"
               "Astroarch Interface * Zarletti-Osservatorio Jupiter"
               "</font></para>"))


def _on_first_page(canvas, doc):
    cover_layout(canvas, doc)


def _on_later_pages(canvas, doc):
    page_layout(canvas, doc)


doc = SimpleDocTemplate(
    OUTPUT, pagesize=A4,
    leftMargin=2 * cm, rightMargin=2 * cm,
    topMargin=2 * cm, bottomMargin=1.6 * cm,
    title="Astroarch Interface - User Manual",
    author="Zarletti-Osservatorio Jupiter",
    subject="User manual and installation guide",
    creator="Astroarch Interface v0.2.14",
)
doc.build(story, onFirstPage=_on_first_page, onLaterPages=_on_later_pages)

import os
size_kb = os.path.getsize(OUTPUT) / 1024
print(f"OK: {OUTPUT} ({size_kb:.0f} KB)")
