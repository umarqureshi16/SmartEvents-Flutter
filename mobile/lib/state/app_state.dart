import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/firebase_service.dart';
import '../core/session_store.dart';
import '../core/socket_service.dart';
import '../models/models.dart';

/// Who is signed in, plus app-wide settings (theme). Screens listen to it.
class AppState extends ChangeNotifier {
  AppState() {
    Api.instance.onSessionExpired = () {
      if (user != null) signOut(expired: true);
    };
  }

  AppUser? user;
  bool ready = false;
  ThemeMode themeMode = ThemeMode.system;
  int unread = 0;
  String? notice;

  bool get signedIn => user != null;

  Future<void> restore() async {
    await SessionStore.instance.load();
    final saved = SessionStore.instance.user;
    if (SessionStore.instance.token != null && saved != null) {
      user = AppUser(saved);
      _afterSignIn();
      refreshMe();
    }
    ready = true;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try {
      final res = await Api.instance.get('/auth/me');
      final u = Map<String, dynamic>.from(res['user'] as Map);
      user = AppUser(u);
      await SessionStore.instance.save(user: u);
      notifyListeners();
    } catch (_) {/* stay with the saved summary */}
  }

  Future<void> signIn(String email, String password) async {
    final res = await Api.instance.post('/auth/login', {'email': email.trim(), 'password': password});
    await _start(res);
    FirebaseService.instance.logEvent('login', {'method': 'email'});
  }

  /// Creates the account. Returns a message when the email must be verified
  /// first; otherwise signs straight in.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? category,
  }) async {
    final res = await Api.instance.post('/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'role': role,
      if (role == 'provider' && category != null) 'category': category,
    });
    FirebaseService.instance.logEvent('sign_up', {'method': 'email', 'role': role});
    final verified = (res['user'] as Map?)?['isEmailVerified'] == true;
    if (!verified) return res['message'] as String? ?? 'Check your inbox to verify your email, then sign in.';
    await signIn(email, password);
    return null;
  }

  Future<void> _start(Map<String, dynamic> res) async {
    final u = Map<String, dynamic>.from(res['user'] as Map);
    await SessionStore.instance.save(token: res['token'] as String?, refreshToken: res['refreshToken'] as String?, user: u);
    user = AppUser(u);
    _afterSignIn();
    notifyListeners();
    refreshMe();
  }

  void _afterSignIn() {
    SocketService.instance.connect();
    FirebaseService.instance.setUser(user?.id, user?.role);
    FirebaseService.instance.registerForPush();
    loadUnread();
  }

  Future<void> loadUnread() async {
    try {
      final res = await Api.instance.get('/notifications');
      final list = (res['data'] as List? ?? []);
      unread = list.where((n) => n is Map && n['isRead'] != true).length;
      notifyListeners();
    } catch (_) {}
  }

  void setUnread(int n) {
    unread = n;
    notifyListeners();
  }

  Future<void> signOut({bool expired = false}) async {
    await FirebaseService.instance.unregisterPush();
    try {
      await Api.instance.post('/auth/logout');
    } catch (_) {}
    SocketService.instance.disconnect();
    await SessionStore.instance.clear();
    FirebaseService.instance.setUser(null, null);
    user = null;
    unread = 0;
    notice = expired ? 'Your session ended. Please sign in again.' : null;
    notifyListeners();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    notifyListeners();
  }
}
