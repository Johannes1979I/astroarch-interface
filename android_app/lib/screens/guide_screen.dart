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
    on ApiException catch (e) { if (mounted) showSnack(context, '${'Errore: '.tr(context)}${e.body}', error: true); }
    catch (e) { if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true); }
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

  Widget _chart(AppState s) {
    if (s.phd2History.isEmpty) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          color: T.panel(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.line(context)),
        ),
        child: Center(child: Text('In attesa di dati guide…'.tr(context), style: TextStyle(color: T.muted(context), fontSize: 12))),
      );
    }
    final points = s.phd2History;
    final List<FlSpot> raSpots = [];
    final List<FlSpot> decSpots = [];
    for (var i = 0; i < points.length; i++) {
      final ra = (points[i]['rms_ra'] as num?)?.toDouble() ?? 0;
      final dec = (points[i]['rms_dec'] as num?)?.toDouble() ?? 0;
      raSpots.add(FlSpot(i.toDouble(), ra));
      decSpots.add(FlSpot(i.toDouble(), dec));
    }
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 14, 14, 6),
      decoration: BoxDecoration(
        color: T.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(context)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: raSpots,
              isCurved: true,
              color: T.accent(context),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: decSpots,
              isCurved: true,
              color: T.accent2(context),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
          ],
          minY: 0,
          maxY: 3,
        ),
      ),
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
          : '${'Errore: '.tr(context)}${e.body}');
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      _inflight = false;
    }
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
