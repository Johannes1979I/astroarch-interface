import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Card "Avvia KStars / PHD2" nella Dashboard.
/// Due pulsanti che spawnano i binari sul DISPLAY del RPi (la finestra
/// appare sul monitor del RPi, non sul telefono). Mostra indicatore live
/// dello stato (in esecuzione / da avviare) via polling ogni 3s.
class LaunchAppsCard extends StatefulWidget {
  const LaunchAppsCard({super.key});
  @override
  State<LaunchAppsCard> createState() => _LaunchAppsCardState();
}

class _LaunchAppsCardState extends State<LaunchAppsCard> {
  Timer? _poll;
  bool _kstarsRunning = false;
  bool _phd2Running = false;
  bool _kstarsBusy = false;
  bool _phd2Busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = context.read<AppState>();
    if (s.api == null) return;
    try {
      final r = await s.api!.guiAppsState();
      if (!mounted) return;
      setState(() {
        _kstarsRunning = r['kstars_running'] == true;
        _phd2Running = r['phd2_running'] == true;
      });
    } catch (_) {}
  }

  Future<void> _launchKStars() async {
    final s = context.read<AppState>();
    if (s.api == null) return;
    setState(() => _kstarsBusy = true);
    try {
      final r = await s.api!.launchKStars();
      if (!mounted) return;
      if (r['already_running'] == true) {
        showSnack(context, 'KStars già in esecuzione'.tr(context));
      } else {
        showSnack(context, 'KStars avviato sul desktop del RPi'.tr(context));
      }
      // Rilegge dopo 1.5s per vedere il processo
      await Future.delayed(const Duration(milliseconds: 1500));
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) showSnack(context,
          '${'Errore: '.tr(context)}${e.body}', error: true);
    } catch (e) {
      if (mounted) showSnack(context,
          '${'Errore: '.tr(context)}$e', error: true);
    } finally {
      if (mounted) setState(() => _kstarsBusy = false);
    }
  }

  Future<void> _launchPhd2() async {
    final s = context.read<AppState>();
    if (s.api == null) return;
    setState(() => _phd2Busy = true);
    try {
      final r = await s.api!.launchPhd2();
      if (!mounted) return;
      if (r['already_running'] == true) {
        showSnack(context, 'PHD2 già in esecuzione'.tr(context));
      } else {
        showSnack(context, 'PHD2 avviato sul desktop del RPi'.tr(context));
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) showSnack(context,
          '${'Errore: '.tr(context)}${e.body}', error: true);
    } catch (e) {
      if (mounted) showSnack(context,
          '${'Errore: '.tr(context)}$e', error: true);
    } finally {
      if (mounted) setState(() => _phd2Busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: T.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.rocket_launch, size: 14, color: T.muted(context)),
          const SizedBox(width: 6),
          Text('AVVIO PROGRAMMI'.tr(context),
              style: TextStyle(color: T.muted(context),
                  fontSize: 10, letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('sul desktop del RPi'.tr(context),
              style: TextStyle(color: T.muted(context),
                  fontSize: 10, fontStyle: FontStyle.italic)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _appButton(
            label: 'KSTARS / EKOS',
            icon: Icons.public,
            running: _kstarsRunning,
            busy: _kstarsBusy,
            onTap: _launchKStars,
          )),
          const SizedBox(width: 8),
          Expanded(child: _appButton(
            label: 'PHD2',
            icon: Icons.gps_fixed,
            running: _phd2Running,
            busy: _phd2Busy,
            onTap: _launchPhd2,
          )),
        ]),
      ]),
    );
  }

  Widget _appButton({
    required String label, required IconData icon,
    required bool running, required bool busy,
    required VoidCallback onTap,
  }) {
    final Color bgColor = running
        ? T.ok(context).withValues(alpha: 0.15)
        : T.accent(context).withValues(alpha: 0.10);
    final Color borderColor = running
        ? T.ok(context).withValues(alpha: 0.5)
        : T.accent(context).withValues(alpha: 0.4);
    final Color fgColor = running ? T.ok(context) : T.accent(context);

    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          if (busy)
            SizedBox(width: 16, height: 16, child:
                CircularProgressIndicator(strokeWidth: 2, color: fgColor))
          else
            Icon(running ? Icons.check_circle : icon,
                color: fgColor, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(label,
                style: TextStyle(color: fgColor, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: .3),
                overflow: TextOverflow.ellipsis),
            Text(running
                    ? 'in esecuzione'.tr(context)
                    : 'avvia'.tr(context),
                style: TextStyle(color: fgColor.withValues(alpha: 0.8),
                    fontSize: 10)),
          ])),
        ]),
      ),
    );
  }
}
