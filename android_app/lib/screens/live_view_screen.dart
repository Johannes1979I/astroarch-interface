import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LiveViewScreen extends StatelessWidget {
  const LiveViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final jpeg = s.lastFrameJpeg;
    final m = s.lastFrameMeta;
    return Scaffold(
      appBar: AppBar(title: Row(children: [const LiveDot(), const SizedBox(width: 10), Text('Live View'.tr(context))])),
      body: jpeg == null
          ? Center(child: Text('Nessun frame ricevuto…'.tr(context), style: TextStyle(color: T.muted(context))))
          : Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1.0, maxScale: 5.0,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: Image.memory(jpeg, gaplessPlayback: true, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: T.panel(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 12, runSpacing: 6, children: [
                        _kv(context, 'OBJ', m['object']?.toString() ?? '—'),
                        _kv(context, 'FILTER', m['filter']?.toString() ?? '—'),
                        _kv(context, 'EXP', m['exposure'] == null ? '—' : '${m['exposure']}s'),
                        _kv(context, 'TYPE', m['frame_type']?.toString() ?? '—'),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 6, children: [
                        _kv(context, 'HFR', (m['hfr'] as num?)?.toStringAsFixed(2) ?? '—'),
                        _kv(context, '★', '${m['stars'] ?? '—'}'),
                        _kv(context, 'SIZE', '${m['width'] ?? '—'}×${m['height'] ?? '—'}'),
                        _kv(context, 'MEDIAN', (m['median'] as num?)?.toStringAsFixed(0) ?? '—'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _kv(BuildContext c, String k, String v) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$k ', style: TextStyle(color: T.muted(c), fontSize: 10)),
      Text(v, style: TextStyle(color: T.text(c), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}
