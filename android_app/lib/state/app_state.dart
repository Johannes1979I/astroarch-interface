import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/ws_client.dart';
import '../i18n/strings.dart';
import 'capture_job.dart';

/// Stato globale dell'app.
/// - Configurazione di connessione (host/porta/token) persistente
/// - Modello "specchio" del bridge: properties INDI, PHD2 live, last frame, ecc.
/// - Notifica i listener su ogni cambiamento (Provider/ChangeNotifier)
class AppState extends ChangeNotifier {
  // --- Connection config ---
  String host = '';
  int port = 8765;
  String token = '';
  bool nightMode = false;
  bool useHttps = false;
  // Lingua UI — IT è default ("Zarletti-Osservatorio Jupiter" è italiano).
  // Cambiabile da Settings; persistente via SharedPreferences (chiave 'locale').
  AppLocale locale = AppLocale.it;

  // Device selezionato per ogni ruolo (persistente, override automatico se >1 device)
  String? selectedCamera;
  String? selectedMount;
  String? selectedFocuser;
  String? selectedFilterWheel;

  // --- Active target (oggetto inquadrato dall'utente) ---------------------
  // Il target è memorizzato qui IN APP, persistente. Ogni volta che cambia
  // viene anche spinto su Ekos via setTargetCoords così Ekos resta allineato
  // (NB: KStars "Center & Slew" non aggiorna automaticamente Align.target,
  // questo è il fix architetturale).
  String? activeTargetName;
  double? activeTargetRaHours;
  double? activeTargetDecDeg;

  // Ruoli camere auto-rilevati dal backend (PHD2 / heuristic)
  String? primaryCameraAuto;
  String? guideCameraAuto;
  String? cameraRolesMethod; // "phd2" | "heuristic" | "single" | "none"

  // Lista capture jobs (multi-job sequencer Ekos-style)
  List<CaptureJob> captureJobs = [];

  Future<void> loadCaptureJobs() async {
    captureJobs = await CaptureJobsStore.loadJobs();
    notifyListeners();
  }
  Future<void> saveCaptureJobs() async {
    await CaptureJobsStore.saveJobs(captureJobs);
  }
  void addCaptureJob(CaptureJob j) {
    captureJobs.add(j);
    saveCaptureJobs();
    notifyListeners();
  }
  void updateCaptureJob(int idx, CaptureJob j) {
    if (idx < 0 || idx >= captureJobs.length) return;
    captureJobs[idx] = j;
    saveCaptureJobs();
    notifyListeners();
  }
  void removeCaptureJob(int idx) {
    if (idx < 0 || idx >= captureJobs.length) return;
    captureJobs.removeAt(idx);
    saveCaptureJobs();
    notifyListeners();
  }
  void duplicateCaptureJob(int idx) {
    if (idx < 0 || idx >= captureJobs.length) return;
    captureJobs.insert(idx + 1, captureJobs[idx].copy(newId: CaptureJob.genId()));
    saveCaptureJobs();
    notifyListeners();
  }
  void reorderCaptureJobs(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx -= 1;
    final j = captureJobs.removeAt(oldIdx);
    captureJobs.insert(newIdx, j);
    saveCaptureJobs();
    notifyListeners();
  }
  void resetJobsStatus() {
    for (final j in captureJobs) {
      j.status = CaptureJobStatus.pending;
      j.doneCount = 0;
      j.lastError = null;
    }
    notifyListeners();
  }

  // --- Connection runtime ---
  String connectionStateLabel = 'disconnected';
  String wsStateLabel = 'disconnected';
  String wsFramesLabel = 'disconnected';
  ApiClient? api;
  WsClient? _wsState;
  WsClient? _wsFrames;

