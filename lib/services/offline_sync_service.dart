import '../models/sync_models.dart';
import 'backend_contract.dart';

class OfflineSyncService {
  OfflineSyncService(this.backend, this.queue);
  final RafaelBackend backend;
  final OfflineSyncQueue queue;

  Future<void> flush() async {
    final actions = await queue.pending();
    for (final action in actions) {
      try {
        switch (action.type) {
          case SyncActionType.createTrip:
            await backend.createTrip(action.payload);
          case SyncActionType.counterOffer:
            await backend.sendCounterOffer(action.payload['tripId'] as String, action.payload['cup'] as int);
          case SyncActionType.acceptTrip:
            await backend.acceptTrip(action.payload['tripId'] as String, action.payload['driverId'] as String);
          case SyncActionType.updateStatus:
            await backend.updateTripStatus(action.payload['tripId'] as String, action.payload['status'] as String);
          case SyncActionType.updateLocation:
            final p = action.payload['position'] as Map<String, dynamic>;
            await backend.updateDriverLocation(DriverLocationUpdate(
              driverId: action.payload['driverId'] as String,
              tripId: action.payload['tripId'] as String?,
              position: GeoPoint.fromJson(p),
              capturedAt: DateTime.parse(action.payload['capturedAt'] as String),
            ));
        }
        await queue.remove(action.id);
      } catch (_) {
        break;
      }
    }
  }
}
