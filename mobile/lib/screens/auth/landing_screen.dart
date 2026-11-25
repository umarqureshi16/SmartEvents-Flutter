import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// The landing page, the same one as the website's home page
/// (client/src/pages/Home.jsx), laid out for phones: hero with the rotating
/// word, the live offer mock-up and gate pass, stats, how it works,
/// categories, featured vendors, Smartie, why SmartEvents, testimonials,
/// questions and the final call to action. It widens to two columns on
/// tablets.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<AppState>().notice;
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 760;
        return CustomScrollView(slivers: [
          const _TopBar(),
          SliverList.list(children: [
            if (notice != null) _Notice(notice),
            _Hero(wide: wide),
            const _Stats(),
            _HowItWorks(wide: wide),
            _Categories(wide: wide),
            const _FeaturedVendors(),
            _SmartieTeaser(wide: wide),
            _WhySmartEvents(wide: wide),
            const _Testimonials(),
            const _Faq(),
            const _FinalCta(),
            const _Footer(),
          ]),
        ]);
      }),
    );
  }
}

// ----------------------------------------------------------------- tokens

class _L {
  _L._();
  static const glow = Color(0xFF0ABF53);
  static const slate900 = Color(0xFF0F172A);
  static const emerald400 = Color(0xFF34D399);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);

  static Color success(BuildContext c) => AppPalette.of(c).success;
  static Color muted(BuildContext c) => AppPalette.of(c).muted;
  static Color border(BuildContext c) => AppPalette.of(c).border;
  static Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;
  static Color surface2(BuildContext c) => AppPalette.of(c).surface2;
  static Color bg(BuildContext c) => Theme.of(c).scaffoldBackgroundColor;
  static Color fg(BuildContext c) => Theme.of(c).colorScheme.onSurface;
  static Color brand(BuildContext c) => Theme.of(c).colorScheme.primary;

  static TextStyle mono({double size = 11, FontWeight weight = FontWeight.w700, Color? color, double spacing = 1.4}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing);
}

/// Section with the website's spacing and a centred, width-limited body.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.color, this.dark = false, this.vertical = 56});
  final Widget child;
  final Color? color;
  final bool dark;
  final double vertical;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color ?? (dark ? _L.slate900 : _L.bg(context)),
          border: Border(bottom: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.08) : _L.border(context))),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: vertical),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: child)),
      );
}

/// "TRANSACTION FLOW" + "How SmartEvents Works" + optional line.
class _Heading extends StatelessWidget {
  const _Heading(this.kicker, this.title, {this.body, this.center = true, this.trailing});
  final String kicker;
  final String title;
  final String? body;
  final bool center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final text = Column(crossAxisAlignment: align, children: [
      Text(kicker, style: _L.mono(color: _L.success(context), spacing: 2.4)),
      const SizedBox(height: 8),
      Text(title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: _L.fg(context))),
      if (body != null) ...[
        const SizedBox(height: 8),
        Text(body!, textAlign: center ? TextAlign.center : TextAlign.start, style: TextStyle(fontSize: 13, height: 1.5, color: _L.muted(context))),
      ],
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: trailing == null ? text : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: text), trailing!]),
    );
  }
}

/// The website's primary pill button (brand colour with a soft glow).
class _PrimaryPill extends StatelessWidget {
  const _PrimaryPill({required this.label, required this.onTap, this.big = true, this.expand = false});
  final String label;
  final VoidCallback onTap;
  final bool big;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final brand = _L.brand(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: -5, offset: const Offset(0, 10))],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Theme.of(context).brightness == Brightness.dark ? _L.bg(context) : Colors.white,
          shape: const StadiumBorder(),
          padding: EdgeInsets.symmetric(horizontal: big ? 28 : 18, vertical: big ? 18 : 12),
          minimumSize: expand ? const Size.fromHeight(54) : null,
          textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 15 : 13),
        ),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: big ? 18 : 15),
        ]),
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.label, required this.onTap, this.expand = false});
  final String label;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _L.fg(context),
          side: BorderSide(color: _L.border(context)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          minimumSize: expand ? const Size.fromHeight(54) : null,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        child: Text(label),
      );
}

/// The website's rounded card (surface, border, soft shadow).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _L.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _L.border(context))),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon, {this.size = 44});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = _L.success(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: c, size: size * 0.45),
    );
  }
}

