import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/password_policy.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
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

/// "Continue with Google", shared by sign-in and sign-up.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, required this.busy, this.label = 'Continue with Google'});
  final VoidCallback? onPressed;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), side: BorderSide(color: p.border)),
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
                child: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4285F4), fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: p.muted))),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

bool _needsAdminCode(Object e) => e is ApiException && (e.code == 'ADMIN_CODE_REQUIRED' || e.code == 'ADMIN_CODE_INVALID');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _adminCode = TextEditingController();
  bool _busy = false;
  bool _google = false;
  bool _show = false;
  bool _showAdmin = false;
  bool _unverified = false;
  String? _error;

  void _fail(Object e) {
    setState(() {
      _error = Api.messageOf(e);
      if (_needsAdminCode(e)) _showAdmin = true;
      _unverified = e is ApiException && e.status == 403 && e.message.toLowerCase().contains('verif');
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _unverified = false;
    });
    try {
      await context.read<AppState>().signIn(_email.text, _password.text, adminCode: _adminCode.text);
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withGoogle() async {
    setState(() {
      _google = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signInWithGoogle(adminCode: _adminCode.text);
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _google = false);
    }
  }

  Future<void> _resend() async {
    final err = V.email(_email.text);
    if (err != null) return setState(() => _error = err);
    try {
      final res = await Api.instance.post('/auth/resend-verification', {'email': _email.text.trim()});
      if (mounted) showMessage(context, res['message'] as String? ?? 'A new verification link is on its way.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see your bookings, offers and passes.',
      children: [
        GoogleButton(onPressed: _withGoogle, busy: _google),
        const _OrDivider(),
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
                validator: V.email,
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
                validator: (v) => (v ?? '').isEmpty ? 'Password is required' : null,
              ),
              if (_showAdmin) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _adminCode,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin access code',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    helperText: 'Needed for admin and super admin accounts',
                  ),
                  validator: (v) => (v ?? '').length > 200 ? 'The code is too long' : null,
                ),
              ],
            ]),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
        ),
        if (_error != null) _ErrorBanner(_error!),
        if (_unverified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, children: [
              TextButton.icon(onPressed: _resend, icon: const Icon(Icons.forward_to_inbox_rounded), label: const Text('Send the link again')),
              TextButton.icon(onPressed: () => context.push('/verify-email'), icon: const Icon(Icons.link_rounded), label: const Text('I have the link')),
            ]),
          ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: _busy ? const _Spinner() : const Text('Sign in'),
        ),
        if (!_showAdmin)
          TextButton(onPressed: () => setState(() => _showAdmin = true), child: const Text('Admin? Enter your access code')),
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
  final _adminCode = TextEditingController();
  String _role = 'customer';
  String _category = 'decoration';
  bool _busy = false;
  bool _google = false;
  bool _show = false;
  String? _error;
  String? _done;

  bool get _elevated => _role == 'admin' || _role == 'superadmin';

  static const categories = {
    'venue': 'Venue', 'catering': 'Catering', 'decoration': 'Decoration',
    'photography': 'Photography', 'music': 'Music', 'makeup': 'Makeup',
  };

  String? _adminCodeError() {
    if (!_elevated) return null;
    final c = _adminCode.text.trim();
    if (c.isEmpty) return 'The admin signup code is required';
    if (c.length > 200) return 'The code is too long';
    return null;
  }

  Future<void> _submit() async {
    final codeError = _adminCodeError();
    final valid = _form.currentState!.validate();
    if (codeError != null) setState(() => _error = codeError);
    if (!valid || codeError != null) return;
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
            adminCode: _elevated ? _adminCode.text.trim() : null,
          );
      if (msg != null && mounted) setState(() => _done = msg);
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withGoogle() async {
    final codeError = _adminCodeError();
    if (codeError != null) {
      setState(() => _error = '$codeError. Enter it first, then sign up with Google.');
      return;
    }
    setState(() {
      _google = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signInWithGoogle(role: _role, category: _category, adminCode: _elevated ? _adminCode.text : null);
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _google = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    if (_done != null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.mark_email_read_rounded,
          title: 'Check your inbox',
          message: _done,
          action: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Go to sign in')),
            TextButton(onPressed: () => context.push('/verify-email'), child: const Text('Paste the link from the email')),
          ]),
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
          selected: _elevated ? <String>{} : {_role},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) => setState(() => _role = s.isEmpty ? 'customer' : s.first),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<String>(
            tooltip: 'Admin accounts',
            onSelected: (r) => setState(() => _role = r),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'admin', child: Text('Admin')),
              PopupMenuItem(value: 'superadmin', child: Text('Super admin')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _elevated ? 'Signing up as ${_role == 'admin' ? 'Admin' : 'Super admin'}' : 'Admin sign-up',
                style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ),
        if (_role == 'provider') ...[
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'What do you offer?', prefixIcon: Icon(Icons.category_outlined)),
            items: categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 14),
        ],
        if (_elevated) ...[
          TextField(
            controller: _adminCode,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Admin signup code', prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
          ),
          const SizedBox(height: 14),
        ],
        GoogleButton(onPressed: _withGoogle, busy: _google, label: 'Sign up with Google'),
        const _OrDivider(),
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: _role == 'provider' ? 'Business or your name' : 'Full name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              validator: V.name,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: V.email,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: !_show,
              maxLength: 128,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                counterText: '',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              validator: (v) => V.newPassword(v, name: _name.text, email: _email.text),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        PasswordChecklist(rules: passwordRules(_password.text, name: _name.text, email: _email.text), muted: p.muted, ok: p.success),
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

