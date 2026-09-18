import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/sync_models.dart';
import 'app_config.dart';
import 'backend_contract.dart';

class RestRafaelBackend implements RafaelBackend {
  RestRafaelBackend({String? baseUrl, this.token = ''})
      : baseUrl = (baseUrl ?? AppConfig.apiUrl).replaceAll(RegExp(r'/$'), '');

  final String baseUrl;
  String token;

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    if (baseUrl.isEmpty) throw StateError('RAFAEL_API_URL no está configurada');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      req.headers.contentType = ContentType.json;
      if (token.isNotEmpty) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await utf8.decoder.bind(res).join();
      dynamic data;
      if (text.isNotEmpty) data = jsonDecode(text);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = data is Map ? data['error']?.toString() : null;
        throw HttpException(msg ?? 'Servidor respondió ${res.statusCode}');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String,dynamic>> login(String identity,String pin) async =>
    Map<String,dynamic>.from(await _request('POST','/v1/auth/login',body:{'identity':identity,'pin':pin}) as Map);

  Future<Map<String,dynamic>> register(Map<String,dynamic> data) async =>
    Map<String,dynamic>.from(await _request('POST','/v1/auth/register',body:data) as Map);

  Future<Map<String,dynamic>> me() async =>
    Map<String,dynamic>.from(await _request('GET','/v1/me') as Map);

  Future<void> logout() async { await _request('POST','/v1/auth/logout'); }

  @override Future<String> createTrip(Map<String,dynamic> trip) async {
    final d=Map<String,dynamic>.from(await _request('POST','/v1/trips',body:trip) as Map);
    return d['id']?.toString() ?? d['trip']?['id']?.toString() ?? '';
  }
  @override Future<void> sendCounterOffer(String tripId,int cup) async =>
    _request('POST','/v1/trips/$tripId/counter-offer',body:{'cup':cup});
  @override Future<void> acceptTrip(String tripId,String driverId) async =>
    _request('POST','/v1/trips/$tripId/accept',body:{'driverId':driverId});
  @override Future<void> updateTripStatus(String tripId,String status) async =>
    _request('POST','/v1/trips/$tripId/status',body:{'status':status});
  @override Future<void> updateDriverLocation(DriverLocationUpdate update) async =>
    _request('POST','/v1/location',body:update.toJson());

  Future<Map<String,dynamic>> trip(String id) async =>
    Map<String,dynamic>.from(await _request('GET','/v1/trips/$id') as Map);

  @override Stream<Map<String,dynamic>> watchTrip(String tripId) async* {
    while (true) {
      yield await trip(tripId);
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  Future<List<Map<String,dynamic>>> adminDrivers() async =>
    _list(await _request('GET','/v1/admin/drivers'));
  Future<List<Map<String,dynamic>>> adminClients({String query=''}) async =>
    _list(await _request('GET','/v1/admin/clients?q=${Uri.encodeQueryComponent(query)}'));
  Future<List<Map<String,dynamic>>> adminTrips() async =>
    _list(await _request('GET','/v1/admin/trips'));
  Future<List<Map<String,dynamic>>> adminAudit() async =>
    _list(await _request('GET','/v1/admin/audit'));

  Future<void> setDriverActive(String id,bool active) async =>
    _request('POST','/v1/admin/drivers/$id/active',body:{'active':active});
  Future<void> renewDriver(String id) async =>
    _request('POST','/v1/admin/drivers/$id/renew');
  Future<void> setClientActive(String id,bool active) async =>
    _request('POST','/v1/admin/clients/$id/active',body:{'active':active});

  Future<Map<String,dynamic>> subscriptionStatus() async =>
    Map<String,dynamic>.from(await _request('GET','/v1/driver/subscription') as Map);
  Future<void> reportSubscriptionPayment() async =>
    _request('POST','/v1/driver/subscription-payment');

  List<Map<String,dynamic>> _list(dynamic value) {
    final raw = value is Map ? (value['items'] ?? value['drivers'] ?? value['clients'] ?? value['trips'] ?? value['audit']) : value;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
}
