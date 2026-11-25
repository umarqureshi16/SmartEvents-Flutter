import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/password_policy.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../auth/auth_screens.dart' show PasswordChecklist;

/// Account settings, like the website's Settings page: name and email,
/// password, and the country/region that sets the currency.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: const [
          _ProfileCard(),
          SizedBox(height: 16),
          _RegionCard(),
          SizedBox(height: 16),
          _PasswordCard(),
        ]),
      );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12.5)),
            ]),
          ),
        ]),
      );
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard();
  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AppState>().user?.name ?? '');
  late final _email = TextEditingController(text: context.read<AppState>().user?.email ?? '');
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = context.read<AppState>();
    final body = <String, String>{};
    if (_name.text.trim() != app.user?.name) body['name'] = _name.text.trim();
    if (_email.text.trim().toLowerCase() != app.user?.email.toLowerCase()) body['email'] = _email.text.trim();
    if (body.isEmpty) return showMessage(context, 'Nothing has changed.');
    setState(() => _busy = true);
    try {
      final res = await Api.instance.put('/auth/profile', body);
      if (res['user'] is Map) await app.updateUser(Map<String, dynamic>.from(res['user'] as Map));
      if (mounted) showMessage(context, res['message'] as String? ?? 'Your profile has been updated.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _CardTitle(Icons.badge_outlined, 'Your details', 'The name and email on your account'),
              TextFormField(
                controller: _name,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name', counterText: ''),
                validator: V.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: V.email,
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save details')),
            ]),
          ),
        ),
      );
}

class _RegionCard extends StatefulWidget {
  const _RegionCard();
  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard> {
  Map<String, Map<String, dynamic>> _countries = {};
  String? _country;
  String? _region;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user?.raw['locale'];
    _country = u is Map ? u['country'] as String? : null;
    _region = u is Map ? u['region'] as String? : null;
    Api.instance.get('/locale').then((r) {
      final c = (r['data'] as Map?)?['countries'];
      if (c is Map && mounted) {
        setState(() => _countries = c.map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v as Map))));
      }
    }).catchError((e) {
      if (mounted) setState(() => _error = 'Region settings are not available on this server yet.');
    });
  }

  List<String> get _regions => ((_countries[_country]?['regions'] as List?) ?? const []).map((e) => '$e').toList();

  Future<void> _save() async {
    if (_country == null) return;
    setState(() => _busy = true);
    try {
      await Api.instance.put('/locale/me', {'country': _country, 'region': _region});
      if (!mounted) return;
      final app = context.read<AppState>();
      await app.refreshMe();
      await app.loadRates();
      if (mounted) showMessage(context, 'Saved. Prices now show in ${_countries[_country]?['currency'] ?? 'your currency'}.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _CardTitle(Icons.public_rounded, 'Region and currency', 'Sets the currency for prices and the style Smartie designs in'),
            if (_error != null)
              Text(_error!, style: TextStyle(color: AppPalette.of(context).muted))
            else if (_countries.isEmpty)
              const LinearProgressIndicator()
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _countries.containsKey(_country) ? _country : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Country'),
                items: _countries.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value['name']} (${e.value['currency']})')))
                    .toList(),
                onChanged: (v) => setState(() {
                  _country = v;
                  _region = null;
                }),
              ),
              if (_regions.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey(_country),
                  initialValue: _regions.contains(_region) ? _region : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Region (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
                    ..._regions.map((r) => DropdownMenuItem<String?>(value: r, child: Text(r))),
                  ],
                  onChanged: (v) => setState(() => _region = v),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(onPressed: _busy || _country == null ? null : _save, child: Text(_busy ? 'Saving…' : 'Save region')),
            ],
          ]),
        ),
      );
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard();
  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await Api.instance.put('/auth/password', {'currentPassword': _current.text, 'newPassword': _next.text});
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) showMessage(context, res['message'] as String? ?? 'Your password has been changed.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final u = context.watch<AppState>().user;
    final google = u?.raw['googleId'] != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _CardTitle(Icons.lock_outline_rounded, 'Password',
                google ? 'You sign in with Google. Use "Forgot password" on the sign-in screen to add a password.' : 'Change the password you sign in with'),
            TextFormField(
              controller: _current,
              obscureText: !_show,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide passwords' : 'Show passwords',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Your current password is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: !_show,
              maxLength: 128,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'New password', counterText: ''),
              validator: (v) {
                final err = V.newPassword(v, name: u?.name ?? '', email: u?.email ?? '');
                if (err != null) return err;
                return v == _current.text ? 'New password must be different from the current one' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: !_show,
              decoration: const InputDecoration(labelText: 'Type the new password again'),
              validator: (v) => v == _next.text ? null : 'The passwords do not match',
            ),
            const SizedBox(height: 12),
            PasswordChecklist(rules: passwordRules(_next.text, name: u?.name ?? '', email: u?.email ?? ''), muted: p.muted, ok: p.success),
            const SizedBox(height: 14),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Change password')),
          ]),
        ),
      ),
    );
  }
}

/// "Contact us", the same form as the website's Contact page.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AppState>().user?.name ?? '');
  late final _email = TextEditingController(text: context.read<AppState>().user?.email ?? '');
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await Api.instance.post('/auth/contact', {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      showMessage(context, res['message'] as String? ?? 'Thanks! We will get back to you soon.');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Contact us')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Name', counterText: ''),
              validator: (v) => V.length(v, min: 2, max: 80, label: 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: V.email),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Subject', counterText: ''),
              validator: (v) => V.length(v, min: 3, max: 150, label: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
              validator: (v) => V.length(v, min: 10, max: 2000, label: 'Message'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending…' : 'Send message'),
            ),
          ]),
        ),
      );
}
