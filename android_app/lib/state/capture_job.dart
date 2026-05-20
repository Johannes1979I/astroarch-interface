import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Job di acquisizione (equivalente di un "Sequence Job" di Ekos).
class CaptureJob {
  String id;          // uuid-like
  String? filter;     // L, R, G, B, Ha, OIII, SII, ... (nome o slot)
  int count;
  double exposureSec;
  double gain;
  double offset;
  int binX;
  int binY;
  String frameType;   // FRAME_LIGHT / FRAME_DARK / FRAME_FLAT / FRAME_BIAS
  String transferFormat; // FITS / NATIVE / XISF (default FITS)
  String captureFormat;  // RAW / RGB (per camere color, default RAW)
  double delaySec;    // pausa tra scatti
  bool ditherEachFrame;
  String? targetName; // opzionale (es. "M31")
  String? notes;
  // v0.2.34: setpoint temperatura sensore PER JOB (opzionale).
  // Se null, l'ESQ omette i tag <TemperatureValue>/<TemperatureEnforced>
  // → Ekos parte senza forzare nulla (usa lo stato corrente del cooler).
  // Se valorizzato, Ekos attende che la camera raggiunga il setpoint
  // prima di partire con gli scatti del job.
  double? temperatureC;

  // Stato runtime (non persistito in disk)
  CaptureJobStatus status;
  int doneCount;
  String? lastError;

  CaptureJob({
    required this.id,
    this.filter,
    this.count = 1,
    this.exposureSec = 60,
    this.gain = 100,
    this.offset = 50,
    this.binX = 1,
    this.binY = 1,
    this.frameType = 'FRAME_LIGHT',
    this.transferFormat = 'FITS',
    this.captureFormat = 'RAW',
    this.delaySec = 2,
    this.ditherEachFrame = false,
    this.targetName,
    this.notes,
    this.temperatureC,
    this.status = CaptureJobStatus.pending,
    this.doneCount = 0,
    this.lastError,
  });

  CaptureJob copy({String? newId}) => CaptureJob(
    id: newId ?? id,
    filter: filter,
    count: count,
    exposureSec: exposureSec,
    gain: gain,
    offset: offset,
    binX: binX,
    binY: binY,
    frameType: frameType,
    transferFormat: transferFormat,
    captureFormat: captureFormat,
    delaySec: delaySec,
    ditherEachFrame: ditherEachFrame,
    targetName: targetName,
    notes: notes,
    temperatureC: temperatureC,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'filter': filter,
    'count': count,
    'exposureSec': exposureSec,
    'gain': gain,
    'offset': offset,
    'binX': binX,
    'binY': binY,
    'frameType': frameType,
    'transferFormat': transferFormat,
    'captureFormat': captureFormat,
    'delaySec': delaySec,
    'ditherEachFrame': ditherEachFrame,
    'targetName': targetName,
    'notes': notes,
    'temperatureC': temperatureC,
  };

  static CaptureJob fromJson(Map<String, dynamic> j) => CaptureJob(
    id: j['id'] ?? _genId(),
    filter: j['filter'],
    count: (j['count'] as num?)?.toInt() ?? 1,
    exposureSec: (j['exposureSec'] as num?)?.toDouble() ?? 60,
    gain: (j['gain'] as num?)?.toDouble() ?? 100,
    offset: (j['offset'] as num?)?.toDouble() ?? 50,
    binX: (j['binX'] as num?)?.toInt() ?? 1,
    binY: (j['binY'] as num?)?.toInt() ?? 1,
    frameType: j['frameType'] ?? 'FRAME_LIGHT',
    transferFormat: j['transferFormat'] ?? 'FITS',
    captureFormat: j['captureFormat'] ?? 'RAW',
    delaySec: (j['delaySec'] as num?)?.toDouble() ?? 2,
    ditherEachFrame: j['ditherEachFrame'] == true,
    targetName: j['targetName'],
    notes: j['notes'],
    temperatureC: (j['temperatureC'] as num?)?.toDouble(),
  );

  static String _genId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'j_${ts.toRadixString(36)}';
  }
  static String genId() => _genId();

  String get summary {
    final bits = <String>[];
    if (filter != null && filter!.isNotEmpty) bits.add(filter!);
    bits.add(frameType.replaceFirst('FRAME_', ''));
    bits.add('${exposureSec.toStringAsFixed(exposureSec < 1 ? 2 : 0)}s');
    bits.add('×$count');
    if (temperatureC != null) bits.add('${temperatureC!.toStringAsFixed(0)}°C');
    return bits.join(' · ');
  }

  Duration get estimatedDuration => Duration(
    milliseconds: ((count * exposureSec + (count - 1).clamp(0, count) * delaySec) * 1000).round(),
  );
}

enum CaptureJobStatus {
  pending,
  running,
  done,
  failed,
  aborted,
  paused,
}

/// Storage persistente lista jobs + preset salvati.
class CaptureJobsStore {
  static const _kJobs = 'captureJobs_v1';
  static const _kPresets = 'capturePresets_v1';

  static Future<List<CaptureJob>> loadJobs() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kJobs);
    if (s == null) return [];
    try {
      final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
      return list.map(CaptureJob.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveJobs(List<CaptureJob> jobs) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kJobs, jsonEncode(jobs.map((j) => j.toJson()).toList()));
  }

  /// Preset: snapshot (nome, lista jobs).
  static Future<Map<String, List<CaptureJob>>> loadPresets() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kPresets);
    if (s == null) return {};
    try {
      final map = (jsonDecode(s) as Map).cast<String, dynamic>();
      return {
        for (final entry in map.entries)
          entry.key: ((entry.value as List).cast<Map<String, dynamic>>())
              .map(CaptureJob.fromJson)
              .toList(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePreset(String name, List<CaptureJob> jobs) async {
    final all = await loadPresets();
    all[name] = jobs;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPresets,
        jsonEncode(all.map((k, v) => MapEntry(k, v.map((j) => j.toJson()).toList()))));
  }

  static Future<void> deletePreset(String name) async {
    final all = await loadPresets();
    all.remove(name);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPresets,
        jsonEncode(all.map((k, v) => MapEntry(k, v.map((j) => j.toJson()).toList()))));
  }
}
