import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/sync_models.dart';
import 'backend_contract.dart';

class RafaelApiException implements Exception {
  const RafaelApiException(this.statusCode, this.code);
  final int statusCode;
  final String code;
  @override String toString() => 'RafaelApiException($statusCode, $code)';
}

/// REST client ready to point at Rafael's production server.
/// No API secret is stored in the app. A session token can be supplied after login.
class RestRafaelBackend implements RafaelBackend {
  RestRafaelBackend({required this.baseUrl, this.bearerToken});

  final String baseUrl;
  String? bearerToken;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.openUrl(method, _uri(path));
      request.headers.contentType = ContentType.json;
      if (bearerToken != null && bearerToken!.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String code = 'server_error';
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map && decoded['error'] != null) code = decoded['error'].toString();
        } catch (_) {}
        throw RafaelApiException(response.statusCode, code);
      }
      if (text.trim().isEmpty) return <String, dynamic>{};
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> register({required String name, required String identity, required String phone, required String role, required String pin, String? vehicle}) =>
      _json('POST', '/v1/auth/register', body: {
        'name': name, 'identity': identity, 'phone': phone, 'role': role, 'pin': pin,
        if (vehicle != null) 'vehicle': vehicle.toLowerCase().replaceAll(' ', ''),
      });

  Future<Map<String, dynamic>> login({required String identity, required String pin}) async {
    final result = await _json('POST', '/v1/auth/login', body: {'identity': identity, 'pin': pin});
    final token = result['token']?.toString();
    if (token == null || token.isEmpty) throw const FormatException('Falta token de sesión');
    bearerToken = token;
    return result;
  }

  Future<void> logout() async {
    if (bearerToken == null) return;
    await _json('POST', '/v1/auth/logout');
    bearerToken = null;
  }

  Future<Map<String, dynamic>> me() => _json('GET', '/v1/me');

  Future<Map<String, dynamic>> updateProfilePhoto(String photoData) =>
      _json('PATCH', '/v1/me/profile-photo', body: {'photoData': photoData});

  /// Returns true only when the server still accepts this session token.
  Future<bool> sessionIsValid() async {
    try { await me(); return true; } on RafaelApiException { return false; } on HttpException { return false; }
  }
  Future<Map<String, dynamic>> settings() => _json('GET', '/v1/settings');

  Future<Map<String, dynamic>> adminDashboard() => _json('GET', '/v1/admin/dashboard');

  Future<List<Map<String, dynamic>>> adminBusinesses() => _jsonList('GET', '/v1/admin/businesses');
  Future<Map<String, dynamic>> createBusiness({required String name,required String phone,required String category}) => _json('POST','/v1/admin/businesses',body:{'name':name,'phone':phone,'category':category});
  Future<Map<String, dynamic>> setBusinessActive(String id,bool active) => _json('PATCH','/v1/admin/businesses/$id',body:{'active':active});
  Future<void> deleteBusiness(String id) async {await _json('DELETE','/v1/admin/businesses/$id');}


  Future<List<Map<String, dynamic>>> adminDrivers() => _jsonList('GET', '/v1/admin/drivers');

  Future<List<Map<String, dynamic>>> adminClients({String query = ''}) {
    final q=query.trim().isEmpty?'':'?q=${Uri.encodeQueryComponent(query.trim())}';
    return _jsonList('GET', '/v1/admin/clients$q');
  }

  Future<Map<String, dynamic>> setClientActive(String clientId, bool active) =>
      _json('PATCH', '/v1/admin/clients/$clientId', body: {'active': active});

  Future<void> adminDeleteTrip(String tripId) async {
    await _json('DELETE', '/v1/admin/trips/$tripId');
  }

  Future<List<Map<String, dynamic>>> adminAudit({int limit = 50, String? action, String? role, String? query}) {
    final params=<String>['limit=$limit'];
    if(action!=null&&action.isNotEmpty) params.add('action=${Uri.encodeQueryComponent(action)}');
    if(role!=null&&role.isNotEmpty) params.add('role=${Uri.encodeQueryComponent(role)}');
    if(query!=null&&query.trim().isNotEmpty) params.add('q=${Uri.encodeQueryComponent(query.trim())}');
    return _jsonList('GET', '/v1/admin/audit?${params.join('&')}');
  }

  Future<List<Map<String, dynamic>>> driverInbox() => _jsonList('GET', '/v1/driver/inbox');

  Future<Map<String, dynamic>> trip(String tripId) => _json('GET', '/v1/trips/$tripId');

  Future<List<Map<String, dynamic>>> trips({String? status, int limit = 30}) {
    final params = <String>['limit=$limit'];
    if (status != null && status.isNotEmpty) params.add('status=${Uri.encodeQueryComponent(status)}');
    return _jsonList('GET', '/v1/trips?${params.join('&')}');
  }

  Future<Map<String, dynamic>> updateSettings({required int monthlyFeeCup, required String transfermovilCard}) =>
      _json('PUT', '/v1/settings', body: {'monthlyFeeCup': monthlyFeeCup, 'transfermovilCard': transfermovilCard});

  Future<Map<String, dynamic>> setDriverActive(String driverId, bool active) =>
      _json('PATCH', '/v1/drivers/$driverId', body: {'active': active});

  Future<Map<String, dynamic>> renewDriver(String driverId) =>
      _json('POST', '/v1/drivers/$driverId/subscription');

  Future<Map<String, dynamic>> submitSubscriptionPayment(String reference) =>
      _json('POST', '/v1/driver/subscription-payment', body: {'reference': reference});

  Future<List<Map<String, dynamic>>> _jsonList(String method, String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.openUrl(method, _uri(path));
      request.headers.contentType = ContentType.json;
      if (bearerToken != null && bearerToken!.isNotEmpty) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('Servidor respondió ${response.statusCode}');
      final decoded = jsonDecode(text) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } finally { client.close(force: true); }
  }

  Future<List<Map<String, dynamic>>> driverSubscriptionPayments() =>
      _jsonList('GET', '/v1/driver/subscription-payment');

  Future<List<Map<String, dynamic>>> adminSubscriptionPayments({String status = 'pending'}) =>
      _jsonList('GET', '/v1/admin/subscription-payments?status=${Uri.encodeQueryComponent(status)}');

  Future<Map<String, dynamic>> reviewSubscriptionPayment(String paymentId, String decision) =>
      _json('POST', '/v1/admin/subscription-payments/$paymentId/review', body: {'decision': decision});

  /// Ubicación fresca del conductor. El servidor solo la entrega al cliente
  /// dueño del viaje activo, al propio conductor o al administrador.
  Future<GeoPoint?> driverLocation(String driverId, {String? tripId}) async {
    final suffix = tripId == null ? '' : '?tripId=${Uri.encodeQueryComponent(tripId)}';
    try {
      final json = await _json('GET', '/v1/drivers/$driverId/location$suffix');
      return GeoPoint((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble());
    } on HttpException {
      return null;
    }
  }

  Stream<GeoPoint> watchDriverLocation(String driverId, {required String tripId}) async* {
    var wait = 4;
    while (true) {
      try {
        final point = await driverLocation(driverId, tripId: tripId);
        if (point != null) yield point;
        wait = 4;
      } on SocketException {
        wait = (wait * 2).clamp(4, 30);
      } on TimeoutException {
        wait = (wait * 2).clamp(4, 30);
      }
      await Future<void>.delayed(Duration(seconds: wait));
    }
  }

  Future<void> acceptCounterOffer(String tripId) =>
      _json('POST', '/v1/trips/$tripId/accept-counter');

  Future<void> rejectCounterOffer(String tripId) =>
      _json('POST', '/v1/trips/$tripId/reject-counter');

  @override
  Future<String> createTrip(Map<String, dynamic> trip) async {
    final result = await _json('POST', '/v1/trips', body: trip);
    final id = result['id']?.toString();
    if (id == null || id.isEmpty) throw const FormatException('Falta id del viaje');
    return id;
  }

  @override
  Future<void> sendCounterOffer(String tripId, int cup) =>
      _json('POST', '/v1/trips/$tripId/counter-offer', body: {'cup': cup});

  @override
  Future<void> acceptTrip(String tripId, String driverId) =>
      _json('POST', '/v1/trips/$tripId/accept', body: {'driverId': driverId});

  @override
  Future<void> updateTripStatus(String tripId, String status) =>
      _json('PATCH', '/v1/trips/$tripId', body: {'status': status});

  @override
  Future<void> updateDriverLocation(DriverLocationUpdate update) =>
      _json('POST', '/v1/drivers/${update.driverId}/location', body: {
        'tripId': update.tripId,
        'latitude': update.position.latitude,
        'longitude': update.position.longitude,
        'capturedAt': update.capturedAt.toUtc().toIso8601String(),
      });

  /// Polling tolerante a conexiones débiles. Si falla Internet, no mata el stream:
  /// espera cada vez más (hasta 30 s) y vuelve a intentar. Al recuperar conexión
  /// regresa al intervalo normal para que el viaje vuelva a verse casi en vivo.
  @override
  Stream<Map<String, dynamic>> watchTrip(String tripId) async* {
    var delaySeconds = 4;
    while (true) {
      try {
        yield await _json('GET', '/v1/trips/$tripId');
        delaySeconds = 4;
      } on SocketException {
        delaySeconds = (delaySeconds * 2).clamp(4, 30);
      } on TimeoutException {
        delaySeconds = (delaySeconds * 2).clamp(4, 30);
      } on HttpException {
        delaySeconds = (delaySeconds * 2).clamp(4, 30);
      }
      await Future<void>.delayed(Duration(seconds: delaySeconds));
    }
  }

  /// Sincronización incremental: trae solo cambios posteriores al último reloj
  /// conocido del servidor, reduciendo consumo de datos.
  Future<Map<String, dynamic>> changes({DateTime? since}) {
    final q = since == null ? '' : '?since=${Uri.encodeQueryComponent(since.toUtc().toIso8601String())}';
    return _json('GET', '/v1/changes$q');
  }
}
