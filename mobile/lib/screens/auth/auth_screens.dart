import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/password_policy.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// First screen for signed-out people.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<AppState>().notice;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0D1018)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('SmartEvents', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
              const Spacer(),
              const _FeatureCards().animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),
              const SizedBox(height: 28),
              Text('Your event.\nYour price.',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontSize: 40, height: 1.05))
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 500.ms),
              const SizedBox(height: 12),
              Text(
                'Negotiate with venues, caterers and decorators in real time. Payment is held safely until your event is delivered, and Smartie AI helps you plan.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15, height: 1.45),
              ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
              if (notice != null) ...[
                const SizedBox(height: 14),
                Text(notice, style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E1B4B), minimumSize: const Size.fromHeight(56)),
                onPressed: () => context.push('/register'),
                child: const Text('Create an account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => context.push('/login'),
                child: const Text('I already have an account'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    Widget card(IconData icon, String title, String text) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Icon(icon, color: const Color(0xFFA5B4FC)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5)),
              ]),
            ),
          ]),
        );
    return Column(children: [
      card(Icons.handshake_rounded, 'Live negotiation', 'Offer, counter and chat with vendors'),
      const SizedBox(height: 10),
      card(Icons.verified_user_rounded, 'Escrow protection', 'Money is released only after delivery'),
      const SizedBox(height: 10),
      card(Icons.auto_awesome_rounded, 'Smartie AI', 'Budget plans, designs and answers'),
    ]);
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: p.muted, fontSize: 15)),
                const SizedBox(height: 26),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signIn(_email.text, _password.text);
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see your bookings, offers and passes.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email address',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: !_show,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _show ? 'Hide password' : 'Show password',
                    icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
              ),
            ]),
          ),
        ),
        if (_error != null) _ErrorBanner(_error!),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: _busy ? const _Spinner() : const Text('Sign in'),
        ),
        const SizedBox(height: 14),
        TextButton(onPressed: () => context.pushReplacement('/register'), child: const Text('New here? Create an account')),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'customer';
  String _category = 'decoration';
  bool _busy = false;
  bool _show = false;
  String? _error;
  String? _done;

  static const _categories = {
    'venue': 'Venue', 'catering': 'Catering', 'decoration': 'Decoration',
    'photography': 'Photography', 'music': 'Music', 'makeup': 'Makeup',
  };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!isStrongPassword(_password.text, name: _name.text, email: _email.text)) {
      setState(() => _error = 'Choose a stronger password: it must meet every rule below the field.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await context.read<AppState>().register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            role: _role,
            category: _category,
          );
      if (msg != null && mounted) setState(() => _done = msg);
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (_done != null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.mark_email_read_rounded,
          title: 'Check your inbox',
          message: _done,
          action: FilledButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Go to sign in')),
        ),
      );
    }
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'Book and negotiate as an organizer, or sell your services as a vendor.',
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'customer', label: Text('Organizer'), icon: Icon(Icons.event_available_rounded)),
            ButtonSegment(value: 'provider', label: Text('Vendor'), icon: Icon(Icons.storefront_rounded)),
          ],
          selected: {_role},
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
        const SizedBox(height: 18),
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: _role == 'provider' ? 'Business or your name' : 'Full name', prefixIcon: const Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(v ?? '') ? null : 'Enter a valid email address',
              onChanged: (_) => setState(() {}),
            ),
            if (_role == 'provider') ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'What do you offer?', prefixIcon: Icon(Icons.category_outlined)),
                items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: !_show,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _PasswordChecklist(rules: passwordRules(_password.text, name: _name.text, email: _email.text), muted: p.muted, ok: p.success),
        if (_error != null) _ErrorBanner(_error!),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: _busy ? const _Spinner() : const Text('Create account'),
        ),
        const SizedBox(height: 14),
        TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Already have an account? Sign in')),
      ],
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.rules, required this.muted, required this.ok});
  final List<PasswordRule> rules;
  final Color muted;
  final Color ok;

  @override
  Widget build(BuildContext context) {
    final met = rules.where((r) => r.ok).length;
    final level = met == rules.length ? 3 : met >= 6 ? 2 : met >= 4 ? 1 : 0;
    const labels = ['Weak', 'Fair', 'Good', 'Strong'];
    const colors = [AppColors.danger, AppColors.warning, Color(0xFF0EA5E9), Color(0xFF10B981)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Container(
              height: 5,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: met > 0 && i <= level ? colors[level] : AppPalette.of(context).border,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text(met > 0 ? labels[level] : '', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: colors[level])),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, children: [
        for (final r in rules)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 14, color: r.ok ? ok : muted),
            const SizedBox(width: 4),
            Text(r.label, style: TextStyle(fontSize: 12, color: r.ok ? ok : muted)),
          ]),
      ]),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white));
}
