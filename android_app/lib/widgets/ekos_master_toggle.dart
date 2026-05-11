import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Pulsante master Ekos per la Dashboard.
///
/// Replica esattamente il quadratino "Start/Stop Ekos" che si trova nel
/// pannello Setup di Ekos sul desktop: tap quando spento → avvia Ekos
/// + INDI + connetti tutti i driver del profilo. Tap quando acceso →
/// disconnetti + ferma Ekos.
///
/// Il colore segue lo stato letto via `/api/system/ekos_state`:
///   - verde   = ekos+indi entrambi "Started" (tutto collegato)
///   - rosso   = ekos OR indi "Idle"          (sistema fermo)
///   - giallo  = "Pending" (transizione, lo sappiamo per pochi secondi
///               dopo un toggle)
///   - grigio  = "unknown" (DBus non risponde / Ekos non raggiungibile)
class EkosMasterToggle extends StatefulWidget {
  const EkosMasterToggle({super.key});
  @override
  State<EkosMasterToggle> createState() => _EkosMasterToggleState();
}

class _EkosMasterToggleState extends State<EkosMasterToggle> {
  Timer? _poll;
  // Stato letto dall'API: "active" | "inactive" | "pending" | "error" | "unknown"
  String _state = 'unknown';
  bool _busy = false;
  // Quando l'utente tappa, mostriamo "pending" finché la prima risposta del
  // backend non conferma il nuovo stato (così non vede il pulsante saltare
  // da rosso → rosso → giallo → verde). Si annulla appena cambia il backend.
  String? _optimisticState;

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
      final r = await s.api!.ekosState();
      final newState = (r['active'] as String?) ?? 'unknown';
      if (!mounted) return;
      setState(() {
        _state = newState;
        // Annulla l'ottimismo solo se il backend ha "raggiunto" il target.
        // Esempio: ho tappato da inactive → optimistic=pending. Quando il
        // backend torna active O resta inactive (cioè non è più pending),
        // capisco che la transizione è finita.
        if (_optimisticState == 'pending' && newState != 'pending') {
          _optimisticState = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _state = 'unknown');
    }
  }

  Future<void> _onTap() async {
    final s = context.read<AppState>();
    if (s.api == null) return;
    setState(() {
      _busy = true;
      _optimisticState = 'pending';
    });
    try {
      await s.api!.ekosToggle();
      // Rilegge lo stato dopo 1.5s (Ekos start/stop sono asincroni)
      await Future.delayed(const Duration(milliseconds: 1500));
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'Errore: '.tr(context)}${e.body}'),
          backgroundColor: T.err(context),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'Errore: '.tr(context)}$e'),
          backgroundColor: T.err(context),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stato effettivo da mostrare (ottimistico se in transizione)
    final viewState = _optimisticState ?? _state;
    Color bg, fg;
    IconData icon;
    String label;
    String sub;
    switch (viewState) {
      case 'active':
        bg = T.ok(context);
        fg = Colors.white;
        icon = Icons.check_circle;
        label = 'SISTEMA ATTIVO'.tr(context);
        sub = 'Tutte le periferiche connesse'.tr(context);
        break;
      case 'pending':
        bg = T.warn(context);
        fg = Colors.white;
        icon = Icons.sync;
        label = 'IN TRANSIZIONE…'.tr(context);
        sub = 'Ekos sta cambiando stato'.tr(context);
        break;
      case 'error':
        bg = T.err(context);
        fg = Colors.white;
        icon = Icons.error;
        label = 'ERRORE EKOS'.tr(context);
        sub = 'Controlla i driver INDI'.tr(context);
        break;
      case 'unknown':
        bg = T.muted(context);
        fg = Colors.white;
        icon = Icons.help_outline;
        label = 'EKOS NON RAGGIUNGIBILE'.tr(context);
        sub = 'Verifica che KStars sia aperto'.tr(context);
        break;
      case 'inactive':
      default:
        bg = T.err(context);
        fg = Colors.white;
        icon = Icons.power_settings_new;
        label = 'SISTEMA DISATTIVATO'.tr(context);
        sub = 'Tap per avviare Ekos e connettere'.tr(context);
    }

    return InkWell(
      onTap: _busy ? null : _onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.4),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // Cerchio con icona/spinner
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _busy || viewState == 'pending'
                  ? SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  : Icon(icon, color: fg, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: fg, fontSize: 14, fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.82), fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.power_settings_new, color: fg.withValues(alpha: 0.6),
              size: 22),
        ]),
      ),
    );
  }
}