/// A responsive grid: 1, 2 or 4 columns depending on the width available.
class _Grid extends StatelessWidget {
  const _Grid({required this.children, this.minTile = 260, this.gap = 14});
  final List<Widget> children;
  final double minTile;
  final double gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / minTile).floor().clamp(1, 4);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}

// ----------------------------------------------------------------- top bar

class _Logo extends StatelessWidget {
  const _Logo({this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), blurRadius: 14)],
          ),
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: -0.785398,
            child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.42)),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) => SliverAppBar(
        pinned: true,
        floating: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: _L.bg(context),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(children: [
          const _Logo(size: 34),
          const SizedBox(width: 12),
          Text('SmartEvents', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: -0.5, color: _L.fg(context))),
        ]),
        actions: [
          TextButton(onPressed: () => context.push('/login'), child: const Text('Sign in')),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () => context.push('/register'),
              style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 16), visualDensity: VisualDensity.compact),
              child: const Text('Join'),
            ),
          ),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

// ----------------------------------------------------------------- 1. hero

class _Hero extends StatefulWidget {
  const _Hero({required this.wide});
  final bool wide;
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  static const _words = ['Counter-Offer Bids.', 'Instant QR Passes.', 'Escrow Payments.', 'Verified Vendors.'];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _words.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = _L.success(context);
    final w = MediaQuery.sizeOf(context).width;
    final h1 = w < 360 ? 38.0 : (widget.wide ? 60.0 : 44.0);

    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Badge
      InkWell(
        onTap: () => context.push('/register'),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _L.surface(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _L.brand(context).withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: success, shape: BoxShape.circle))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 1, end: 0.35, duration: 900.ms),
            const SizedBox(width: 8),
            Flexible(
              child: Text('SMARTEVENTS 3.0 · AI Concierge & Reverse Bidding',
                  style: _L.mono(size: 10.5, color: _L.brand(context), spacing: 0.8).copyWith(height: 1.45), maxLines: 2),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: success),
          ]),
        ),
      ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.3),
      const SizedBox(height: 22),
      // Headline with the rotating word
      Text('Your Event.\nYour Price.',
              style: TextStyle(fontSize: h1, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -1.6, color: _L.fg(context)))
          .animate()
          .fadeIn(delay: 100.ms, duration: 450.ms)
          .slideY(begin: 0.15),
      SizedBox(
        height: h1 * 1.25,
        child: AnimatedSwitcher(
          // Old word out first, then the new one in (like the site's mode="wait").
          duration: 700.ms,
          switchInCurve: const Interval(0.5, 1, curve: Curves.easeOut),
          switchOutCurve: const Interval(0.5, 1, curve: Curves.easeIn),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a), child: child),
          ),
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
          child: FittedBox(
            key: ValueKey(_i),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_words[_i], style: TextStyle(fontSize: h1, fontWeight: FontWeight.w800, letterSpacing: -1.4, color: success)),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Post your event budget, receive counter-bids from top verified vendors, and sell QR ticket passes with guaranteed escrow payments.',
        style: TextStyle(fontSize: 16, height: 1.55, color: _L.muted(context), fontWeight: FontWeight.w500),
      ).animate().fadeIn(delay: 200.ms, duration: 450.ms).slideY(begin: 0.15),
      const SizedBox(height: 26),
      // CTAs: full width on phones, side by side when there is room.
      LayoutBuilder(builder: (context, box) {
        final stack = box.maxWidth < 430;
        final primary = _PrimaryPill(label: 'Post an Event Free', onTap: () => context.push('/register'), expand: stack);
        final outline = _OutlinePill(label: 'Browse & Bid as Vendor', onTap: () => context.push('/login'), expand: stack);
        return stack
            ? Column(children: [primary, const SizedBox(height: 12), outline])
            : Wrap(spacing: 14, runSpacing: 12, children: [primary, outline]);
      }).animate().fadeIn(delay: 300.ms, duration: 450.ms).slideY(begin: 0.15),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 18),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: _L.border(context)))),
        child: Wrap(spacing: 18, runSpacing: 10, children: [
          for (final t in const ['2-Way Counter-Offers', 'QR Code Gate Entry', 'Stripe & Escrow Protected'])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline_rounded, size: 16, color: success),
              const SizedBox(width: 6),
              Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _L.muted(context))),
            ]),
        ]),
      ).animate().fadeIn(delay: 400.ms, duration: 450.ms),
    ]);

    const mock = _HeroMockup();

    return Stack(children: [
      // Background glows, like the website.
      Positioned(
        top: -120,
        right: -140,
        child: IgnorePointer(
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_L.glow.withValues(alpha: 0.16), _L.glow.withValues(alpha: 0.05), Colors.transparent]),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 40,
        left: -120,
        child: IgnorePointer(
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [success.withValues(alpha: 0.10), Colors.transparent])),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 44),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: widget.wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(flex: 7, child: copy),
                    const SizedBox(width: 40),
                    const Expanded(flex: 5, child: mock),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, const SizedBox(height: 34), mock]),
          ),
        ),
      ),
    ]);
  }
}