/// Pulls the token out of a pasted link (`.../reset-password/TOKEN` or
/// `...?token=TOKEN`), or returns the text as it is when it is the token.
String tokenFrom(String text) {
  final s = text.trim();
  final uri = Uri.tryParse(s);
  if (uri != null && uri.hasScheme) {
    final q = uri.queryParameters['token'];
    if (q != null && q.isNotEmpty) return q;
    final segs = uri.pathSegments.where((x) => x.isNotEmpty).toList();
    if (segs.isNotEmpty) return segs.last;
  }
  return s;
}

/// Forgot password: emails a reset link, then sets the new password here
/// from that link (the link also works on the website).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  bool _show = false;
  String? _error;

  Future<void> _send() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.post('/auth/forgot-password', {'email': _email.text.trim()});
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Api.instance.post('/auth/reset-password', {'token': tokenFrom(_link.text), 'password': _password.text});
      if (!mounted) return;
      showMessage(context, res['message'] as String? ?? 'Your password was changed. Sign in with the new one.');
      context.pushReplacement('/login');
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _AuthScaffold(
      title: _sent ? 'Set a new password' : 'Forgot your password?',
      subtitle: _sent
          ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way. Paste that link here.'
          : 'Enter your email and we will send you a link to choose a new password.',
      children: [
        if (!_sent)
          Form(
            key: _emailForm,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: V.email,
              onFieldSubmitted: (_) => _send(),
            ),
          )
        else
          Form(
            key: _resetForm,
            child: Column(children: [
              TextFormField(
                controller: _link,
                decoration: const InputDecoration(labelText: 'Reset link from the email', prefixIcon: Icon(Icons.link_rounded)),
                validator: (v) => tokenFrom(v ?? '').isEmpty ? 'Paste the link from the email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: !_show,
                maxLength: 128,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'New password',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _show ? 'Hide password' : 'Show password',
                    icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
                validator: (v) => V.newPassword(v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: !_show,
                decoration: const InputDecoration(labelText: 'Type it again', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => v == _password.text ? null : 'The passwords do not match',
              ),
              const SizedBox(height: 12),
              PasswordChecklist(rules: passwordRules(_password.text), muted: p.muted, ok: p.success),
            ]),
          ),
        if (_error != null) _ErrorBanner(_error!),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : (_sent ? _reset : _send),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: _busy ? const _Spinner() : Text(_sent ? 'Save new password' : 'Send reset link'),
        ),
        if (_sent) TextButton(onPressed: () => setState(() => _sent = false), child: const Text('Send the link again')),
      ],
    );
  }
}

/// Verifies the email address from the link in the welcome email.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _link = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Api.instance.post('/auth/verify-email', {'token': tokenFrom(_link.text)});
      if (!mounted) return;
      showMessage(context, res['message'] as String? ?? 'Your email is verified. You can sign in now.');
      context.pushReplacement('/login');
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Verify your email',
        subtitle: 'Paste the link from the email we sent you.',
        children: [
          Form(
            key: _form,
            child: TextFormField(
              controller: _link,
              decoration: const InputDecoration(labelText: 'Verification link', prefixIcon: Icon(Icons.link_rounded)),
              validator: (v) => tokenFrom(v ?? '').isEmpty ? 'Verification token is required' : null,
            ),
          ),
          if (_error != null) _ErrorBanner(_error!),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _verify,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            child: _busy ? const _Spinner() : const Text('Verify email'),
          ),
        ],
      );
}

class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.rules, required this.muted, required this.ok});
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
