import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../app_version.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Schermata Settings: lingua UI + tema + QR di accoppiamento + info.
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
          _sectionLabel(context, 'Accoppiamento'.tr(context)),
          Container(
            decoration: _cardDeco(context),
            child: ListTile(
              leading: Icon(Icons.qr_code_2, color: T.accent(context)),
              title: Text('Mostra QR di accoppiamento'.tr(context)),
              subtitle: Text(
                  'Per configurare un altro dispositivo'.tr(context),
                  style: TextStyle(color: T.muted(context), fontSize: 11)),
              trailing: Icon(Icons.chevron_right, color: T.muted(context)),
              onTap: s.api == null ? null : () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const _PairingQrScreen()));
              },
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
                subtitle: Text('${'Versione'.tr(context)} $kAppVersion'),
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

/// Schermata che mostra il QR generato dal bridge (con IP Tailscale).
class _PairingQrScreen extends StatefulWidget {
  const _PairingQrScreen();
  @override
  State<_PairingQrScreen> createState() => _PairingQrScreenState();
}

class _PairingQrScreenState extends State<_PairingQrScreen> {
  Map<String, dynamic>? _data;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    if (s.api == null) return;
    try {
      final r = await s.api!.pairingQr();
      if (!mounted) return;
      setState(() { _data = r; _err = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _err = e.body);
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR di accoppiamento'.tr(context)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _err != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${'Errore: '.tr(context)}$_err',
                  style: TextStyle(color: T.err(context))),
            ))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(_data!),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final pngB64 = data['png_base64'] as String?;
    final Uint8List? pngBytes = pngB64 == null ? null : base64.decode(pngB64);
    final host = data['host']?.toString() ?? '—';
    final port = data['port']?.toString() ?? '—';
    final token = data['token']?.toString() ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Scansiona dall\'app sul nuovo dispositivo'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(color: T.muted(context), fontSize: 12)),
        const SizedBox(height: 14),
        if (pngBytes != null) Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.line(context)),
          ),
          child: Image.memory(pngBytes, fit: BoxFit.contain,
              filterQuality: FilterQuality.none),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: T.panel(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: T.line(context)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Oppure inserisci a mano'.tr(context).toUpperCase(),
                style: TextStyle(color: T.muted(context),
                    fontSize: 10, letterSpacing: 1.4)),
            const SizedBox(height: 6),
            _kv(context, 'Host', host),
            _kv(context, 'Porta'.tr(context), port),
            const SizedBox(height: 8),
            Text('Token'.toUpperCase(),
                style: TextStyle(color: T.muted(context),
                    fontSize: 10, letterSpacing: 1.4)),
            const SizedBox(height: 4),
            SelectableText(token,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: Text('Copia token'.tr(context)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: token));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Token copiato'.tr(context)),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Text(
          'L\'host nel QR è l\'IP Tailscale del Raspberry: '
          'il QR funziona da qualsiasi rete con Tailscale attivo. '
          'Per la LAN usa l\'IP locale del Raspberry.'.tr(context),
          textAlign: TextAlign.center,
          style: TextStyle(color: T.muted(context), fontSize: 11),
        ),
      ]),
    );
  }

  Widget _kv(BuildContext c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 70, child: Text('$k:',
              style: TextStyle(color: T.muted(c), fontSize: 11))),
          Expanded(child: Text(v,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13))),
        ]),
      );
}
