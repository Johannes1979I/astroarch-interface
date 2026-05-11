import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Schermata Settings: lingua UI + tema. Accessibile dal drawer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('Impostazioni'.tr(context))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionLabel(context, 'Lingua'.tr(context)),
          Container(
            decoration: _cardDeco(context),
            child: Column(children: [
              RadioListTile<AppLocale>(
                value: AppLocale.it,
                groupValue: s.locale,
                onChanged: (v) { if (v != null) s.setLocale(v); },
                title: Text('Italiano (predefinito)'.tr(context)),
                subtitle: Text('Italiano',
                    style: TextStyle(color: T.muted(context), fontSize: 11)),
                secondary: const Text('🇮🇹', style: TextStyle(fontSize: 22)),
              ),
              const Divider(height: 1),
              RadioListTile<AppLocale>(
                value: AppLocale.en,
                groupValue: s.locale,
                onChanged: (v) { if (v != null) s.setLocale(v); },
                title: Text('English'.tr(context)),
                subtitle: Text('English',
                    style: TextStyle(color: T.muted(context), fontSize: 11)),
                secondary: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          _sectionLabel(context, 'Aspetto'.tr(context)),
          Container(
            decoration: _cardDeco(context),
            child: SwitchListTile(
              title: Text(s.nightMode
                  ? 'Tema Notte'.tr(context)
                  : 'Tema Pro'.tr(context)),
              subtitle: Text(s.nightMode
                  ? 'Tema scuro adatto al campo'.tr(context)
                  : 'Tema standard più chiaro'.tr(context),
                  style: TextStyle(color: T.muted(context), fontSize: 11)),
              secondary: Icon(s.nightMode
                  ? Icons.nightlight_round : Icons.wb_sunny,
                  color: T.accent(context)),
              value: s.nightMode,
              onChanged: (v) => s.setNight(v),
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel(context, 'Info app'.tr(context)),
          Container(
            decoration: _cardDeco(context),
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: T.accent(context)),
                title: const Text('Astroarch Interface'),
                subtitle: Text('${'Versione'.tr(context)} 0.2.16'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person_outline, color: T.accent(context)),
                title: const Text('Zarletti-Osservatorio Jupiter'),
                subtitle: Text('${s.host}:${s.port}',
                    style: TextStyle(color: T.muted(context), fontSize: 11,
                        fontFamily: 'monospace')),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Text(t.toUpperCase(),
            style: TextStyle(fontSize: 10, color: T.muted(c),
                letterSpacing: 2, fontWeight: FontWeight.w700)),
      );

  BoxDecoration _cardDeco(BuildContext c) => BoxDecoration(
        color: T.panel(c),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line(c)),
      );
}
