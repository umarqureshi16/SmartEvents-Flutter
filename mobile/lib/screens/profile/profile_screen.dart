import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user!;
    final p = AppPalette.of(context);
    final fb = FirebaseService.instance;

    Widget tile(IconData icon, String title, {String? subtitle, VoidCallback? onTap, Widget? trailing}) => ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(26)),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white24,
              child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(u.email, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
                    child: Text(u.roleLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 15),
                  Text(' Trust ${u.trustScore.round()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            tile(Icons.qr_code_2_rounded, 'My passes', subtitle: 'Entry passes with QR codes', onTap: () => context.push('/tickets')),
            const Divider(indent: 56),
            tile(Icons.notifications_none_rounded, 'Notifications', subtitle: app.unread > 0 ? '${app.unread} unread' : 'All caught up', onTap: () => context.push('/notifications')),
            const Divider(indent: 56),
            tile(Icons.storefront_outlined, 'Browse vendors', onTap: () => context.go('/vendors')),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                const Expanded(child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {app.themeMode},
                  onSelectionChanged: (s) => context.read<AppState>().setTheme(s.first),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            tile(Icons.local_fire_department_outlined, 'Firebase',
                subtitle: fb.enabled
                    ? 'Connected · analytics, crash reports${fb.pushToken != null ? ', push notifications on' : ''}'
                    : 'Not connected yet (run "flutterfire configure")',
                trailing: Icon(fb.enabled ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: fb.enabled ? p.success : p.muted)),
            const Divider(indent: 56),
            tile(Icons.cloud_outlined, 'Server', subtitle: ApiConfig.apiBaseUrl),
          ]),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmDialog(context, title: 'Sign out?', message: 'You can sign back in at any time.', confirm: 'Sign out')) {
              if (context.mounted) await context.read<AppState>().signOut();
            }
          },
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4))),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ]),
    );
  }
}
