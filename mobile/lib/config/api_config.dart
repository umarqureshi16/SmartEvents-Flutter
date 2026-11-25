/// Where the app talks to the SmartEvents backend (the same Express API the
/// web app uses).
///
/// Override at build time, e.g. for a local server on the Android emulator:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1 \
///               --dart-define=SOCKET_URL=http://10.0.2.2:5000
class ApiConfig {
  ApiConfig._();

  /// REST API, e.g. POST $apiBaseUrl/auth/login.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-events-puce.vercel.app/api/v1',
  );

  /// Socket.IO server for live negotiation updates and notifications.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://smartie-backend.onrender.com',
  );

  /// Google sign-in: the web OAuth client ID the server checks Google's
  /// ID token against (the same one the website uses). It is public, not a secret.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '334746400767-n57icbgda5ejph7hes6g1is3rjmktpd3.apps.googleusercontent.com',
  );
}
