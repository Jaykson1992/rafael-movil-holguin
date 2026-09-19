import 'dart:async';

import '../models/sync_models.dart';
import 'location_tracking_service.dart';
import 'rest_backend_service.dart';

/// Une el GPS físico del conductor con el backend y permite al cliente
/// observar la última posición autorizada. No depende de Google Maps.
class LiveTripTrackingService {
  LiveTripTrackingService({required this.backend, required this.location});
  final RestRafaelBackend backend;
  final LocationTrackingService location;
  StreamSubscription<GeoPoint>? _driverGps;

  Future<void> startDriverSharing({required String driverId, required String tripId}) async {
    await _driverGps?.cancel();
    _driverGps = location.watchPosition().listen((point) async {
      try {
        await backend.updateDriverLocation(DriverLocationUpdate(
          driverId: driverId,
          tripId: tripId,
          position: point,
          capturedAt: DateTime.now(),
        ));
      } catch (_) {
        // La siguiente lectura GPS vuelve a intentar; la UI no se bloquea.
      }
    });
  }

  Stream<GeoPoint> watchDriver({required String driverId, required String tripId}) =>
      backend.watchDriverLocation(driverId, tripId: tripId);

  Future<void> stopDriverSharing() async {
    await _driverGps?.cancel();
    _driverGps = null;
  }
}