  // --- Mirrored state ---
  // properties indexed by "device::name"
  final Map<String, Map<String, dynamic>> properties = {};
  final Set<String> devices = {};
  String indiConn = 'disconnected';
  String phd2Conn = 'disconnected';
  Map<String, dynamic> phd2Live = {};
  Map<String, dynamic> lastFrameMeta = {};
  Uint8List? lastFrameJpeg;
  Map<String, dynamic>? _pendingFrameMeta;
  final List<Map<String, dynamic>> messages = [];
  // PHD2 history for charts (last N entries)
  final List<Map<String, dynamic>> phd2History = [];
  static const int _phd2HistoryMax = 120;

  // Diagnostica: counter eventi WS ricevuti + ultimo tipo
  int wsEventsReceived = 0;
  String? lastWsEventType;
  int wsExpectedProperties = 0;  // dato dal snapshot_begin
  bool snapshotInProgress = false;

  // --- Persistence ---
  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    host = p.getString('host') ?? '';
    port = p.getInt('port') ?? 8765;
    token = p.getString('token') ?? '';
    nightMode = p.getBool('night') ?? false;
    useHttps = p.getBool('https') ?? false;
    final loc = p.getString('locale');
    locale = (loc == 'en') ? AppLocale.en : AppLocale.it;
    selectedCamera = p.getString('selectedCamera');
    selectedMount = p.getString('selectedMount');
    selectedFocuser = p.getString('selectedFocuser');
    selectedFilterWheel = p.getString('selectedFilterWheel');
    activeTargetName = p.getString('activeTargetName');
    activeTargetRaHours = p.getDouble('activeTargetRaHours');
    activeTargetDecDeg = p.getDouble('activeTargetDecDeg');
    notifyListeners();
  }

  Future<void> savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('host', host);
    await p.setInt('port', port);
    await p.setString('token', token);
    await p.setBool('night', nightMode);
    await p.setBool('https', useHttps);
    await p.setString('locale', locale == AppLocale.en ? 'en' : 'it');
    if (selectedCamera != null) await p.setString('selectedCamera', selectedCamera!); else await p.remove('selectedCamera');
    if (selectedMount != null) await p.setString('selectedMount', selectedMount!); else await p.remove('selectedMount');
    if (selectedFocuser != null) await p.setString('selectedFocuser', selectedFocuser!); else await p.remove('selectedFocuser');
    if (selectedFilterWheel != null) await p.setString('selectedFilterWheel', selectedFilterWheel!); else await p.remove('selectedFilterWheel');
    if (activeTargetName != null) await p.setString('activeTargetName', activeTargetName!); else await p.remove('activeTargetName');
    if (activeTargetRaHours != null) await p.setDouble('activeTargetRaHours', activeTargetRaHours!); else await p.remove('activeTargetRaHours');
    if (activeTargetDecDeg != null) await p.setDouble('activeTargetDecDeg', activeTargetDecDeg!); else await p.remove('activeTargetDecDeg');
  }

  /// Imposta il target attivo (nome + RA/Dec) localmente e lo spinge a Ekos
  /// via /api/align/ekos_align_set (idempotente).
  /// Se nome è null, usa una stringa formattata dalle coordinate.
  Future<void> setActiveTarget({
    String? name, required double raHours, required double decDeg,
    bool pushToEkos = true,
  }) async {
    activeTargetName = name;
    activeTargetRaHours = raHours;
    activeTargetDecDeg = decDeg;
    notifyListeners();
    await savePrefs();
    if (pushToEkos && api != null) {
      try {
        await api!.alignEkosSet(targetRaHours: raHours, targetDecDeg: decDeg);
      } catch (_) {
        // Non bloccare l'UI se Ekos non risponde — il valore è comunque
        // salvato in app e verrà ri-spinto prima del prossimo captureAndSolve.
      }
    }
  }

  /// Cancella il target attivo (locale + Ekos resta come è).
  Future<void> clearActiveTarget() async {
    activeTargetName = null;
    activeTargetRaHours = null;
    activeTargetDecDeg = null;
    notifyListeners();
    await savePrefs();
  }

  /// Lista dei device che espongono una certa property INDI (es CCD_EXPOSURE = camere).
  List<String> devicesWithProperty(String propName) {
    final out = <String>{};
    for (final p in properties.values) {
      if (p['name'] == propName) out.add(p['device'] as String);
    }
    final list = out.toList()..sort();
    return list;
  }

  List<String> get cameraDevices => devicesWithProperty('CCD_EXPOSURE');
  List<String> get mountDevices => devicesWithProperty('EQUATORIAL_EOD_COORD');
  List<String> get focuserDevices => devicesWithProperty('ABS_FOCUS_POSITION');
  List<String> get filterWheelDevices => devicesWithProperty('FILTER_SLOT');

  /// Restituisce il device "effettivo" da usare per le chiamate API.
  /// Logica: se l'utente ha selezionato uno e c'è ancora connesso -> usa quello.
  /// Altrimenti, se c'è un solo device disponibile -> usa quello (auto).
  /// Altrimenti null -> serve scelta utente.
  String? effectiveDevice(String role) {
    final list = switch (role) {
      'camera' => cameraDevices,
      'mount' => mountDevices,
      'focuser' => focuserDevices,
      'filter_wheel' => filterWheelDevices,
      _ => <String>[],
    };
    if (list.isEmpty) return null;
    final selected = switch (role) {
      'camera' => selectedCamera,
      'mount' => selectedMount,
      'focuser' => selectedFocuser,
      'filter_wheel' => selectedFilterWheel,
      _ => null,
    };
    if (selected != null && list.contains(selected)) return selected;
    if (list.length == 1) return list.first;
    // Camera: usa primary auto-rilevata da Ekos/PHD2 se ce l'abbiamo
    if (role == 'camera' && primaryCameraAuto != null && list.contains(primaryCameraAuto!)) {
      return primaryCameraAuto;
    }
    return null; // ambiguo, serve scelta
  }

  void setSelectedDevice(String role, String? device) {
    switch (role) {
      case 'camera': selectedCamera = device; break;
      case 'mount': selectedMount = device; break;
      case 'focuser': selectedFocuser = device; break;
      case 'filter_wheel': selectedFilterWheel = device; break;
    }
    savePrefs();
    notifyListeners();
  }

  void setNight(bool v) {
    nightMode = v;
    savePrefs();
    notifyListeners();
  }

  void setLocale(AppLocale l) {
    locale = l;
    savePrefs();
    notifyListeners();
  }

  String get baseUrl =>
      '${useHttps ? "https" : "http"}://$host:$port';

  Uri _wsUri(String path) {
    final scheme = useHttps ? 'wss' : 'ws';
    return Uri.parse('$scheme://$host:$port$path?token=${Uri.encodeQueryComponent(token)}');
  }

  // --- Connect / Disconnect ---

  // Errore dell'ultimo connect, mostrato sulla Login se !=null
  String? lastConnectError;

  Future<bool> connect() async {
    // IMPORTANTE: NON assegnare api prima che ping abbia successo,
    // altrimenti main.dart passa subito a ShellScreen e l'utente
    // si ritrova dentro la dashboard senza connessione reale.
    final probe = ApiClient(baseUrl: baseUrl, token: token);
    connectionStateLabel = 'pinging';
    lastConnectError = null;
    notifyListeners();

    bool pingOk = false;
    try {
      pingOk = await probe.ping();
    } catch (e) {
      lastConnectError = 'Ping exception: $e';
    }
    if (!pingOk) {
      connectionStateLabel = 'unreachable';
      lastConnectError ??= 'Bridge non raggiungibile su $baseUrl (timeout o cleartext bloccato).';
      probe.close();
      notifyListeners();
      return false;
    }

    // Verifica auth + raggiungibilità con info endpoint
    try {
      await probe.info();
    } catch (e) {
      lastConnectError = 'Bridge raggiunto ma auth/info fallito: $e';
      connectionStateLabel = 'auth_failed';
      probe.close();
      notifyListeners();
      return false;
    }

    // Snapshot iniziale (potrebbe essere lento se molti device)
    Map<String, dynamic>? snap;
    try {
      snap = await probe.snapshot();
    } catch (e) {
      lastConnectError = 'Snapshot REST fallito: $e';
      connectionStateLabel = 'snapshot_failed';
      probe.close();
      notifyListeners();
      return false;
    }

    // Solo ora promuoviamo il client a "ufficiale"
    api = probe;
    connectionStateLabel = 'connected';
    _ingestSnapshot(snap);
    notifyListeners();

    // Best-effort: chiedi al backend chi è camera primaria / guida (Ekos/PHD2)
    _refreshCameraRoles();

    // Avvia WS state
    await _wsState?.stop();
    _wsState = WsClient(
      uri: _wsUri('/ws/state'),
      onState: (s) { wsStateLabel = s; notifyListeners(); },
      onJson: _ingestWsJson,
    );
    await _wsState!.start();

    // Avvia WS frames
    await _wsFrames?.stop();
    _wsFrames = WsClient(
      uri: _wsUri('/ws/frames'),
      onState: (s) { wsFramesLabel = s; notifyListeners(); },
      onJson: (j) {
        if (j['type'] == 'frame_meta') {
          _pendingFrameMeta = j;
        }
      },
      onBytes: (bytes) {
        if (_pendingFrameMeta != null) {
          lastFrameMeta = Map<String, dynamic>.from(_pendingFrameMeta!);
          lastFrameJpeg = bytes;
          _pendingFrameMeta = null;
          notifyListeners();
        }
      },
    );
    await _wsFrames!.start();

    return true;
  }

  Future<void> _refreshCameraRoles() async {
    if (api == null) return;
    try {
      final r = await api!.cameraRoles();
      primaryCameraAuto = r['primary'] as String?;
      guideCameraAuto = r['guide'] as String?;
      cameraRolesMethod = r['method'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshCameraRoles() => _refreshCameraRoles();

  /// Forza refresh dello snapshot via REST. Utile per pull-to-refresh.
  Future<bool> refreshSnapshot() async {
    if (api == null) return false;
    try {
      final snap = await api!.snapshot();
      _ingestSnapshot(snap);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await _wsState?.stop();
    await _wsFrames?.stop();
    api?.close();
    api = null;
    properties.clear();
    devices.clear();
    indiConn = 'disconnected';
    phd2Conn = 'disconnected';
    connectionStateLabel = 'disconnected';
    notifyListeners();
  }

  // --- Ingest ---

  void _ingestSnapshot(Map<String, dynamic> snap) {
    final conn = snap['connections'] as Map<String, dynamic>?;
    if (conn != null) {
      indiConn = conn['indi'] ?? 'disconnected';
      phd2Conn = conn['phd2'] ?? 'disconnected';
    }
    devices
      ..clear()
      ..addAll(((snap['devices'] as List?) ?? []).cast<String>());
    properties.clear();
    for (final p in (snap['properties'] as List? ?? [])) {
      final m = (p as Map).cast<String, dynamic>();
      properties['${m['device']}::${m['name']}'] = m;
    }
    phd2Live = (snap['phd2'] as Map?)?.cast<String, dynamic>() ?? {};
    lastFrameMeta = (snap['last_frame'] as Map?)?.cast<String, dynamic>() ?? {};
    messages
      ..clear()
      ..addAll(((snap['messages'] as List?) ?? []).cast<Map>().map((m) => m.cast<String, dynamic>()));
    notifyListeners();
  }

  void _ingestWsJson(Map<String, dynamic> j) {
    final type = j['type']?.toString();
    wsEventsReceived++;
    lastWsEventType = type;
    switch (type) {
      case 'snapshot':
        // Legacy: vecchio backend mandava snapshot in un unico mega-messaggio
        _ingestSnapshot((j['snapshot'] as Map).cast<String, dynamic>());
        break;
      case 'snapshot_begin':
        // Nuovo flusso chunked: pulisco e aspetto property_def streaming
        snapshotInProgress = true;
        wsExpectedProperties = (j['properties_count'] as num?)?.toInt() ?? 0;
        properties.clear();
        devices
          ..clear()
          ..addAll(((j['devices'] as List?) ?? []).cast<String>());
        final c = (j['connections'] as Map?)?.cast<String, dynamic>();
        if (c != null) {
          indiConn = c['indi'] ?? 'disconnected';
          phd2Conn = c['phd2'] ?? 'disconnected';
        }
        phd2Live = (j['phd2'] as Map?)?.cast<String, dynamic>() ?? {};
        lastFrameMeta = (j['last_frame'] as Map?)?.cast<String, dynamic>() ?? {};
        messages
          ..clear()
          ..addAll(((j['messages'] as List?) ?? []).cast<Map>().map((m) => m.cast<String, dynamic>()));
        notifyListeners();
        break;
      case 'snapshot_end':
        snapshotInProgress = false;
        notifyListeners();
        break;
      case 'connection':
        if (j.containsKey('indi')) indiConn = j['indi'];
        if (j.containsKey('phd2')) phd2Conn = j['phd2'];
        notifyListeners();
        break;
      case 'property_def':
      case 'property_set':
        final p = (j['property'] as Map).cast<String, dynamic>();
        properties['${p['device']}::${p['name']}'] = p;
        devices.add(p['device']);
        notifyListeners();
        break;
      case 'property_del':
        final dev = j['device'];
        final name = j['name'];
        if (name != null && (name as String).isNotEmpty) {
          properties.remove('$dev::$name');
        } else {
          properties.removeWhere((k, _) => k.startsWith('$dev::'));
          devices.remove(dev);
        }
        notifyListeners();
        break;
      case 'indi_message':
        messages.add(j.cast<String, dynamic>());
        if (messages.length > 200) messages.removeRange(0, messages.length - 200);
        notifyListeners();
        break;
      case 'phd2_live':
        phd2Live = (j['phd2'] as Map).cast<String, dynamic>();
        // Salva snapshot per grafico
        phd2History.add({'ts': DateTime.now().millisecondsSinceEpoch, ...phd2Live});
        if (phd2History.length > _phd2HistoryMax) {
          phd2History.removeRange(0, phd2History.length - _phd2HistoryMax);
        }
        notifyListeners();
        break;
      case 'phd2_event':
        // event raw, non lo salviamo nel history (lo fa phd2_live)
        break;
      case 'frame_meta':
        lastFrameMeta = j.cast<String, dynamic>();
        notifyListeners();
        break;
      default:
        break;
    }
  }

  // --- Helpers per le schermate ---

  Map<String, dynamic>? prop(String device, String name) =>
      properties['$device::$name'];

  /// Trova primo device che espone una property (auto-detection ruolo).
  String? findDeviceByProperty(String propName) {
    for (final entry in properties.entries) {
      if (entry.value['name'] == propName) return entry.value['device'] as String;
    }
    return null;
  }

  /// Tutte le property di un device, ordinate per group/name.
  List<Map<String, dynamic>> deviceProps(String device) {
    final list = properties.values.where((p) => p['device'] == device).toList();
    list.sort((a, b) {
      final g = (a['group'] as String).compareTo(b['group'] as String);
      return g != 0 ? g : (a['name'] as String).compareTo(b['name'] as String);
    });
    return list;
  }

  String? mountDevice() => effectiveDevice('mount') ?? findDeviceByProperty('EQUATORIAL_EOD_COORD');
  String? cameraDevice() => effectiveDevice('camera') ?? findDeviceByProperty('CCD_EXPOSURE');
  String? focuserDevice() => effectiveDevice('focuser') ?? findDeviceByProperty('ABS_FOCUS_POSITION');
  String? filterWheelDevice() => effectiveDevice('filter_wheel') ?? findDeviceByProperty('FILTER_SLOT');
}

dynamic propValue(Map<String, dynamic>? prop, String elementName) {
  if (prop == null) return null;
  for (final e in (prop['elements'] as List? ?? [])) {
    if (e['name'] == elementName) return e['value'];
  }
  return null;
}
