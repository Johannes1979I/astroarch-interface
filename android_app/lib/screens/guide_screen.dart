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