/// The live counter-offer card and the floating gate pass from the website.
class _HeroMockup extends StatelessWidget {
  const _HeroMockup();

  @override
  Widget build(BuildContext context) {
    final success = _L.success(context);
    final muted = _L.muted(context);
    Widget line(String label, String value, {bool strike = false, bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: strong ? _L.fg(context) : muted, fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
            Text(value,
                style: _L.mono(
                  size: strong ? 16 : 12,
                  weight: strong || !strike ? FontWeight.w800 : FontWeight.w500,
                  color: strong ? success : muted,
                  spacing: 0,
                ).copyWith(decoration: strike ? TextDecoration.lineThrough : null)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _L.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _L.border(context)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 18))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(radius: 17, backgroundColor: success.withValues(alpha: 0.15), child: Text('GR', style: TextStyle(color: success, fontWeight: FontWeight.w800, fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Gourmet Royale Catering', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
                Text('4.9 ★ (184 reviews)', style: _L.mono(size: 10, weight: FontWeight.w500, color: muted, spacing: 0)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
              child: Text('COUNTER-OFFER', style: _L.mono(size: 9.5, color: success, spacing: 0.5)),
            ),
          ]),
          Divider(height: 26, color: _L.border(context)),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _L.surface2(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _L.border(context))),
            child: Column(children: [
              line('Original Host Budget:', money(5000), strike: true),
              line('Vendor Initial Quote:', money(4500)),
              Divider(height: 14, color: _L.border(context)),
              line('Proposed Counter Price:', money(4200), strong: true),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => context.push('/login'),
                style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Accept & Pay Escrow', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => context.push('/login'),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18), foregroundColor: _L.fg(context)),
              child: const Text('Counter', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scaleXY(begin: 0.92, curve: Curves.easeOutBack),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _L.slate900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.qr_code_2_rounded, color: _L.emerald400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GATE PASS TICKET', style: _L.mono(size: 9.5, color: _L.slate300, spacing: 0.6)),
              const SizedBox(height: 2),
              const Text('VIP Gala Pass #TKT-9421', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _L.glow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _L.glow.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: _L.emerald400, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 1, end: 0.3, duration: 800.ms),
              const SizedBox(width: 6),
              Text('VALID ENTRY', style: _L.mono(size: 9.5, color: _L.emerald400, spacing: 0.4)),
            ]),
          ),
        ]),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -8, duration: 2000.ms, curve: Curves.easeInOut),
    ]);
  }
}

// ----------------------------------------------------------------- 2. stats

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    const stats = [
      (6200, '', '+', 'Events Formed', true),
      (99.98, '', '%', 'Uptime Reliability', false),
      (1500, '', '+', 'Verified Vendors', true),
      (98.6, '', '%', 'Check-In Verification', false),
      (4.5, '\$', 'M+', 'Escrow Volume', true),
    ];
    return _Section(
      dark: true,
      vertical: 44,
      child: _Grid(minTile: 150, gap: 22, children: [
        for (final (value, pre, post, label, green) in stats)
          Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: 1400.ms,
              curve: Curves.easeOutCubic,
              builder: (_, v, _) {
                final shown = value is int
                    ? _thousands(v.round())
                    : v.toStringAsFixed(value.toString().split('.').last.length);
                return Text('$pre$shown$post', style: _L.mono(size: 30, weight: FontWeight.w900, color: green ? _L.emerald400 : Colors.white, spacing: -0.5));
              },
            ),
            const SizedBox(height: 6),
            Text(label.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _L.slate300, letterSpacing: 0.6)),
          ]),
      ]),
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

