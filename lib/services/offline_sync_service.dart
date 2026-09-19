import 'dart:convert';
import 'dart:io';

import '../models/sync_models.dart';

/// Cola offline persistente.
///
/// V21 conserva las acciones pendientes en un archivo JSON local para que un
/// cierre/reinicio de la app no borre solicitudes que todavía no llegaron al
/// servidor. La ruta se inyecta al iniciar la app para mantener este servicio
/// independiente de plugins y fácil de probar.
class OfflineSyncService {
  OfflineSyncService({String? persistencePath}) : _persistencePath = persistencePath;

  final String? _persistencePath;
  final List<PendingSyncAction> _queue = [];

  List<PendingSyncAction> get pending => List.unmodifiable(_queue);

  Future<void> load() async {
    final path = _persistencePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      _queue
        ..clear()
        ..addAll(decoded.whereType<Map>().map((raw) {
          final map = raw.cast<String, dynamic>();
          final rawType = map['type']?.toString() ?? '';
          final type = SyncActionType.values.where((item) => item.name == rawType).firstOrNull;
          if (type == null) return null;
          return PendingSyncAction(
            id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
            createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
          );
        }).whereType<PendingSyncAction>());
    } catch (_) {
      // Archivo corrupto: no bloquea el arranque ni destruye el archivo.
    }
  }

  Future<void> enqueue(PendingSyncAction action) async {
    final duplicate = _queue.any((item) =>
        item.type == action.type && _canonical(item.payload) == _canonical(action.payload));
    if (!duplicate) {
      _queue.add(action);
      await _save();
    }
  }

  Future<int> flush(Future<void> Function(PendingSyncAction) sender) async {
    var sent = 0;
    for (final action in List<PendingSyncAction>.from(_queue)) {
      try {
        await sender(action);
        _queue.remove(action);
        sent++;
        await _save();
      } catch (_) {
        break;
      }
    }
    return sent;
  }

  Future<void> clear() async {
    _queue.clear();
    await _save();
  }

  String _canonical(Map<String, dynamic> value) {
    dynamic sortValue(dynamic v) {
      if (v is Map) {
        final keys = v.keys.map((e) => e.toString()).toList()..sort();
        return {for (final key in keys) key: sortValue(v[key])};
      }
      if (v is List) return v.map(sortValue).toList();
      return v;
    }
    return jsonEncode(sortValue(value));
  }

  Future<void> _save() async {
    final path = _persistencePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    final data = _queue
        .map((a) => <String, dynamic>{
              'id': a.id,
              'type': a.type.name,
              'payload': a.payload,
              'createdAt': a.createdAt.toUtc().toIso8601String(),
            })
        .toList(growable: false);
    await tmp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(path);
  }
}
