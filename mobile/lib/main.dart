import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/firebase_service.dart';
import 'core/theme.dart';
import 'router.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is optional: before `flutterfire configure` the app runs without it.
  await FirebaseService.instance.init();
  final app = AppState();
  await app.restore();
  runApp(SmartEventsApp(app: app));
}

class SmartEventsApp extends StatefulWidget {
  const SmartEventsApp({super.key, required this.app});
  final AppState app;

  @override
  State<SmartEventsApp> createState() => _SmartEventsAppState();
}

class _SmartEventsAppState extends State<SmartEventsApp> {
  late final GoRouter _router = buildRouter(widget.app);

  @override
  void initState() {
    super.initState();
    // Tapping a push notification about a booking opens its negotiation.
    FirebaseService.instance.onOpenNotification = (data) {
      final id = data['bookingId'] ?? data['relatedId'];
      if (id != null) _router.push('/negotiate/$id');
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.app,
      child: Consumer<AppState>(
        builder: (_, app, _) => MaterialApp.router(
          title: 'SmartEvents',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: app.themeMode,
          scaffoldMessengerKey: FirebaseService.instance.messengerKey,
          routerConfig: _router,
        ),
      ),
    );
  }
}
