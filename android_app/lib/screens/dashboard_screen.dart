import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/ekos_master_toggle.dart';
import 'live_view_screen.dart';
import 'shell_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: openShellDrawer),
        title: Row(children: [const LiveDot(), const SizedBox(width: 10), Text('Dashboard'.tr(context))]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () async {
              final ok = await state.refreshSnapshot();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Snapshot aggiornato'.tr(context) : 'Refresh fallito'.tr(context)),
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Badge versione app: SEMPRE allineato all'APK installato.
                  // La costante kAppVersion (lib/app_version.dart) deve
                  // essere bumpata ad ogni release insieme a pubspec.yaml.
                  Text('v$kAppVersion',
                      style: TextStyle(color: T.accent(context),
                          fontSize: 11, fontWeight: FontWeight.w700,
                          fontFamily: 'monospace')),
                  Text('${state.devices.length} dev',
                      style: TextStyle(color: T.muted(context), fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await state.refreshSnapshot();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // Pulsante master Attiva/Disattiva — clone del quadratino
            // Start/Stop Ekos del pannello Setup. Verde=tutto su, rosso=tutto giù.
            const EkosMasterToggle(),
            const SizedBox(height: 12),
            _connectionBanner(context, state),
            const SizedBox(height: 10),
            _targetCard(context, state),
            const SizedBox(height: 12),
            _lastFrame(context, state),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                _mountCard(context, state),
                _cameraCard(context, state),
                _guideCard(context, state),
                _focuserCard(context, state),
              ],
            ),
            SectionLabel('Sequenza in corso'.tr(context)),
            _sequenceProgress(context, state),
            SectionLabel('Telemetria osservatorio'.tr(context)),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: [
                _weatherCard(context, state),
                _domeCard(context, state),
              ],
            ),
            if (state.messages.isNotEmpty) ...[
              SectionLabel('Ultimi messaggi'.tr(context)),
              ...state.messages.reversed.take(3).map((m) => _msgRow(context, m)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _connectionBanner(BuildContext c, AppState s) {
    Color dot(String state) {
      switch (state) {
        case 'connected': return T.ok(c);
        case 'reconnecting':
        case 'connecting':
        case 'pinging':
          return T.warn(c);
        default: return T.err(c);
      }
    }
    Widget pill(String label, String state) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: dot(state), shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label: ', style: TextStyle(color: T.muted(c), fontSize: 10.5)),
        Text(state, style: TextStyle(color: dot(state), fontSize: 10.5, fontWeight: FontWeight.w600)),
      ],
    );

    final allOk = s.indiConn == 'connected' && s.wsStateLabel == 'connected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: T.panel(c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: allOk ? T.ok(c).withValues(alpha: 0.3) : T.warn(c).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14, runSpacing: 4,
            children: [
              pill('INDI', s.indiConn),
              pill('PHD2', s.phd2Conn),
              pill('WS state', s.wsStateLabel),
              pill('WS frames', s.wsFramesLabel),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'WS events: ${s.wsEventsReceived}',
                style: TextStyle(color: T.muted(c), fontSize: 10, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 12),
              if (s.lastWsEventType != null)
                Text(
                  'last: ${s.lastWsEventType}',
                  style: TextStyle(color: T.muted(c), fontSize: 10, fontFamily: 'monospace'),
                ),
              const Spacer(),
              if (s.snapshotInProgress)
                Text(
                  'syncing ${s.properties.length}/${s.wsExpectedProperties}…',
                  style: TextStyle(color: T.warn(c), fontSize: 10, fontFamily: 'monospace'),
                )
              else
                Text(
                  '${s.properties.length} props',
                  style: TextStyle(color: T.muted(c), fontSize: 10, fontFamily: 'monospace'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetCard(BuildContext c, AppState s) {
    final m = s.mountDevice();
    if (m == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.panel(c),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.line(c)),
        ),
        child: Text('Nessun mount connesso ad Ekos'.tr(c),
            style: TextStyle(color: T.muted(c), fontSize: 13)),
      );
    }
    final coord = s.prop(m, 'EQUATORIAL_EOD_COORD');
    final ra = (propValue(coord, 'RA') as num?)?.toDouble();
    final dec = (propValue(coord, 'DEC') as num?)?.toDouble();
    return TargetCard(
      title: m,
      subtitle: coord?['state'] ?? '',
      rows: [
        MapEntry('RA', ra == null ? '—' : _hms(ra)),
        MapEntry('Dec', dec == null ? '—' : _dms(dec)),
        MapEntry('State', coord?['state'] ?? '—'),
        MapEntry('Group', coord?['group'] ?? '—'),
      ],
    );
  }

  Widget _lastFrame(BuildContext c, AppState s) {
    final hasFrame = s.lastFrameJpeg != null;
    return InkWell(
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LiveViewScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.line(c)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasFrame)
              Image.memory(s.lastFrameJpeg!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, color: T.muted(c), size: 36),
                    const SizedBox(height: 6),
                    Text('In attesa del primo scatto…'.tr(c), style: TextStyle(color: T.muted(c), fontSize: 12)),
                  ],
                ),
              ),
            if (hasFrame)
              Positioned(
                left: 10, top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    [
                      s.lastFrameMeta['filter'],
                      if (s.lastFrameMeta['exposure'] != null) '${s.lastFrameMeta['exposure']}s',
                      s.lastFrameMeta['frame_type'],
                    ].whereType<String>().join(' · '),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            if (hasFrame)
              Positioned(
                right: 10, bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'HFR ${(s.lastFrameMeta['hfr'] ?? 0).toStringAsFixed(2)} · ★ ${s.lastFrameMeta['stars'] ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mountCard(BuildContext c, AppState s) {
    final m = s.mountDevice();
    final track = m == null ? null : s.prop(m, 'TELESCOPE_TRACK_STATE');
    final on = (propValue(track, 'TRACK_ON') == true);
    return StatusCard(
      header: 'MOUNT',
      value: on ? 'Tracking' : 'Idle',
      subtitle: m ?? 'no mount',
      badgeColor: on ? T.ok(c) : T.muted(c),
      badgeText: on ? 'on' : 'off',
    );
  }

  Widget _cameraCard(BuildContext c, AppState s) {
    final cam = s.cameraDevice();
    final temp = cam == null ? null : s.prop(cam, 'CCD_TEMPERATURE');
    final t = (propValue(temp, 'CCD_TEMPERATURE_VALUE') as num?)?.toDouble();
    return StatusCard(
      header: 'CAMERA',
      value: t == null ? '—' : '${t.toStringAsFixed(1)} °C',
      subtitle: cam ?? 'no camera',
      badgeColor: T.accent2(c),
      badgeText: cam != null ? 'on' : null,
    );
  }

  Widget _guideCard(BuildContext c, AppState s) {
    final rms = s.phd2Live['rms_total'];
    final st = s.phd2Live['app_state'] ?? 'Stopped';
    return StatusCard(
      header: 'GUIDE',
      value: rms == null ? '—' : 'RMS ${(rms as num).toStringAsFixed(2)}″',
      subtitle: 'PHD2 · $st',
      badgeColor: st == 'Guiding' ? T.ok(c) : T.muted(c),
      badgeText: st == 'Guiding' ? 'on' : st.toString(),
    );
  }

  Widget _focuserCard(BuildContext c, AppState s) {
    final f = s.focuserDevice();
    final pos = f == null ? null : s.prop(f, 'ABS_FOCUS_POSITION');
    final v = propValue(pos, 'FOCUS_ABSOLUTE_POSITION');
    return StatusCard(
      header: 'FOCUS',
      value: v == null ? '—' : '$v',
      subtitle: f ?? 'no focuser',
      badgeColor: T.accent(c),
      badgeText: f != null ? 'idle' : null,
    );
  }

  Widget _sequenceProgress(BuildContext c, AppState s) {
    // Cerca CCD_EXPOSURE per progress dell'esposizione corrente
    final cam = s.cameraDevice();
    final exp = cam == null ? null : s.prop(cam, 'CCD_EXPOSURE');
    final remaining = (propValue(exp, 'CCD_EXPOSURE_VALUE') as num?)?.toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.panel(c),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(c)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Esposizione corrente'.tr(c), style: TextStyle(color: T.text(c), fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                exp?['state'] ?? '—',
                style: TextStyle(color: exp?['state'] == 'Busy' ? T.accent(c) : T.muted(c), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: exp?['state'] == 'Busy' ? null : 0.0,
            backgroundColor: T.line(c),
            color: T.accent(c),
            minHeight: 5,
          ),
          const SizedBox(height: 6),
          Text(
            remaining == null ? 'idle' : '${remaining.toStringAsFixed(0)}s ${'rimanenti'.tr(c)}',
            style: TextStyle(color: T.muted(c), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _weatherCard(BuildContext c, AppState s) {
    // Cerca un device con WEATHER_PARAMETERS
    String dev = s.findDeviceByProperty('WEATHER_PARAMETERS') ?? '';
    final wp = dev.isEmpty ? null : s.prop(dev, 'WEATHER_PARAMETERS');
    String value = '—';
    String sub = dev.isEmpty ? 'no weather' : dev;
    if (wp != null) {
      final elements = (wp['elements'] as List? ?? []).cast<Map>();
      final temp = elements.firstWhere((e) => '${e['name']}'.contains('TEMP'),
          orElse: () => <String, dynamic>{});
      final v = temp['value'];
      if (v is num) value = '${v.toStringAsFixed(1)} °C';
    }
    return StatusCard(header: 'WEATHER', value: value, subtitle: sub);
  }

  Widget _domeCard(BuildContext c, AppState s) {
    String dev = s.findDeviceByProperty('DOME_SHUTTER') ?? '';
    final p = dev.isEmpty ? null : s.prop(dev, 'DOME_SHUTTER');
    bool open = false;
    for (final e in (p?['elements'] as List? ?? [])) {
      if (e['name'] == 'SHUTTER_OPEN' && e['value'] == true) open = true;
    }
    return StatusCard(
      header: 'DOME',
      value: dev.isEmpty ? '—' : (open ? 'Aperto'.tr(c) : 'Chiuso'.tr(c)),
      subtitle: dev.isEmpty ? 'no dome' : dev,
      badgeColor: open ? T.ok(c) : T.warn(c),
      badgeText: open ? 'open' : 'close',
    );
  }

  Widget _msgRow(BuildContext c, Map<String, dynamic> m) {
    final ts = (m['ts'] as num?)?.toDouble();
    final time = ts != null ? DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt()) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time == null ? '' : '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}',
              style: TextStyle(color: T.muted(c), fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${m['device'] ?? ''} ${m['message'] ?? ''}'.trim(),
                style: TextStyle(color: T.text(c), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  String _hms(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).floor();
    final s = (((hours - h) * 60 - m) * 60).round();
    return '${h.toString().padLeft(2,'0')}h ${m.toString().padLeft(2,'0')}m ${s.toString().padLeft(2,'0')}s';
  }

  String _dms(double deg) {
    final sign = deg < 0 ? '-' : '+';
    final a = deg.abs();
    final d = a.floor();
    final m = ((a - d) * 60).floor();
    final s = (((a - d) * 60 - m) * 60).round();
    return '$sign${d.toString().padLeft(2,'0')}° ${m.toString().padLeft(2,'0')}′ ${s.toString().padLeft(2,'0')}″';
  }
}
