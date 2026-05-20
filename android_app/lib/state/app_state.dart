import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/ws_client.dart';
import '../i18n/strings.dart';
import 'bridge_connection.dart';
import 'capture_job.dart';

/// Stato globale dell'app.
/// - Configurazione di connessione (host/porta/token) persistente
/// - Modello "specchio" del bridge: properties INDI, PHD2 live, last frame, ecc.
/// - Notifica i listener su ogni cambiamento (Provider/ChangeNotifier)
class AppState extends ChangeNotifier {
  // --- Bridges (multi-RPi) ---
  // L'utente può salvare più bridge (un RPi per ognuno) e switchare con un
  // tap. La lista è persistita come JSON in `bridges_v1`. Una sola è ATTIVA
  // per volta (quella effettivamente connessa). I getter `host/port/token`
  // sotto sono facades verso la bridge attiva, per backward-compat col
  // codice esistente che li legge come campi singoli.
  List<BridgeConnection> bridges = [];
  String? activeBridgeId;

  /// Bridge attualmente selezionata (mai null se ce ne sono).
  BridgeConnection? get activeBridge {
    if (bridges.isEmpty) return null;
    if (activeBridgeId != null) {
      for (final b in bridges) {
        if (b.id == activeBridgeId) return b;
      }
    }
    return bridges.first;
  }

  // === Facades verso la bridge attiva ===
  String get host => activeBridge?.host ?? '';
  set host(String v) {
    final b = activeBridge;
    if (b != null) { b.host = v; savePrefs(); }
  }
  int get port => activeBridge?.port ?? 8765;
  set port(int v) {
    final b = activeBridge;
    if (b != null) { b.port = v; savePrefs(); }
  }
  String get token => activeBridge?.token ?? '';
  set token(String v) {
    final b = activeBridge;
    if (b != null) { b.token = v; savePrefs(); }
  }
  bool get useHttps => activeBridge?.useHttps ?? false;
  set useHttps(bool v) {
    final b = activeBridge;
    if (b != null) { b.useHttps = v; savePrefs(); }
  }

  bool nightMode = false;
  // Lingua UI — IT è default ("Zarletti-Osservatorio Jupiter" è italiano).
  // Cambiabile da Settings; persistente via SharedPreferences (chiave 'locale').
  AppLocale locale = AppLocale.it;

  // Device selezionato per ogni ruolo (persistente, override automatico se >1 device)
  String? selectedCamera;
  String? selectedMount;
  String? selectedFocuser;
  String? selectedFilterWheel;

  // --- Dither config (persistente, v0.2.36) -------------------------------
  // Override dei parametri dither applicati dal bridge ad ogni `/ekos_run`.
  // Se l'utente NON ha mai toccato il pannello, lasciamo null → il bridge
  // usa i valori che l'utente ha messo in Ekos (kstarsrc [Guide]) come
  // default. Quando l'utente cambia uno slider, persistiamo qui e mandiamo
  // l'override esplicito al bridge.
  double? ditherAmountPx;       // es. 5.0
  double? ditherSettleSec;      // es. 30.0
  double? ditherSettlePixels;   // es. 1.5
  int? ditherFrequency;         // es. 1 (ogni scatto) / 3 (ogni 3 scatti)
  bool? ditherRaOnly;           // false di default

  /// Salva la dither config + persiste. Passare null su un campo lo riporta
  /// al default (= leggi da Ekos).
  void setDitherConfig({
    double? amountPx, double? settleSec, double? settlePixels,
    int? frequency, bool? raOnly, bool reset = false,
  }) {
    if (reset) {
      ditherAmountPx = null;
      ditherSettleSec = null;
      ditherSettlePixels = null;
      ditherFrequency = null;
      ditherRaOnly = null;
    } else {
      if (amountPx != null) ditherAmountPx = amountPx;
      if (settleSec != null) ditherSettleSec = settleSec;
      if (settlePixels != null) ditherSettlePixels = settlePixels;
      if (frequency != null) ditherFrequency = frequency;
      if (raOnly != null) ditherRaOnly = raOnly;
    }
    savePrefs();
    notifyListeners();
  }