// ----------------------------------------------------------------- 3. how it works

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('01', 'Publish Event RFP', 'Hosts outline their requirements, location, estimated guest capacity, and initial budget parameters.', Icons.calendar_month_rounded),
      ('02', 'AI Concierge Analysis', 'Our smart agent analyzes requirements, generates matching recommendations, and scopes realistic budgets.', Icons.auto_awesome_rounded),
      ('03', 'InDrive-Style Bidding', 'Negotiate pricing in real-time. Make counter-offers directly to vendors until both sides lock in the ideal price.', Icons.payments_rounded),
      ('04', 'Escrow & QR Gate Passes', 'Funds are secured in escrow. Attendee tickets generate dynamic QR passes validated at gate terminals.', Icons.qr_code_2_rounded),
    ];
    return _Section(
      color: _L.surface(context),
      child: Column(children: [
        const _Heading('TRANSACTION FLOW', 'How SmartEvents Works', body: 'Four simple steps to host, negotiate, and verify your event listings securely.'),
        _Grid(children: [
          for (final (n, title, body, icon) in steps)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _L.bg(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: _L.border(context))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(n, style: _L.mono(size: 28, weight: FontWeight.w900, color: _L.success(context).withValues(alpha: 0.7), spacing: 0)),
                  const Spacer(),
                  _IconTile(icon, size: 40),
                ]),
                const SizedBox(height: 14),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 13, height: 1.5, color: _L.muted(context))),
              ]),
            ),
        ]),
      ]),
    );
  }
}

// ----------------------------------------------------------------- 4. categories

