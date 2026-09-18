import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PersistedSession {
  const PersistedSession({required this.role, required this.token, required this.name, required this.identity, this.vehicle});
  final String role;
  final String token;
  final String name;
  final String identity;
  final String? vehicle;
}

class SessionService {
  SessionService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final FlutterSecureStorage _storage;

  static const _role='session_role', _token='session_token', _name='session_name', _identity='session_identity', _vehicle='session_vehicle';

  Future<void> save({required String role, required String token, required String name, required String identity, String? vehicle}) async {
    await Future.wait([
      _storage.write(key:_role,value:role), _storage.write(key:_token,value:token),
      _storage.write(key:_name,value:name), _storage.write(key:_identity,value:identity),
      if(vehicle!=null) _storage.write(key:_vehicle,value:vehicle),
    ]);
  }

  Future<PersistedSession?> restore() async {
    final values=await Future.wait([_storage.read(key:_role),_storage.read(key:_token),_storage.read(key:_name),_storage.read(key:_identity),_storage.read(key:_vehicle)]);
    final role=values[0], token=values[1], name=values[2], identity=values[3];
    if(role==null||token==null||token.isEmpty||name==null||identity==null) return null;
    return PersistedSession(role:role,token:token,name:name,identity:identity,vehicle:values[4]);
  }

  Future<void> clear() => _storage.deleteAll();
}
