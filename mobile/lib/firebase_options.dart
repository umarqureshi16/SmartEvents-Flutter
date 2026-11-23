// Placeholder until the app is connected to a Firebase project.
//
// Run, from the mobile/ folder:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// That replaces this file with the real keys for your project (and adds
// google-services.json / GoogleService-Info.plist). Until then the app runs
// normally with Firebase turned off.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError('Firebase is not configured yet. Run "flutterfire configure" in mobile/.');
  }
}
