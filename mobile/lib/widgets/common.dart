import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

/// A network picture with a soft placeholder and a branded fallback.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.icon = Icons.celebration_rounded, this.label});
  final String? url;
  final BoxFit fit;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 34),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w800)),
        ],
      ]),
    );
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => const ShimmerBox(),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.height, this.width, this.radius = 0});
  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Shimmer.fromColors(
      baseColor: p.surface2,
      highlightColor: p.border.withValues(alpha: 0.6),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Placeholder cards while a list loads.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 4, this.height = 120});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => ShimmerBox(height: height, radius: 22),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load this',
        message: message,
        action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      );
}

/// A coloured pill for a booking or ticket status.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = status.toLowerCase();
    final Color c = switch (s) {
      'confirmed' || 'accepted' || 'completed' || 'valid' || 'active' || 'paid' => p.success,
      'rejected' || 'cancelled' || 'no_show' || 'disputed' => AppColors.danger,
      'used' || 'checked_in' => p.muted,
      _ => p.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(
        (label ?? (s == 'confirmed' ? 'confirmed' : s.replaceAll('_', ' '))).toUpperCase(),
        style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40, this.url});
  final String name;
  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? NetImage(url)
            : Container(
                color: brand.withValues(alpha: 0.14),
                alignment: Alignment.center,
                child: Text(initials(name), style: TextStyle(color: brand, fontWeight: FontWeight.w900, fontSize: size * 0.36)),
              ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          ?trailing,
        ]),
      );
}

/// Small label + value used in detail screens.
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800, color: p.muted)),
            const SizedBox(height: 2),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.danger : null,
    ));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, required String confirm, bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(90, 44)) : FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}


/// Light / dark switch (sun in dark mode, moon in light mode), like the
/// website's navbar toggle. The choice is remembered between launches.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      color: color,
      onPressed: () => context.read<AppState>().toggleTheme(context),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, a) => RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: child)),
        child: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, key: ValueKey(dark)),
      ),
    );
  }
}
