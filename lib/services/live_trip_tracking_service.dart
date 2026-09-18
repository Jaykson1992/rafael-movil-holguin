import 'dart:async';
import '../models/sync_models.dart';
import 'backend_contract.dart';
import 'location_tracking_service.dart';

class LiveTripTrackingService {
  LiveTripTrackingService(this.backend, this.location);
  final RafaelBackend backend;
  final LocationTrackingService location;
  StreamSubscription<GeoPoint>? _subscription;

  Future<bool> start({required String driverId, required String tripId}) async {
    if (!await location.ensurePermission()) return false;
    await _subscription?.cancel();
    _subscription = location.positions().listen((point) {
      backend.updateDriverLocation(DriverLocationUpdate(
        driverId: driverId,
        tripId: tripId,
        position: point,
        capturedAt: DateTime.now(),
      ));
    });
    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
