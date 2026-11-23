import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the signed-in session (tokens and the user summary) in the device's
/// secure storage (Keychain / Keystore; encrypted storage on the web).
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'se_token';
  static const _kRefresh = 'se_refresh';
  static const _kUser = 'se_user';

  String? token;
  String? refreshToken;
  Map<String, dynamic>? user;

  Future<void> load() async {
    try {
      token = await _storage.read(key: _kToken);
      refreshToken = await _storage.read(key: _kRefresh);
      final raw = await _storage.read(key: _kUser);
      user = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Storage can be unavailable (private browsing); start signed out.
      token = null;
      refreshToken = null;
      user = null;
    }
  }

  Future<void> save({String? token, String? refreshToken, Map<String, dynamic>? user}) async {
    if (token != null) this.token = token;
    if (refreshToken != null) this.refreshToken = refreshToken;
    if (user != null) this.user = user;
    try {
      if (token != null) await _storage.write(key: _kToken, value: token);
      if (refreshToken != null) await _storage.write(key: _kRefresh, value: refreshToken);
      if (user != null) await _storage.write(key: _kUser, value: jsonEncode(user));
    } catch (_) {/* kept in memory for this run */}
  }

  Future<void> clear() async {
    token = null;
    refreshToken = null;
    user = null;
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
