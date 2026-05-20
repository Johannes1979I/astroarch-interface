import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../i18n/strings.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Pannello cooler: toggle on/off, set temp target, mostra power, riconnetti driver.
/// Logica robusta per driver che fanno delProperty (es. ToupTek toupbase).
class CoolerPanel extends StatefulWidget {
  final String camera;
  final TextEditingController tempCtl;
  const CoolerPanel({super.key, required this.camera, required this.tempCtl});

  @override
  State<CoolerPanel> createState() => _CoolerPanelState();
}

class _CoolerPanelState extends State<CoolerPanel> {
  bool _busy = false;

  bool _isCoolerOn(AppState s) {
    final cooler = s.prop(widget.camera, 'CCD_COOLER');
    if (cooler != null) return propValue(cooler, 'COOLER_ON') == true;
    final p = s.prop(widget.camera, 'CCD_COOLER_POWER');
    final v = (propValue(p, 'COOLER_POWER') as num?)?.toDouble() ?? 0;
    return v > 0;
  }

  double? _power(AppState s) {
    final p = s.prop(widget.camera, 'CCD_COOLER_POWER');
    return (propValue(p, 'COOLER_POWER') as num?)?.toDouble();
  }

  double? _temp(AppState s) {
    final p = s.prop(widget.camera, 'CCD_TEMPERATURE');
    return (propValue(p, 'CCD_TEMPERATURE_VALUE') as num?)?.toDouble();
  }

  String? _tempState(AppState s) =>
      s.prop(widget.camera, 'CCD_TEMPERATURE')?['state'] as String?;

  double _f() => double.tryParse(widget.tempCtl.text.replaceAll(',', '.')) ?? -10;

  Future<void> _toggle(AppState s, bool currentlyOn) async {
    if (_busy || s.api == null) return;
    setState(() => _busy = true);
    final newState = !currentlyOn;
    final target = _f();
    // v0.2.34: anche il toggle ON-OFF persiste il setpoint corrente
    if (newState) s.setUserTargetTemperatureC(target);
    try {
      await s.api!.cameraCooler(newState, target: target, device: widget.camera);
      await Future.delayed(const Duration(milliseconds: 600));
      try { await s.api!.indiRefresh(device: widget.camera); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
      await s.refreshSnapshot();
      // Loop di verifica entro 4s
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (DateTime.now().isBefore(deadline)) {
        if (_isCoolerOn(s) == newState) break;
        await Future.delayed(const Duration(milliseconds: 400));
        await s.refreshSnapshot();
      }
      if (mounted) {
        showSnack(context, newState
            ? '${'Cooler ON · target '.tr(context)}${target.toStringAsFixed(1)}°C'
            : 'Cooler OFF'.tr(context));
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}${e.body}', error: true);
    } catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setTarget(AppState s) async {
    if (_busy || s.api == null) return;
    setState(() => _busy = true);
    final t = _f();
    // v0.2.34: persist immediato così se l'utente esce dalla schermata
    // subito dopo aver premuto IMPOSTA, il valore non si perde.
    s.setUserTargetTemperatureC(t);
    try {
      await s.api!.cameraCooler(true, target: t, device: widget.camera);
      await Future.delayed(const Duration(milliseconds: 400));
      await s.refreshSnapshot();
      if (mounted) {
        showSnack(context, '${'Target '.tr(context)}${t.toStringAsFixed(1)}${'°C inviato (cooling ~3°C/min)'.tr(context)}');
      }
    } catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reconnect(AppState s) async {
    if (_busy || s.api == null) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: T.panel(context),
      title: Text('Riconnetti driver?'.tr(context)),
      content: Text('${'Disconnette/riconnette "'.tr(context)}${widget.camera}${'". Risolve quasi tutti i blocchi del cooler.'.tr(context)}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('ANNULLA'.tr(context))),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text('RICONNETTI'.tr(context))),
      ],
    ));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      showSnack(context, 'Disconnetto…'.tr(context));
      await s.api!.indiDisconnect(widget.camera);
      await Future.delayed(const Duration(seconds: 2));
      await s.api!.indiConnect(widget.camera);
      await Future.delayed(const Duration(seconds: 3));
      await s.refreshSnapshot();
      if (mounted) showSnack(context, 'Driver riconnesso'.tr(context));
    } catch (e) {
      if (mounted) showSnack(context, '${'Errore: '.tr(context)}$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final on = _isCoolerOn(s);
    final temp = _temp(s);
    final power = _power(s);
    final tempState = _tempState(s);
    final target = _f();

    final Color tempColor = !on
        ? T.muted(context)
        : (tempState == 'Busy' ? T.warn(context) : T.ok(context));
    String label;
    if (!on) {
      label = 'cooler off'.tr(context);
    } else if (temp == null) {
      label = 'cooler on'.tr(context);
    } else if ((temp - target).abs() < 0.5) {
      label = 'target raggiunto'.tr(context);
    } else {
      label = '${'cooling… target '.tr(context)}${target.toStringAsFixed(1)}°';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.ac_unit, size: 14, color: T.muted(context)),
            const SizedBox(width: 6),
            Text('COOLER'.tr(context), style: TextStyle(
                color: T.muted(context), fontSize: 10.5, letterSpacing: 1.4)),
            const Spacer(),
            Text(label, style: TextStyle(color: T.muted(context), fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(temp == null ? '—' : '${temp.toStringAsFixed(1)} °C',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: tempColor)),
                  Row(children: [
                    Icon(Icons.bolt, size: 12, color: T.muted(context)),
                    const SizedBox(width: 3),
                    Text(power == null ? '${'POWER'.tr(context)} —' : '${'POWER'.tr(context)} ${power.toStringAsFixed(0)}%',
                        style: TextStyle(color: T.muted(context), fontSize: 11)),
                  ]),
                ],
              ),
            ),
            // Toggle button
            _toggleBtn(s, on),
          ]),
          if (on && power != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (power / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: T.line(context),
                color: T.accent(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: widget.tempCtl,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\-]'))],
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'TARGET T (°C)'.tr(context),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.thermostat, size: 16),
                label: Text('IMPOSTA'.tr(context)),
                onPressed: _busy ? null : () => _setTarget(s),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (on && (power ?? 0) == 0)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: T.warn(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: T.warn(context).withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber, color: T.warn(context), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Cooler ON ma POWER 0%. Tap "Riconnetti driver" se persiste.'.tr(context),
                  style: TextStyle(color: T.text(context), fontSize: 11),
                )),
              ]),
            ),
          GhostButton(
            label: 'Riconnetti driver'.tr(context),
            icon: Icons.refresh,
            small: true,
            onPressed: _busy ? null : () => _reconnect(s),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(AppState s, bool on) {
    final accent = on ? T.ok(context) : T.muted(context);
    final bg = on ? T.ok(context).withValues(alpha: 0.18) : Colors.transparent;
    final border = on ? T.ok(context).withValues(alpha: 0.6) : T.line(context);
    return SizedBox(
      width: 130, height: 50,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: border, width: on ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: _busy ? null : () => _toggle(s, on),
          borderRadius: BorderRadius.circular(11),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_busy)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
            else
              Icon(on ? Icons.ac_unit : Icons.power_settings_new, color: accent, size: 18),
            const SizedBox(width: 6),
            Text(_busy ? '…' : (on ? 'ON' : 'OFF'),
                style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 14)),
          ])),
        ),
      ),
    );
  }
}