  // --- Cooler target temperature (persistente) ----------------------------
  // BUG FIX v0.2.34: lo slider in Capture si resettava a -10°C ogni volta
  // che l'utente lasciava la schermata e tornava. Adesso il valore vive
  // qui in AppState ed è persistito su SharedPreferences (chiave
  // 'userTargetTemperatureC'), così sopravvive a:
  //   • cambio di schermata (rebuild del widget)
  //   • kill dell'app
  //   • riavvio del telefono
  //   • switch tra bridge multipli (è una preferenza utente, non per-RPi)
  // -10°C resta il default per chi non l'ha mai impostato.
  double userTargetTemperatureC = -10.0;

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
    // Multi-bridge: carica lista. Se vuota e ci sono i vecchi campi
    // host/port/token in prefs, esegue migrazione automatica creando
    // una bridge singola "Bridge principale".
    bridges = BridgeConnection.decodeList(p.getString('bridges_v1'));
    activeBridgeId = p.getString('activeBridgeId');
    if (bridges.isEmpty) {
      final legacyHost = p.getString('host') ?? '';
      final legacyToken = p.getString('token') ?? '';
      if (legacyHost.isNotEmpty && legacyToken.isNotEmpty) {
        final migrated = BridgeConnection(
          id: BridgeConnection.generateId(),
          name: 'Bridge principale',
          host: legacyHost,
          port: p.getInt('port') ?? 8765,
          token: legacyToken,
          useHttps: p.getBool('https') ?? false,
        );
        bridges = [migrated];
        activeBridgeId = migrated.id;
        await _saveBridgesList(p);
      }
    }
    nightMode = p.getBool('night') ?? false;
    final loc = p.getString('locale');
    locale = (loc == 'en') ? AppLocale.en : AppLocale.it;
    selectedCamera = p.getString('selectedCamera');
    selectedMount = p.getString('selectedMount');
    selectedFocuser = p.getString('selectedFocuser');
    selectedFilterWheel = p.getString('selectedFilterWheel');
    activeTargetName = p.getString('activeTargetName');
    activeTargetRaHours = p.getDouble('activeTargetRaHours');
    activeTargetDecDeg = p.getDouble('activeTargetDecDeg');
    userTargetTemperatureC = p.getDouble('userTargetTemperatureC') ?? -10.0;
    // v0.2.36: dither config
    ditherAmountPx = p.getDouble('ditherAmountPx');
    ditherSettleSec = p.getDouble('ditherSettleSec');
    ditherSettlePixels = p.getDouble('ditherSettlePixels');
    ditherFrequency = p.getInt('ditherFrequency');
    ditherRaOnly = p.containsKey('ditherRaOnly') ? p.getBool('ditherRaOnly') : null;
    notifyListeners();
  }

  Future<void> _saveBridgesList(SharedPreferences p) async {
    await p.setString('bridges_v1', BridgeConnection.encodeList(bridges));
    if (activeBridgeId != null) {
      await p.setString('activeBridgeId', activeBridgeId!);
    } else {
      await p.remove('activeBridgeId');
    }
  }

  Future<void> savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await _saveBridgesList(p);
    await p.setBool('night', nightMode);
    await p.setString('locale', locale == AppLocale.en ? 'en' : 'it');
    if (selectedCamera != null) await p.setString('selectedCamera', selectedCamera!); else await p.remove('selectedCamera');
    if (selectedMount != null) await p.setString('selectedMount', selectedMount!); else await p.remove('selectedMount');
    if (selectedFocuser != null) await p.setString('selectedFocuser', selectedFocuser!); else await p.remove('selectedFocuser');
    if (selectedFilterWheel != null) await p.setString('selectedFilterWheel', selectedFilterWheel!); else await p.remove('selectedFilterWheel');
    if (activeTargetName != null) await p.setString('activeTargetName', activeTargetName!); else await p.remove('activeTargetName');
    if (activeTargetRaHours != null) await p.setDouble('activeTargetRaHours', activeTargetRaHours!); else await p.remove('activeTargetRaHours');
    if (activeTargetDecDeg != null) await p.setDouble('activeTargetDecDeg', activeTargetDecDeg!); else await p.remove('activeTargetDecDeg');
    await p.setDouble('userTargetTemperatureC', userTargetTemperatureC);
    // v0.2.36: dither config
    if (ditherAmountPx != null) await p.setDouble('ditherAmountPx', ditherAmountPx!);
    else await p.remove('ditherAmountPx');
    if (ditherSettleSec != null) await p.setDouble('ditherSettleSec', ditherSettleSec!);
    else await p.remove('ditherSettleSec');
    if (ditherSettlePixels != null) await p.setDouble('ditherSettlePixels', ditherSettlePixels!);
    else await p.remove('ditherSettlePixels');
    if (ditherFrequency != null) await p.setInt('ditherFrequency', ditherFrequency!);
    else await p.remove('ditherFrequency');
    if (ditherRaOnly != null) await p.setBool('ditherRaOnly', ditherRaOnly!);
    else await p.remove('ditherRaOnly');
  }

  /// Aggiorna il setpoint utente della temperatura sensore e lo persiste.
  /// Chiamato da CoolerPanel ogni volta che il testo cambia o IMPOSTA è premuto.
  void setUserTargetTemperatureC(double v) {
    userTargetTemperatureC = v;
    savePrefs();
    notifyListeners();
  }

  // === Multi-bridge management ===

  /// Aggiunge una nuova bridge alla lista. Non la attiva — chiamare
  /// `switchTo()` per attivarla.
  Future<BridgeConnection> addBridge({
    required String name, required String host, required int port,
    required String token, bool useHttps = false,
  }) async {
    final b = BridgeConnection(
      id: BridgeConnection.generateId(),
      name: name, host: host, port: port, token: token, useHttps: useHttps,
    );
    bridges.add(b);
    // Se è la prima, attivala
    activeBridgeId ??= b.id;
    await savePrefs();
    notifyListeners();
    return b;
  }

  Future<void> renameBridge(String id, String newName) async {
    for (final b in bridges) {
      if (b.id == id) {
        b.name = newName;
        await savePrefs();
        notifyListeners();
        return;
      }
    }
  }

  Future<void> removeBridge(String id) async {
    // Se rimuovo l'attiva, disconnetto prima
    if (id == activeBridgeId) {
      await disconnect();
      activeBridgeId = null;
    }
    bridges.removeWhere((b) => b.id == id);
    if (activeBridgeId == null && bridges.isNotEmpty) {
      activeBridgeId = bridges.first.id;
    }
    await savePrefs();
    notifyListeners();
  }

  /// Switch a una bridge esistente (per id): disconnette quella attuale,
  /// pulisce lo stato locale (è un telescopio diverso!), poi connette
  /// alla nuova. Ritorna true se la connessione è riuscita.
  Future<bool> switchTo(String id) async {
    final target = bridges.firstWhere((b) => b.id == id,
        orElse: () => BridgeConnection(
            id: '', name: '', host: '', port: 0, token: ''));
    if (target.id.isEmpty) return false;
    await disconnect();
    _resetBridgeLocalState();
    activeBridgeId = id;
    target.lastUsedAt = DateTime.now();
    await savePrefs();
    notifyListeners();
    return await connect();
  }

  /// Pulisce lo stato locale legato alla bridge (device, target, frame,
  /// phd2 live, ...). Chiamato al cambio di bridge: il setup hardware
  /// dell'altro RPi è diverso, niente di quanto c'era prima è rilevante.
  void _resetBridgeLocalState() {
    properties.clear();
    devices.clear();
    indiConn = 'disconnected';
    phd2Conn = 'disconnected';
    phd2Live = {};
    phd2History.clear();
    lastFrameMeta = {};
    lastFrameJpeg = null;
    messages.clear();
    wsEventsReceived = 0;
    lastWsEventType = null;
    primaryCameraAuto = null;
    guideCameraAuto = null;
    cameraRolesMethod = null;
    selectedCamera = null;
    selectedMount = null;
    selectedFocuser = null;
    selectedFilterWheel = null;
    // Target attivo è specifico per telescopio
    activeTargetName = null;
    activeTargetRaHours = null;
    activeTargetDecDeg = null;
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
