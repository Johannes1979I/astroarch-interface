import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});
  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  Future<void> _safe(Future Function() fn, String msg) async {
    try { await fn(); if (mounted) showSnack(context, msg); }
    on ApiException catch (e) {
      if (mounted) showSnack(context,
          '${'Errore: '.tr(context)}${_extractDetail(e.body)}', error: true);
    }
    catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true);
    }
  }

  /// Estrae il campo "detail" dal body JSON di FastAPI, fallback al body.
  String _extractDetail(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final live = s.phd2Live;
    final connected = s.phd2Conn == 'connected';
    final st = live['app_state']?.toString() ?? 'Stopped';
    final rms = (live['rms_total'] as num?)?.toDouble();
    final raRms = (live['rms_ra'] as num?)?.toDouble();
    final decRms = (live['rms_dec'] as num?)?.toDouble();
    final snr = (live['snr'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: openShellDrawer),
        title: Row(children: [
        const LiveDot(),
        const SizedBox(width: 10),
        Text('${'Guide'.tr(context)} · PHD2'),
        const Spacer(),
        Text(connected ? st : 'offline',
            style: TextStyle(color: connected ? T.ok(context) : T.muted(context), fontSize: 12)),
      ])),
      body: !connected
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'PHD2 non connesso al bridge.\nAvvia PHD2 sul RPi e abilita Server (porta 4400).'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: T.muted(context)),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
              children: [
                // Vista stella di guida — il riquadro con crosshair che si
                // vede dentro PHD2. Si aggiorna automaticamente.
                const _GuideStarImageCard(),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
                  childAspectRatio: 1.7,
                  children: [
                    StatusCard(header: 'RMS TOTAL'.tr(context),
                        value: rms == null ? '—' : '${rms.toStringAsFixed(2)}″',
                        subtitle: 'target < 1.0″'),
                    StatusCard(header: 'SNR',
                        value: snr == null ? '—' : snr.toStringAsFixed(0),
                        subtitle: 'star quality'.tr(context)),
                    StatusCard(header: 'RA RMS'.tr(context),
                        value: raRms == null ? '—' : '${raRms.toStringAsFixed(2)}″'),
                    StatusCard(header: 'DEC RMS'.tr(context),
                        value: decRms == null ? '—' : '${decRms.toStringAsFixed(2)}″'),
                  ],
                ),
                SectionLabel('Errore inseguimento'.tr(context)),
                _chart(s),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: PrimaryButton(label: 'START', icon: Icons.play_arrow,
                      onPressed: () => _safe(() => s.api!.guideStart(), 'Guide started'.tr(context)))),
                  const SizedBox(width: 8),
                  Expanded(child: GhostButton(label: 'STOP', icon: Icons.stop,
                      onPressed: () => _safe(() => s.api!.guideStop(), 'Stopped'.tr(context)))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: GhostButton(label: 'DITHER', icon: Icons.scatter_plot,
                      onPressed: () => _safe(() => s.api!.guideDither(amount: 3), 'Dither 3px'.tr(context)))),
                  const SizedBox(width: 8),
                  Expanded(child: GhostButton(label: 'FIND STAR',
                      onPressed: () => _safe(() => s.api!.guideFindStar(), 'Find star'.tr(context)))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: GhostButton(label: 'CALIBRATE',
                      icon: Icons.adjust,
                      onPressed: () => _safe(() => s.api!.guideCalibrate(),
                          'Calibration avviata (richiede ~2 min)'.tr(context)))),
                  const SizedBox(width: 8),
                  Expanded(child: GhostButton(label: 'CLEAR CAL',
                      onPressed: () => _safe(() => s.api!.guideClearCalibration(), 'Cal cleared'.tr(context)))),
                ]),
                SectionLabel('Equipaggiamento PHD2'.tr(context)),
                _equipmentCard(s),
              ],
            ),
    );
  }

  Widget _equipmentCard(AppState s) {
    final live = s.phd2Live;
    final pixelScale = (live['pixel_scale'] as num?)?.toDouble();
    final ver = live['version'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.panel(context), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: T.line(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline, color: T.muted(context), size: 14),
          const SizedBox(width: 6),
          Text('PHD2 ${ver ?? "—"}', style: TextStyle(color: T.muted(context), fontSize: 11)),
          const Spacer(),
          if (pixelScale != null) Text('${pixelScale.toStringAsFixed(2)} ″/px',
              style: TextStyle(color: T.muted(context), fontSize: 11, fontFamily: 'monospace')),
        ]),
        if (live['calibrated'] == true) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('● ${'Calibrated'.tr(context)}', style: TextStyle(color: T.ok(context), fontSize: 11)),
        ),
        if (live['settling'] == true) Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('● ${'Settling…'.tr(context)}', style: TextStyle(color: T.warn(context), fontSize: 11)),
        ),
      ]),
    );
  }

  /// Grafico di inseguimento stile PHD2: due linee (RA in blu, DEC in
  /// rosso) con asse Y in arcsec SIGNATO ± e linea di mezzeria a 0.
  /// I valori plottati sono `ra_raw` / `dec_raw` (= RADistanceRaw /
  /// DECDistanceRaw che PHD2 manda ad ogni `GuideStep`), che è la
  /// deflezione istantanea per-frame. NON sono i valori RMS aggregati.
  Widget _chart(AppState s) {
    // Filtra solo i punti che hanno effettivamente ra_raw/dec_raw
    // (escludendo gli eventi di stato senza deflezione, es. StarLost).
    final pts = s.phd2History.where((p) =>
        p['ra_raw'] != null || p['dec_raw'] != null).toList();

    if (pts.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: T.panel(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.line(context)),
        ),
        child: Center(child: Text(
            'In attesa di dati guide…\n'
            'Avvia il guiding in PHD2 per vedere il grafico.'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(color: T.muted(context), fontSize: 12))),
      );
    }

    final raSpots = <FlSpot>[];
    final decSpots = <FlSpot>[];
    double absMax = 1.0;
    for (var i = 0; i < pts.length; i++) {
      final ra = (pts[i]['ra_raw'] as num?)?.toDouble() ?? 0;
      final dec = (pts[i]['dec_raw'] as num?)?.toDouble() ?? 0;
      raSpots.add(FlSpot(i.toDouble(), ra));
      decSpots.add(FlSpot(i.toDouble(), dec));
      final a = ra.abs() > dec.abs() ? ra.abs() : dec.abs();
      if (a > absMax) absMax = a;
    }
    // Asse Y simmetrico ±absMax (arrotondato in alto a multipli di 0.5″,
    // minimo ±1.0″ così il grafico non oscilla per micro-variazioni).
    final yScale = (absMax <= 1.0) ? 1.0
        : (absMax <= 2.0) ? 2.0
        : (absMax <= 4.0) ? 4.0
        : (absMax + 0.5).ceilToDouble();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 6),
      decoration: BoxDecoration(
        color: T.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(context)),
      ),
      child: Column(children: [
        // Legenda + scala
        Row(children: [
          Container(width: 10, height: 2, color: T.accent(context)),
          const SizedBox(width: 4),
          Text('RA', style: TextStyle(color: T.accent(context),
              fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Container(width: 10, height: 2, color: T.accent2(context)),
          const SizedBox(width: 4),
          Text('DEC', style: TextStyle(color: T.accent2(context),
              fontSize: 10, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Y: ±${yScale.toStringAsFixed(1)}″ · ${pts.length} pts',
              style: TextStyle(color: T.muted(context), fontSize: 10,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 4),
        Expanded(child: LineChart(
          LineChartData(
            minX: 0, maxX: (raSpots.length - 1).toDouble().clamp(1.0, double.infinity),
            minY: -yScale, maxY: yScale,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yScale / 2.0,
              getDrawingHorizontalLine: (v) => FlLine(
                color: v.abs() < 1e-6
                    ? T.muted(context).withValues(alpha: 0.6)
                    : T.line(context).withValues(alpha: 0.4),
                strokeWidth: v.abs() < 1e-6 ? 1.0 : 0.5,
                dashArray: v.abs() < 1e-6 ? null : [2, 4],
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: yScale / 2.0,
                getTitlesWidget: (v, _) => Text(
                    v == 0 ? '0' : v.toStringAsFixed(1),
                    style: TextStyle(color: T.muted(context), fontSize: 9,
                        fontFamily: 'monospace')),
              )),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: const AxisTitles(),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: raSpots,
                isCurved: false,  // PHD2 usa linee dritte, non interpolate
                color: T.accent(context),
                barWidth: 1.3,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: decSpots,
                isCurved: false,
                color: T.accent2(context),
                barWidth: 1.3,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        )),
      ]),
    );
  }
}


/// Widget che mostra il riquadro con la stella di guida intercettato da PHD2.
/// Polling ogni 1500 ms (PHD2 espone una nuova frame ~ogni 1-3s di solito).
/// Se PHD2 non ha ancora una stella selezionata (es. utente non ha fatto
/// "Find Star" / "Calibrate"), mostra placeholder con istruzioni.
class _GuideStarImageCard extends StatefulWidget {
  const _GuideStarImageCard();
  @override
  State<_GuideStarImageCard> createState() => _GuideStarImageCardState();
}

class _GuideStarImageCardState extends State<_GuideStarImageCard> {
  Timer? _timer;
  Uint8List? _png;
  int? _w, _h;
  double? _starX, _starY;
  int? _frame;
  String? _err;
  bool _inflight = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_inflight) return; // evita overlap se la rete è lenta
    final s = context.read<AppState>();
    if (s.api == null) return;
    _inflight = true;
    try {
      final j = await s.api!.guideStarImage();
      final b64 = j['png_base64'] as String?;
      if (b64 == null) throw Exception('missing png');
      final bytes = base64.decode(b64);
      if (!mounted) return;
      setState(() {
        _png = bytes;
        _w = (j['width'] as num?)?.toInt();
        _h = (j['height'] as num?)?.toInt();
        _starX = (j['star_x'] as num?)?.toDouble();
        _starY = (j['star_y'] as num?)?.toDouble();
        _frame = (j['frame'] as num?)?.toInt();
        _err = null;
      });
    } on ApiException catch (e) {
      // 409 = PHD2 senza stella selezionata o app_state non compatibile
      if (mounted) setState(() => _err = e.status == 409
          ? 'PHD2: nessuna stella selezionata. Premi FIND STAR.'.tr(context)
          : '${'Errore: '.tr(context)}${_extractDetailLocal(e.body)}');
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      _inflight = false;
    }
  }

  String _extractDetailLocal(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return body;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Stack(fit: StackFit.expand, children: [
          if (_png != null)
            InteractiveViewer(
              minScale: 1, maxScale: 6,
              child: LayoutBuilder(builder: (ctx, constraints) {
                // Disegna il PNG ridimensionato al riquadro mantenendo
                // l'aspect ratio del crop di PHD2. Calcolo scale per
                // posizionare il crosshair sul punto giusto.
                final cw = constraints.maxWidth;
                final ch = constraints.maxHeight;
                final iw = (_w ?? 1).toDouble();
                final ih = (_h ?? 1).toDouble();
                final scale = (cw / iw < ch / ih) ? cw / iw : ch / ih;
                final dispW = iw * scale, dispH = ih * scale;
                final offX = (cw - dispW) / 2, offY = (ch - dispH) / 2;
                final crossX = _starX == null
                    ? null : offX + _starX! * scale;
                final crossY = _starY == null
                    ? null : offY + _starY! * scale;
                return Stack(children: [
                  Center(child: Image.memory(_png!,
                      fit: BoxFit.contain, gaplessPlayback: true,
                      filterQuality: FilterQuality.medium)),
                  if (crossX != null && crossY != null)
                    Positioned(
                      left: crossX - 22, top: crossY - 22,
                      width: 44, height: 44,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CrosshairPainter(color: T.accent(context)),
                        ),
                      ),
                    ),
                ]);
              }),
            )
          else if (_err != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.search_off, color: T.muted(context), size: 28),
                const SizedBox(height: 8),
                Text(_err!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: T.muted(context), fontSize: 12)),
              ]),
            ))
          else
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          // HUD top-left: frame + crop size
          if (_png != null && _w != null && _h != null) Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(
                '★ ${_starX?.toStringAsFixed(1) ?? "—"}, '
                '${_starY?.toStringAsFixed(1) ?? "—"} · '
                '${_w}×$_h · #${_frame ?? "—"}',
                style: const TextStyle(color: Colors.white,
                    fontFamily: 'monospace', fontSize: 9),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color color;
  _CrosshairPainter({required this.color});
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final r = s.width * 0.35;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // Cerchio centrale
    c.drawCircle(Offset(cx, cy), r, p);
    // Tick orizzontale/verticale
    c.drawLine(Offset(0, cy), Offset(cx - r * 0.5, cy), p);
    c.drawLine(Offset(cx + r * 0.5, cy), Offset(s.width, cy), p);
    c.drawLine(Offset(cx, 0), Offset(cx, cy - r * 0.5), p);
    c.drawLine(Offset(cx, cy + r * 0.5), Offset(cx, s.height), p);
  }
  @override
  bool shouldRepaint(covariant _CrosshairPainter old) => old.color != color;
}