class _Categories extends StatelessWidget {
  const _Categories({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const cats = [
      ('Venues', 'Hotels, lofts, convention halls', Icons.apartment_rounded),
      ('Catering & Dining', 'Multi-course dinners, bars, waitstaff', Icons.restaurant_rounded),
      ('Decoration & Design', 'Florals, theme designs, backdrop sets', Icons.auto_awesome_rounded),
      ('Photography & Film', 'Professional event shoots & highlights', Icons.photo_camera_rounded),
      ('Music & Stage AV', 'Live DJ systems, concert truss, sound rigs', Icons.graphic_eq_rounded),
      ('Makeup Artists', 'Professional event makeup & styling', Icons.brush_rounded),
    ];
    return _Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Heading('DISCOVER CATEGORIES', 'Browse Verified Marketplace',
            center: false,
            trailing: TextButton(onPressed: () => context.push('/register'), child: const Text('Browse all'))),
        _Grid(minTile: 300, children: [
          for (final (name, desc, icon) in cats)
            _Card(
              onTap: () => context.push('/register'),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _IconTile(icon, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(desc, style: TextStyle(fontSize: 12, color: _L.muted(context))),
                  ]),
                ),
                Icon(Icons.north_east_rounded, size: 17, color: _L.muted(context)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

// ----------------------------------------------------------------- 5. featured vendors

class _FeaturedVendors extends StatefulWidget {
  const _FeaturedVendors();
  @override
  State<_FeaturedVendors> createState() => _FeaturedVendorsState();
}

class _FeaturedVendorsState extends State<_FeaturedVendors> {
  List<VendorItem> _vendors = [];

  @override
  void initState() {
    super.initState();
    // The real directory, like the website (no made-up businesses).
    Api.instance.get('/vendor/list', query: {'limit': 6}).then((r) {
      final list = (r['data'] as List? ?? []).whereType<Map>().map((m) => VendorItem(Map<String, dynamic>.from(m))).toList();
      if (mounted) setState(() => _vendors = list);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_vendors.isEmpty) return const SizedBox.shrink();
    return _Section(
      color: _L.surface(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Heading('PREMIUM PROVIDERS', 'Featured Professionals', center: false),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _vendors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final v = _vendors[i];
              return SizedBox(
                width: 250,
                child: _Card(
                  padding: EdgeInsets.zero,
                  onTap: () => context.push('/register'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      height: 130,
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF4338CA)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: Stack(children: [
                        Center(child: Text(v.name.isEmpty ? '?' : v.name[0], style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.9)))),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _L.slate900.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(999)),
                            child: Text('Trust: ${v.trustScore.round()}%', style: _L.mono(size: 9.5, color: Colors.white, spacing: 0)),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v.category.toUpperCase(), style: _L.mono(size: 10, color: _L.success(context), spacing: 1.6)),
                        const SizedBox(height: 4),
                        Text(v.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: Text(v.location, style: TextStyle(fontSize: 12, color: _L.muted(context), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          Text(v.rating > 0 ? '${v.rating.toStringAsFixed(1)} ★' : 'New', style: TextStyle(fontSize: 12, color: _L.success(context), fontWeight: FontWeight.w800)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- 6. Smartie

class _SmartieTeaser extends StatelessWidget {
  const _SmartieTeaser({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: _L.emerald400.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
        child: Text('MEET SMARTIE', style: _L.mono(size: 11, color: _L.emerald400)),
      ),
      const SizedBox(height: 16),
      const Text('The Smart AI Concierge', style: TextStyle(color: Colors.white, fontSize: 32, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -1)),
      const SizedBox(height: 12),
      const Text(
        'Use an AI assistant grounded in your own data to generate comprehensive RFP packages, analyze event budgets, manage vendor packages, and plan your schedules automatically.',
        style: TextStyle(color: _L.slate300, fontSize: 13.5, height: 1.55),
      ),
      const SizedBox(height: 18),
      for (final t in const ['Budget constraints and pricing analyzers', 'Timeline planner step-by-step generators', 'Answers grounded in your live bookings and events'])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: _L.emerald400),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: const TextStyle(color: _L.slate300, fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
        ),
      const SizedBox(height: 10),
      _PrimaryPill(label: 'Open AI Concierge', big: false, onTap: () => context.push('/register')),
    ]);

    final chat = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: _L.glow.withValues(alpha: 0.2), child: const Icon(Icons.auto_awesome_rounded, size: 16, color: _L.emerald400)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Smartie AI Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            Text('Agent Status: Active', style: _L.mono(size: 10, weight: FontWeight.w500, color: _L.slate300, spacing: 0)),
          ]),
        ]),
        Divider(height: 26, color: Colors.white.withValues(alpha: 0.1)),
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text('"I need a catering vendor for 300 guests in Lahore with a maximum budget of ${money(4000)}."',
                  style: const TextStyle(color: _L.slate300, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideX(begin: -0.08),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _L.glow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _L.glow.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('I found 3 verified caterers matching your budget. I can draft an RFP with the following breakdown:',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final l in ['Catering quote: ${money(3600)}', 'Service fee: ${money(200)}', 'Remaining margin: ${money(200)}'])
                  Text('•  $l', style: _L.mono(size: 11, weight: FontWeight.w500, color: _L.slate300, spacing: 0)),
              ]),
            ),
          ),
        ).animate().fadeIn(delay: 450.ms, duration: 400.ms).slideX(begin: 0.08),
      ]),
    );

    return Stack(children: [
      Positioned.fill(child: Container(color: _L.slate900)),
      Positioned(
        top: -100,
        right: -120,
        child: IgnorePointer(
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_L.glow.withValues(alpha: 0.12), Colors.transparent])),
          ),
        ),
      ),
      _Section(
        dark: true,
        color: Colors.transparent,
        child: wide
            ? Row(children: [Expanded(child: copy), const SizedBox(width: 40), Expanded(child: chat)])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, const SizedBox(height: 30), chat]),
      ),
    ]);
  }
}

// ----------------------------------------------------------------- 7. why

class _WhySmartEvents extends StatelessWidget {
  const _WhySmartEvents({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Real-Time Negotiation', 'Secure the price you want through counter-offer history tracking and concurrency checks.', Icons.payments_rounded),
      ('AI Concierge Planning', 'Generative budget breakdowns and RFP scoper tools driven by vector embeddings.', Icons.auto_awesome_rounded),
      ('Verified Providers', 'Vendor credentials and portfolio catalogs checked by platform moderators.', Icons.verified_user_rounded),
      ('Secure Escrow Process', 'Escrow payment releases locked securely via Stripe ledgers.', Icons.shield_rounded),
    ];
    return _Section(
      color: _L.surface(context),
      child: Column(children: [
        const _Heading('WHY SMARTEVENTS', 'Enterprise Reliability, Standardized'),
        _Grid(children: [
          for (final (title, desc, icon) in items)
            _Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _IconTile(icon, size: 48),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(fontSize: 13, height: 1.5, color: _L.muted(context))),
              ]),
            ),
        ]),
      ]),
    );
  }
}

// ----------------------------------------------------------------- 8. testimonials

