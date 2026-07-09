import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Session {
  Session({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  static const _storage = FlutterSecureStorage();

  static Future<Session?> load() async {
    try {
      final baseUrl = await _storage.read(key: 'baseUrl');
      final token = await _storage.read(key: 'token');
      if (baseUrl == null || token == null) return null;
      return Session(baseUrl: baseUrl, token: token);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    await _storage.write(key: 'baseUrl', value: baseUrl);
    await _storage.write(key: 'token', value: token);
  }

  static Future<void> clear() async {
    await _storage.delete(key: 'baseUrl');
    await _storage.delete(key: 'token');
  }
}
