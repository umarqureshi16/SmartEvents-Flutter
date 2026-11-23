import 'dart:async';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'session_store.dart';

/// An error from the API, with a message that can be shown to people.
class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// One HTTP client for the whole app. Adds the access token, renews it with
/// the refresh token when it expires, and turns errors into [ApiException].
class Api {
  Api._() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90), // the free server can take a minute to wake
      headers: {'Content-Type': 'application/json', 'X-Client': 'smartevents-flutter'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = SessionStore.instance.token;
        if (t != null && options.headers['Authorization'] == null) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        final path = err.requestOptions.path;
        final retried = err.requestOptions.extra['retried'] == true;
        final isAuthCall = path.contains('/auth/login') || path.contains('/auth/register') || path.contains('/auth/refresh');
        if (err.response?.statusCode == 401 && !retried && !isAuthCall && SessionStore.instance.refreshToken != null) {
          if (await _refresh()) {
            final opts = err.requestOptions
              ..extra['retried'] = true
              ..headers['Authorization'] = 'Bearer ${SessionStore.instance.token}';
            try {
              return handler.resolve(await dio.fetch(opts));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          onSessionExpired?.call();
        }
        handler.next(err);
      },
    ));
  }

  static final Api instance = Api._();
  late final Dio dio;

  /// Called when the session can no longer be renewed (sign the user out).
  void Function()? onSessionExpired;

  Completer<bool>? _refreshing;

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final res = await Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl))
          .post('/auth/refresh', data: {'refreshToken': SessionStore.instance.refreshToken});
      final data = res.data as Map<String, dynamic>;
      await SessionStore.instance.save(token: data['token'] as String?, refreshToken: data['refreshToken'] as String?);
      c.complete(data['token'] != null);
    } catch (_) {
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }

  static String messageOf(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty && errors.first is Map && errors.first['message'] != null) {
          return errors.map((x) => x['message']).join('. ');
        }
        if (data['message'] is String) return data['message'] as String;
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return 'The server is waking up. Please try again in a moment.';
      }
      if (e.type == DioExceptionType.connectionError) return 'No connection to the server. Check your internet.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<Map<String, dynamic>> _call(Future<Response> Function() fn) async {
    try {
      final res = await fn();
      final data = res.data;
      return data is Map<String, dynamic> ? data : {'data': data};
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _call(() => dio.get(path, queryParameters: query));
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _call(() => dio.post(path, data: body));
  Future<Map<String, dynamic>> put(String path, [Object? body]) => _call(() => dio.put(path, data: body));
  Future<Map<String, dynamic>> delete(String path) => _call(() => dio.delete(path));

  /// Turns a stored path such as "/api/v1/designs/x/image" or "/uploads/a.jpg"
  /// into a full URL on the API's server.
  static String? absolute(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) return url;
    final base = Uri.parse(ApiConfig.apiBaseUrl);
    final origin = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }
}
