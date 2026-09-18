import '../models/sync_models.dart';

/// Contract used by the UI. A real server implementation can replace the
/// local implementation without changing the Cliente/Conductor/Admin screens.
abstract class RafaelBackend {
  Future<String> createTrip(Map<String, dynamic> trip);
  Future<void> sendCounterOffer(String tripId, int cup);
  Future<void> acceptTrip(String tripId, String driverId);
  Future<void> updateTripStatus(String tripId, String status);
  Future<void> updateDriverLocation(DriverLocationUpdate update);
  Stream<Map<String, dynamic>> watchTrip(String tripId);
}

/// Queue contract for Cuba's intermittent connectivity. Actions can be stored
/// locally and retried when a connection returns.
abstract class OfflineSyncQueue {
  Future<void> enqueue(PendingSyncAction action);
  Future<List<PendingSyncAction>> pending();
  Future<void> remove(String actionId);
}
