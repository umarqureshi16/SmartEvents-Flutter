import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/firebase_service.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/bookings/bookings_screen.dart';
import 'screens/bookings/negotiation_screen.dart';
import 'screens/designs/design_studio_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/explore/event_detail_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/more/admin_screen.dart';
import 'screens/more/vendor_tools.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/smartie/smartie_screen.dart';
import 'screens/tickets/tickets_screen.dart';
import 'screens/vendors/vendor_screens.dart';
import 'state/app_state.dart';

/// Logs each screen to Firebase Analytics.
class _ScreenLogger extends NavigatorObserver {
  void _log(Route<dynamic>? r) {
    final name = r?.settings.name;
    if (name != null) FirebaseService.instance.logScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _log(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _log(newRoute);
}

GoRouter buildRouter(AppState app) {
  const publicPaths = {'/welcome', '/login', '/register', '/forgot-password', '/verify-email'};
  return GoRouter(
    initialLocation: '/',
    refreshListenable: app,
    observers: [_ScreenLogger()],
    redirect: (context, state) {
      if (!app.ready) return null;
      final public = publicPaths.contains(state.matchedLocation);
      if (!app.signedIn && !public) return '/welcome';
      if (app.signedIn && public) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', name: 'welcome', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', name: 'login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', name: 'forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', name: 'verify-email', builder: (_, _) => const VerifyEmailScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', name: 'explore', builder: (_, _) => const ExploreScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/vendors', name: 'vendors', builder: (_, _) => const VendorsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/bookings', name: 'bookings', builder: (_, _) => const BookingsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/smartie', name: 'smartie', builder: (_, _) => const SmartieScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', name: 'profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/event/:id', name: 'event', builder: (_, s) => EventDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/vendor/:id', name: 'vendor', builder: (_, s) => VendorDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/negotiate/:id', name: 'negotiate', builder: (_, s) => NegotiationScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/tickets', name: 'tickets', builder: (_, _) => const TicketsScreen()),
      GoRoute(path: '/notifications', name: 'notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/events', name: 'events', builder: (_, _) => const EventsScreen()),
      GoRoute(path: '/events/:id', name: 'event-plan', builder: (_, s) => EventPlanScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/designs', name: 'designs', builder: (_, _) => const DesignStudioScreen()),
      GoRoute(path: '/settings', name: 'settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/contact', name: 'contact', builder: (_, _) => const ContactScreen()),
      GoRoute(path: '/favorites', name: 'favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/services', name: 'services', builder: (_, _) => const ServicesScreen()),
      GoRoute(path: '/listings', name: 'listings', builder: (_, _) => const ListingsScreen()),
      GoRoute(path: '/availability', name: 'availability', builder: (_, _) => const AvailabilityScreen()),
      GoRoute(path: '/reviews', name: 'reviews', builder: (_, _) => const ProviderReviewsScreen()),
      GoRoute(path: '/revenue', name: 'revenue', builder: (_, _) => const RevenueScreen()),
      GoRoute(path: '/scanner', name: 'scanner', builder: (_, _) => const ScannerScreen()),
      GoRoute(path: '/business', name: 'business', builder: (_, _) => const BusinessProfileScreen()),
      GoRoute(path: '/admin', name: 'admin', builder: (_, _) => const AdminScreen()),
    ],
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vendor = app.user?.isVendor == true;
    return Scaffold(
      body: SafeArea(bottom: false, child: shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Explore'),
          const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: 'Vendors'),
          NavigationDestination(
            icon: const Icon(Icons.handshake_outlined),
            selectedIcon: const Icon(Icons.handshake_rounded),
            label: vendor ? 'Offers' : 'Bookings',
          ),
          const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Smartie'),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
