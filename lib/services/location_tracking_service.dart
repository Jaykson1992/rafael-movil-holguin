import 'package:geolocator/geolocator.dart';

import '../models/sync_models.dart';

/// GPS real de Android. No necesita una clave de Google Maps: obtiene
/// coordenadas del proveedor de ubicación del teléfono y deja el mapa como
/// una capa independiente.
abstract class LocationTrackingService {
  Stream<GeoPoint> watchPosition();
  Future<GeoPoint?> currentPosition();
}

class AndroidLocationTrackingService implements LocationTrackingService {
  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<GeoPoint?> currentPosition() async {
    if (!await _ensurePermission()) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoPoint(p.latitude, p.longitude);
  }

  @override
  Stream<GeoPoint> watchPosition() async* {
    if (!await _ensurePermission()) return;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
    await for (final p in Geolocator.getPositionStream(locationSettings: settings)) {
      yield GeoPoint(p.latitude, p.longitude);
    }
  }
}

/// Útil para pruebas sin GPS físico.
class DemoLocationTrackingService implements LocationTrackingService {
  @override
  Future<GeoPoint?> currentPosition() async => const GeoPoint(20.8872, -76.2631);

  @override
  Stream<GeoPoint> watchPosition() async* {
    yield const GeoPoint(20.8872, -76.2631);
  }
}
