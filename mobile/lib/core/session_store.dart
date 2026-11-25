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
  static const _kTheme = 'se_theme';

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
      // Only the session: the light / dark choice stays after signing out.
      for (final k in [_kToken, _kRefresh, _kUser]) {
        await _storage.delete(key: k);
      }
    } catch (_) {}
  }

  /// 'light', 'dark' or 'system' (null when never chosen).
  Future<String?> readTheme() async {
    try {
      return await _storage.read(key: _kTheme);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTheme(String mode) async {
    try {
      await _storage.write(key: _kTheme, value: mode);
    } catch (_) {}
  }
}