class _Testimonials extends StatelessWidget {
  const _Testimonials();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Sarah Jenkins', 'Wedding Coordinator', 'SmartEvents saved our clients thousands of dollars. The InDrive negotiation let us communicate budget boundaries clearly, and escrow payouts kept our vendors feeling secure.'),
      ('David Chen', 'Tech Summit Lead', 'Managing attendee VIP tickets with the staff QR gate scanner was incredibly smooth. We checked in 800 attendees with zero ticket duplication errors.'),
      ('Umar Farooq', 'Premium AV Supplier', 'As a provider, having a live dashboard of incoming proposals and negotiations has completely streamlined our onboarding. We respond instantly and close deals in minutes.'),
    ];
    return _Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Heading('SUCCESS STORIES', 'Loved by Event Organizers'),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final (name, role, quote) = items[i];
              return SizedBox(
                width: 290,
                child: _Card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [for (var s = 0; s < 5; s++) Icon(Icons.star_rounded, size: 16, color: _L.success(context))]),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text('"$quote"',
                          style: TextStyle(fontSize: 12.5, height: 1.55, fontStyle: FontStyle.italic, color: _L.muted(context), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.fade),
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(role, style: _L.mono(size: 10, weight: FontWeight.w500, color: _L.muted(context), spacing: 0)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- 9. FAQ

class _Faq extends StatelessWidget {
  const _Faq();

  @override
  Widget build(BuildContext context) {
    const faqs = [
      ('How does InDrive-style negotiation work on SmartEvents?',
          'When you post an event RFP or book a service package, you specify your budget or target offer price. The vendor can accept the offer immediately or counter with their proposed price. You both can exchange counter-offers in real-time until a mutual price is agreed upon and locked in escrow.'),
      ('What is the Escrow Budget protection?',
          "Once you accept a vendor's counter-offer, the final price is deposited into the SmartEvents Escrow Ledger. The funds are securely held and are only released to the vendor's bank payout account once the event is marked as successfully completed or checked in."),
      ('How does the mobile staff QR Scanner gate work?',
          'Attendees receive QR gate passes in their ticket wallet. At the entrance, staff scan them with "Check in guests" in the app. It verifies the pass instantly and prevents duplicate entry.'),
      ('What does the AI Concierge do?',
          'Smartie, your AI Concierge, uses a large language model, fed with your live platform data, to help you analyze event budgets, generate comprehensive RFP requirements from simple prompts, compare vendor service packages, and plan your event timelines step-by-step.'),
    ];
    return _Section(
      color: _L.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(children: [
          const _Heading('COMMON QUESTIONS', 'Frequently Asked Questions'),
          for (final (q, a) in faqs)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _L.border(context)))),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                  childrenPadding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                  iconColor: _L.success(context),
                  collapsedIconColor: _L.muted(context),
                  title: Text(q, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  children: [Text(a, style: TextStyle(fontSize: 13, height: 1.55, color: _L.muted(context)))],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------- 10. final CTA + footer

class _FinalCta extends StatelessWidget {
  const _FinalCta();
  @override
  Widget build(BuildContext context) => _Section(
        color: _L.surface2(context),
        vertical: 64,
        child: Column(children: [
          Text('Secure the perfect pricing model for your next event today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w900, letterSpacing: -1, color: _L.fg(context))),
          const SizedBox(height: 26),
          _PrimaryPill(label: 'Get Started Free', onTap: () => context.push('/register')),
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.push('/login'), child: const Text('I already have an account')),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Container(
        color: _L.slate900,
        padding: EdgeInsets.fromLTRB(20, 32, 20, 32 + MediaQuery.paddingOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            _Logo(size: 30),
            SizedBox(width: 10),
            Text('SmartEvents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
          ]),
          const SizedBox(height: 12),
          const Text('Negotiate, book and check in, with payments held safely in escrow.', style: TextStyle(color: _L.slate400, fontSize: 12.5)),
          const SizedBox(height: 18),
          Wrap(spacing: 18, runSpacing: 8, children: [
            for (final (label, path) in const [('Sign in', '/login'), ('Create account', '/register'), ('Forgot password', '/forgot-password')])
              InkWell(onTap: () => context.push(path), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
          ]),
          Divider(height: 34, color: Colors.white.withValues(alpha: 0.1)),
          Text('© ${DateTime.now().year} SmartEvents. All rights reserved.', style: _L.mono(size: 10.5, weight: FontWeight.w500, color: _L.slate400, spacing: 0)),
        ]),
      );
}
