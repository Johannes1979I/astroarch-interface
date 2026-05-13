import 'dart:convert';

/// Una bridge salvata in app: nome user-friendly + dati di connessione.
/// Persistite in SharedPreferences come JSON (chiave `bridges_v1`).
class BridgeConnection {
  /// ID stabile (random alla creazione). Usato per riferimenti, non per UI.
  final String id;
  /// Nome user-friendly, modificabile (es. "EQ8 (Newton 300)" / "Askar").
  String name;
  String host;
  int port;
  String token;
  bool useHttps;
  final DateTime addedAt;
  DateTime? lastUsedAt;

  BridgeConnection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.token,
    this.useHttps = false,
    DateTime? addedAt,
    this.lastUsedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get baseUrl => '${useHttps ? "https" : "http"}://$host:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'token': token,
        'useHttps': useHttps,
        'addedAt': addedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory BridgeConnection.fromJson(Map<String, dynamic> j) => BridgeConnection(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Bridge',
        host: j['host'] as String? ?? '',
        port: (j['port'] as num?)?.toInt() ?? 8765,
        token: j['token'] as String? ?? '',
        useHttps: j['useHttps'] as bool? ?? false,
        addedAt: j['addedAt'] != null
            ? DateTime.tryParse(j['addedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        lastUsedAt: j['lastUsedAt'] != null
            ? DateTime.tryParse(j['lastUsedAt'] as String)
            : null,
      );

  static String generateId() {
    // ID semplice timestamp+random — non serve uuid-grade unicità
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = (DateTime.now().microsecondsSinceEpoch % 10000).toRadixString(36);
    return 'br_${ts}_$r';
  }

  /// Helper: serializza una lista come JSON string per SharedPreferences
  static String encodeList(List<BridgeConnection> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  /// Helper: deserializza dalla string
  static List<BridgeConnection> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => BridgeConnection.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
