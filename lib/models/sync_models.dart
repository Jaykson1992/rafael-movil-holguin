class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude};
  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    (json['latitude'] as num).toDouble(),
    (json['longitude'] as num).toDouble(),
  );
}

class DriverLocationUpdate {
  const DriverLocationUpdate({
    required this.driverId,
    required this.position,
    required this.capturedAt,
    this.tripId,
  });
  final String driverId;
  final String? tripId;
  final GeoPoint position;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'tripId': tripId,
    'position': position.toJson(),
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };
}

enum SyncActionType { createTrip, counterOffer, acceptTrip, updateStatus, updateLocation }

class PendingSyncAction {
  const PendingSyncAction({required this.id, required this.type, required this.payload, required this.createdAt});
  final String id;
  final SyncActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
}
