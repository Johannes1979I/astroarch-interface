import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../i18n/strings.dart';
import '../../state/app_state.dart';
import '../../state/capture_job.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Form per creare o modificare un CaptureJob.
class JobFormScreen extends StatefulWidget {
  final CaptureJob? initial;
  final List<String> filters;
  const JobFormScreen({super.key, this.initial, this.filters = const []});

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  late final TextEditingController _expCtl;
  late final TextEditingController _gainCtl;
  late final TextEditingController _offsetCtl;
  late final TextEditingController _countCtl;
  late final TextEditingController _delayCtl;
  late final TextEditingController _targetCtl;
  late String? _filter;
  late int _bin;
  late String _frameType;
  late String _transferFormat;
  late String _captureFormat;
  late bool _dither;

  @override
  void initState() {
    super.initState();
    final j = widget.initial;
    _expCtl = TextEditingController(text: '${j?.exposureSec ?? 60}');
    _gainCtl = TextEditingController(text: '${(j?.gain ?? 100).toInt()}');
    _offsetCtl = TextEditingController(text: '${(j?.offset ?? 50).toInt()}');
    _countCtl = TextEditingController(text: '${j?.count ?? 20}');
    _delayCtl = TextEditingController(text: '${j?.delaySec ?? 2}');
    _targetCtl = TextEditingController(text: j?.targetName ?? '');
    _filter = j?.filter;
    _bin = j?.binX ?? 1;
    _frameType = j?.frameType ?? 'FRAME_LIGHT';
    _transferFormat = j?.transferFormat ?? 'FITS';
    _captureFormat = j?.captureFormat ?? 'RAW';
    _dither = j?.ditherEachFrame ?? false;
  }

  @override
  void dispose() {
    _expCtl.dispose();
    _gainCtl.dispose();
    _offsetCtl.dispose();
    _countCtl.dispose();
    _delayCtl.dispose();
    _targetCtl.dispose();
    super.dispose();
  }

  void _save() {
    final j = (widget.initial ?? CaptureJob(id: CaptureJob.genId()));
    j.exposureSec = double.tryParse(_expCtl.text.replaceAll(',', '.')) ?? 60;
    j.gain = double.tryParse(_gainCtl.text) ?? 100;
    j.offset = double.tryParse(_offsetCtl.text) ?? 50;
    j.count = int.tryParse(_countCtl.text)?.clamp(1, 9999) ?? 1;
    j.delaySec = double.tryParse(_delayCtl.text) ?? 2;
    j.binX = _bin;
    j.binY = _bin;
    j.frameType = _frameType;
    j.transferFormat = _transferFormat;
    j.captureFormat = _captureFormat;
    j.filter = _filter;
    j.ditherEachFrame = _dither;
    j.targetName = _targetCtl.text.trim().isEmpty ? null : _targetCtl.text.trim();
    if (j.exposureSec <= 0 || j.count <= 0) {
      showSnack(context, 'Tempo e count devono essere > 0'.tr(context), error: true);
      return;
    }
    Navigator.pop(context, j);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nuovo job'.tr(context) : 'Modifica job'.tr(context)),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: Icon(Icons.check, color: T.accent(context)),
            label: Text('SALVA'.tr(context),
                style: TextStyle(color: T.accent(context), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SectionLabel('Filter'.tr(context)),
          if (widget.filters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Nessun filter wheel disponibile (filter ignorato)'.tr(context),
                  style: TextStyle(color: T.muted(context), fontSize: 11)),
            )
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              ChipToggle(label: '— libero —'.tr(context), selected: _filter == null,
                  onTap: () => setState(() => _filter = null)),
              for (final f in widget.filters)
                ChipToggle(label: f, selected: _filter == f,
                    onTap: () => setState(() => _filter = f)),
            ]),
          SectionLabel('Frame type'.tr(context)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final ft in const ['FRAME_LIGHT', 'FRAME_DARK', 'FRAME_FLAT', 'FRAME_BIAS'])
              ChipToggle(
                label: ft.replaceFirst('FRAME_', ''),
                selected: _frameType == ft,
                onTap: () => setState(() => _frameType = ft),
              ),
          ]),
          SectionLabel('Formato file (transfer)'.tr(context)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in const ['FITS', 'NATIVE', 'XISF'])
              ChipToggle(
                label: f,
                selected: _transferFormat == f,
                onTap: () => setState(() => _transferFormat = f),
              ),
          ]),
          SectionLabel('Formato sensore (color cam)'.tr(context)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChipToggle(label: 'RAW (Bayer)'.tr(context), selected: _captureFormat == 'RAW',
                onTap: () => setState(() => _captureFormat = 'RAW')),
            ChipToggle(label: 'RGB (debayered)'.tr(context), selected: _captureFormat == 'RGB',
                onTap: () => setState(() => _captureFormat = 'RGB')),
          ]),
          SectionLabel('Binning'.tr(context)),
          Row(children: [
            for (final b in [1, 2, 3, 4]) ...[
              Expanded(child: ChipToggle(
                label: '${b}×$b',
                selected: _bin == b,
                onTap: () => setState(() => _bin = b),
              )),
              if (b < 4) const SizedBox(width: 4),
            ]
          ]),
          SectionLabel('Esposizione'.tr(context)),
          Row(children: [
            Expanded(child: _num(_expCtl, 'TEMPO (s)'.tr(context), '60', decimal: true)),
            const SizedBox(width: 8),
            Expanded(child: _num(_countCtl, 'COUNT'.tr(context), '20')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _num(_gainCtl, 'GAIN'.tr(context), '100')),
            const SizedBox(width: 8),
            Expanded(child: _num(_offsetCtl, 'OFFSET'.tr(context), '50')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _num(_delayCtl, 'DELAY (s)'.tr(context), '2', decimal: true)),
            const SizedBox(width: 8),
            Expanded(
              child: SwitchListTile(
                title: Text('Dither'.tr(context), style: const TextStyle(fontSize: 13)),
                value: _dither,
                onChanged: (v) => setState(() => _dither = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ]),
          SectionLabel('Target (opzionale)'.tr(context)),
          TextField(
            controller: _targetCtl,
            decoration: InputDecoration(
              hintText: 'M 31, NGC 7000, …'.tr(context),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label, String hint, {bool decimal = false}) {
    return Container(
      decoration: BoxDecoration(
        color: T.panel(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: T.line(context)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: T.muted(context), fontSize: 10, letterSpacing: 1.2)),
        TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: false),
          inputFormatters: [
            if (decimal)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(color: T.muted(context)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ]),
    );
  }
}
