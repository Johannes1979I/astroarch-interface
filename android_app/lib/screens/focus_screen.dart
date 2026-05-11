import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  // Autofocus run state
  String? _runId;
  Map<String, dynamic>? _runStatus;
  Timer? _pollTimer;

  // AF parameters
  int _stepSize = 50;
  int _nSteps = 9;
  double _exposureSec = 2.0;

  Future<void> _safe(Future Function() fn, String okMsg) async {
    try { await fn(); if (mounted) showSnack(context, okMsg); }
    on ApiException catch (e) { if (mounted) showSnack(context, '${'Errore: '.tr(context)}${e.body}', error: true); }
    catch (e) { if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true); }
  }

  Future<void> _move(int steps, String direction) async {
    final s = context.read<AppState>();
    await _safe(() => s.api!.focuserRel(steps, direction), '$direction $steps');
  }

  Future<void> _startAutofocus(AppState s) async {
    if (s.api == null) return;
    try {
      final r = await s.api!.focuserAutofocusStart(
        stepSize: _stepSize, nSteps: _nSteps, exposureSec: _exposureSec,
      );
      _runId = r['run_id'] as String?;
      _runStatus = r;
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
      setState(() {});
      if (mounted) showSnack(context, 'Autofocus avviato'.tr(context));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}${e.body}', error: true);
    } catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true);
    }
  }

  Future<void> _pollStatus() async {
    if (_runId == null) return;
    final s = context.read<AppState>();
    try {
      _runStatus = await s.api!.focuserAutofocusStatus(_runId!);
      setState(() {});
      final st = _runStatus!['status'];
      if (st == 'done' || st == 'failed' || st == 'aborted') {
        _pollTimer?.cancel();
      }
    } catch (_) {}
  }

  Future<void> _abortAutofocus() async {
    if (_runId == null) return;
    final s = context.read<AppState>();
    try {
      await s.api!.focuserAutofocusAbort(_runId!);
      if (mounted) showSnack(context, 'Abort autofocus'.tr(context));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.focuserDevice();
    final pos = f == null ? null : s.prop(f, 'ABS_FOCUS_POSITION');
    final temp = f == null ? null : s.prop(f, 'FOCUS_TEMPERATURE');
    final position = (propValue(pos, 'FOCUS_ABSOLUTE_POSITION') as num?)?.toInt();
    final maxPos = _max(pos, 'FOCUS_ABSOLUTE_POSITION');
    final t = (propValue(temp, 'TEMPERATURE') as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(f == null ? 'Focus'.tr(context) : '${'Focus'.tr(context)} · $f')),
      body: f == null
          ? Center(child: Text('Nessun focuser connesso'.tr(context), style: TextStyle(color: T.muted(context))))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
              children: [
                GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1.7,
                  children: [
                    StatusCard(header: 'POSITION'.tr(context), value: position?.toString() ?? '—',
                        subtitle: maxPos == null ? null : '${'max'.tr(context)} ${maxPos.toInt()}'),
                    StatusCard(header: 'TEMP'.tr(context),
                        value: t == null ? '—' : '${t.toStringAsFixed(1)}°', subtitle: 'sensor'.tr(context)),
                    StatusCard(header: 'STATE'.tr(context), value: pos?['state'] ?? '—',
                        subtitle: pos?['state'] == 'Busy' ? 'moving'.tr(context) : 'idle'.tr(context),
                        badgeColor: pos?['state'] == 'Busy' ? T.accent(context) : T.muted(context),
                        badgeText: pos?['state'] == 'Busy' ? 'mov' : 'idle'),
                  ],
                ),
                SectionLabel('Movimento manuale (rel)'.tr(context)),
                Row(children: [
                  Expanded(child: GhostButton(label: '−1000', small: true, onPressed: () => _move(1000, 'in'))),
                  const SizedBox(width: 4),
                  Expanded(child: GhostButton(label: '−100', small: true, onPressed: () => _move(100, 'in'))),
                  const SizedBox(width: 4),
                  Expanded(child: GhostButton(label: '−10', small: true, onPressed: () => _move(10, 'in'))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: GhostButton(label: '+10', small: true, onPressed: () => _move(10, 'out'))),
                  const SizedBox(width: 4),
                  Expanded(child: GhostButton(label: '+100', small: true, onPressed: () => _move(100, 'out'))),
                  const SizedBox(width: 4),
                  Expanded(child: GhostButton(label: '+1000', small: true, onPressed: () => _move(1000, 'out'))),
                ]),
                SectionLabel('Posizione assoluta'.tr(context)),
                _absInput(s, position),
                SectionLabel('Autofocus iterativo'.tr(context)),
                _autofocusParams(),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: PrimaryButton(
                    label: _isAfRunning() ? 'IN CORSO…'.tr(context) : 'AVVIA AUTOFOCUS'.tr(context),
                    icon: Icons.center_focus_strong,
                    onPressed: _isAfRunning() ? null : () => _startAutofocus(s),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GhostButton(
                    label: 'ABORT'.tr(context), icon: Icons.stop, danger: true,
                    onPressed: _isAfRunning() ? _abortAutofocus : null,
                  )),
                ]),
                if (_runStatus != null) ...[
                  const SizedBox(height: 12),
                  _runStatusCard(),
                  SectionLabel('V-Curve'.tr(context)),
                  _vCurveChart(),
                ],
                SectionLabel('Manuale rapido'.tr(context)),
                Row(children: [
                  Expanded(child: GhostButton(
                    label: 'ABORT motion'.tr(context), icon: Icons.stop, danger: true,
                    onPressed: () => _safe(() => s.api!.focuserAbort(), 'Abort'.tr(context)),
                  )),
                ]),
              ],
            ),
    );
  }

  bool _isAfRunning() {
    final st = _runStatus?['status'];
    return st == 'running' || st == 'aborting';
  }

  Widget _autofocusParams() {
    return Column(children: [
      Row(children: [
        Expanded(child: _slider('Step size'.tr(context), _stepSize.toDouble(), 5, 500,
            (v) => setState(() => _stepSize = v.toInt()), formatter: (v) => v.toStringAsFixed(0))),
      ]),
      Row(children: [
        Expanded(child: _slider('N step (dispari)'.tr(context), _nSteps.toDouble(), 5, 21,
            (v) => setState(() => _nSteps = (v.toInt() % 2 == 0 ? v.toInt() + 1 : v.toInt())),
            formatter: (v) => '${v.toInt()}')),
      ]),
      Row(children: [
        Expanded(child: _slider('Esposizione (s)'.tr(context), _exposureSec, 0.5, 10,
            (v) => setState(() => _exposureSec = v),
            formatter: (v) => '${v.toStringAsFixed(1)}s')),
      ]),
    ]);
  }

  Widget _slider(String label, double v, double min, double max,
      ValueChanged<double> onChanged, {required String Function(double) formatter}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: T.panel(context), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: T.line(context)),
      ),
      child: Column(children: [
        Row(children: [
          Text(label.toUpperCase(),
              style: TextStyle(color: T.muted(context), fontSize: 10, letterSpacing: 1.2)),
          const Spacer(),
          Text(formatter(v),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ]),
    );
  }

  Widget _runStatusCard() {
    final r = _runStatus!;
    final samples = (r['samples'] as List? ?? []);
    final stepIdx = r['step_idx'] ?? 0;
    final n = r['n_steps'] ?? _nSteps;
    final st = r['status'];
    Color color;
    switch (st) {
      case 'done': color = T.ok(context); break;
      case 'failed': color = T.err(context); break;
      case 'running': color = T.accent(context); break;
      default: color = T.muted(context);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.panel(context), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(st == 'running' ? Icons.sync : (st == 'done' ? Icons.check_circle : Icons.info),
              color: color, size: 16),
          const SizedBox(width: 6),
          Text('${'Run'.tr(context)}: $st', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$stepIdx/$n', style: TextStyle(color: T.muted(context), fontFamily: 'monospace')),
        ]),
        if (r['best_pos'] != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${'Best position'.tr(context)}: ${r['best_pos']} (HFR ${(r['best_hfr'] as num).toStringAsFixed(2)})',
            style: TextStyle(color: T.ok(context), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (r['error'] != null) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('⚠ ${r['error']}', style: TextStyle(color: T.err(context), fontSize: 11)),
        ),
        const SizedBox(height: 4),
        Text('${samples.length} ${'sample raccolti'.tr(context)}',
            style: TextStyle(color: T.muted(context), fontSize: 11)),
      ]),
    );
  }

  Widget _vCurveChart() {
    final samples = (_runStatus?['samples'] as List? ?? []).cast<Map>();
    if (samples.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: T.panel(context), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: T.line(context)),
        ),
        child: Center(child: Text('No data yet'.tr(context), style: TextStyle(color: T.muted(context)))),
      );
    }
    final spots = <FlSpot>[];
    double minHfr = double.infinity;
    double maxHfr = 0;
    for (final s in samples) {
      final p = (s['pos'] as num?)?.toDouble();
      final h = (s['hfr'] as num?)?.toDouble();
      if (p == null || h == null || h <= 0) continue;
      spots.add(FlSpot(p, h));
      if (h < minHfr) minHfr = h;
      if (h > maxHfr) maxHfr = h;
    }
    if (spots.isEmpty) {
      return SizedBox(height: 180, child: Center(child: Text('No HFR detected'.tr(context),
          style: TextStyle(color: T.muted(context)))));
    }
    final bestPos = (_runStatus?['best_pos'] as num?)?.toDouble();
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 6),
      decoration: BoxDecoration(
        color: T.panel(context), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: T.line(context)),
      ),
      child: LineChart(LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                  style: TextStyle(color: T.muted(context), fontSize: 9)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18,
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                  style: TextStyle(color: T.muted(context), fontSize: 9)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots, isCurved: true, color: T.accent(context), barWidth: 2,
            dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) =>
                FlDotCirclePainter(color: T.accent(context), radius: 3, strokeWidth: 0)),
          ),
        ],
        extraLinesData: bestPos == null ? null : ExtraLinesData(verticalLines: [
          VerticalLine(x: bestPos, color: T.ok(context), strokeWidth: 1, dashArray: [4, 4]),
        ]),
      )),
    );
  }

  Widget _absInput(AppState s, int? cur) {
    final ctl = TextEditingController(text: cur?.toString() ?? '');
    return Row(children: [
      Expanded(child: TextField(
        controller: ctl, keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Posizione'.tr(context), isDense: true),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 100, child: PrimaryButton(label: 'GO', icon: Icons.send, small: true,
          onPressed: () async {
            final v = int.tryParse(ctl.text);
            if (v == null) {
              showSnack(context, 'Numero non valido'.tr(context), error: true);
              return;
            }
            await _safe(() => s.api!.focuserAbs(v), '${'Vai a'.tr(context)} $v');
          })),
    ]);
  }

  num? _max(Map<String, dynamic>? prop, String name) {
    for (final e in (prop?['elements'] as List? ?? [])) {
      if (e['name'] == name) return e['max'] as num?;
    }
    return null;
  }
}
