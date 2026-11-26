import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.muted)),
        ]),
      ),
    );
  }
}

Widget _statGrid(List<Widget> stats) => LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 420 ? 4 : 3;
      final w = (box.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(spacing: 8, runSpacing: 8, children: [for (final s in stats) SizedBox(width: w, child: s)]);
    });

// ---------------------------------------------------------------- organizer profile

/// The organizer's own profile (the website's "My profile"): numbers,
/// upcoming events, spending, reviews given, plans and vendors followed.
class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});
  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/organizers/me');
      setState(() {
        _d = _m(res['data']);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditOrganizerSheet(user: _m(_d?['user'])),
    );
    if (saved != null) {
      setState(() => _d = saved);
      if (mounted) context.read<AppState>().refreshMe();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorState(message: _error!, onRetry: _load));
    final d = _d;
    if (d == null) return Scaffold(appBar: AppBar(), body: const LoadingList(count: 4, height: 90));
    final p = AppPalette.of(context);
    final u = _m(d['user']);
    final s = _m(d['stats']);
    final interests = (u['interests'] as List? ?? []).map((e) => '$e').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My profile'), actions: [IconButton(tooltip: 'Edit profile', onPressed: _edit, icon: const Icon(Icons.edit_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              Api.absolute(u['avatar'] as String?) != null
                  ? Avatar(name: '${u['name'] ?? '?'}', size: 60, url: Api.absolute(u['avatar'] as String?))
                  : CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Text(initials('${u['name'] ?? ''}'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${u['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  if ((u['city'] ?? '').toString().isNotEmpty) Text('${u['city']}', style: const TextStyle(color: Colors.white70)),
                  Text('Member since ${shortDate(parseDate(u['memberSince']))}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          if ((u['bio'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text('${u['bio']}', style: TextStyle(color: p.muted, height: 1.5))),
          if (interests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [for (final i in interests) Chip(label: Text(i), visualDensity: VisualDensity.compact)]),
            ),
          const SizedBox(height: 16),
          _statGrid([
            _Stat('${s['bookings'] ?? 0}', 'Bookings'),
            _Stat('${s['active'] ?? 0}', 'In negotiation'),
            _Stat('${s['completed'] ?? 0}', 'Delivered'),
            _Stat(money(s['spent'] as num?), 'Spent'),
            _Stat('${s['tickets'] ?? 0}', 'Passes', onTap: () => context.push('/tickets')),
            _Stat('${s['plans'] ?? 0}', 'Events', onTap: () => context.push('/events')),
            _Stat('${s['following'] ?? 0}', 'Following', onTap: () => context.push('/favorites')),
            _Stat('${s['reviews'] ?? 0}', 'Reviews given'),
          ]),
          if (_l(d['upcoming']).isNotEmpty) ...[
            const SectionTitle('Coming up'),
            for (final b in _l(d['upcoming']))
              Card(
                child: ListTile(
                  onTap: () => context.push('/negotiate/${idOf(b)}'),
                  title: Text('${b['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${b['vendor'] ?? ''} · ${shortDate(parseDate(b['date']))} · ${b['location'] ?? ''}'),
                  trailing: Text(money(b['price'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
          ],
          if (_l(d['spending']).isNotEmpty) ...[
            const SectionTitle('Spending'),
            for (final b in _l(d['spending']))
              Card(
                child: ListTile(
                  onTap: () => context.push('/negotiate/${idOf(b)}'),
                  title: Text('${b['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${b['vendor'] ?? ''} · escrow ${b['escrow']}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(b['price'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                    StatusChip('${b['status']}'),
                  ]),
                ),
              ),
          ],
          if (_l(d['reviews']).isNotEmpty) ...[
            const SectionTitle('Reviews you gave'),
            for (final r in _l(d['reviews']))
              Card(
                child: ListTile(
                  title: Text('${_m(r['event'])['title'] ?? 'Event'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${'★' * ((r['rating'] as num?)?.round() ?? 0)}  ${r['comment'] ?? ''}'),
                ),
              ),
          ],
        ]),
      ),
    );
  }
}

class _EditOrganizerSheet extends StatefulWidget {
  const _EditOrganizerSheet({required this.user});
  final Map<String, dynamic> user;
  @override
  State<_EditOrganizerSheet> createState() => _EditOrganizerSheetState();
}

class _EditOrganizerSheetState extends State<_EditOrganizerSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.user['name'] ?? ''}');
  late final _city = TextEditingController(text: '${widget.user['city'] ?? ''}');
  late final _bio = TextEditingController(text: '${widget.user['bio'] ?? ''}');
  late final _avatar = TextEditingController(text: '${widget.user['avatar'] ?? ''}');
  late final _cover = TextEditingController(text: '${widget.user['coverImage'] ?? ''}');
  late final List<String> _interests = (widget.user['interests'] as List? ?? []).map((e) => '$e').toList();
  final _tag = TextEditingController();
  bool _busy = false;

  static const _suggested = ['Weddings', 'Mehndi', 'Corporate', 'Birthdays', 'Conferences', 'Concerts', 'Photography', 'Decor', 'Catering'];

  String? _url(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final u = Uri.tryParse(s);
    return u != null && u.hasScheme && u.host.isNotEmpty && s.length <= 500 ? null : 'Photo links must start with https://';
  }

  void _toggle(String i) => setState(() {
        if (_interests.contains(i)) {
          _interests.remove(i);
        } else if (_interests.length < 10) {
          _interests.add(i);
        }
      });

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await Api.instance.put('/organizers/me', {
        'name': _name.text.trim(),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
        'avatar': _avatar.text.trim(),
        'coverImage': _cover.text.trim(),
        'interests': _interests,
      });
      if (!mounted) return;
      showMessage(context, 'Profile saved.');
      Navigator.pop(context, _m(res['data']));
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _form,
          child: ListView(shrinkWrap: true, children: [
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Name', counterText: ''),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Name must be at least 2 characters' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _city, maxLength: 80, decoration: const InputDecoration(labelText: 'City', counterText: '')),
            const SizedBox(height: 10),
            TextFormField(controller: _bio, maxLines: 3, maxLength: 600, decoration: const InputDecoration(labelText: 'About you', alignLabelWithHint: true)),
            const SizedBox(height: 4),
            TextFormField(controller: _avatar, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Photo link (optional)'), validator: _url),
            const SizedBox(height: 10),
            TextFormField(controller: _cover, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Cover picture link (optional)'), validator: _url),
            const SizedBox(height: 14),
            Text('Interests (up to 10)', style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.of(context).muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final i in {..._suggested, ..._interests})
                FilterChip(label: Text(i), selected: _interests.contains(i), onSelected: (_) => _toggle(i)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _tag, maxLength: 40, decoration: const InputDecoration(labelText: 'Add your own', counterText: ''))),
              IconButton(
                onPressed: () {
                  final t = _tag.text.trim();
                  if (t.length >= 2 && !_interests.contains(t)) _toggle(t);
                  _tag.clear();
                },
                icon: const Icon(Icons.add_circle_rounded),
              ),
            ]),
            const SizedBox(height: 14),
            FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(_busy ? 'Saving…' : 'Save profile')),
          ]),
        ),
      );
}

/// What a vendor sees about an organizer who sent them an offer: reliability, not contact details.
class OrganizerCardScreen extends StatefulWidget {
  const OrganizerCardScreen({super.key, required this.id});
  final String id;
  @override
  State<OrganizerCardScreen> createState() => _OrganizerCardScreenState();
}

class _OrganizerCardScreenState extends State<OrganizerCardScreen> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    Api.instance.get('/organizers/${widget.id}').then((r) {
      if (mounted) setState(() => _d = _m(r['data']));
    }).catchError((e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: const Text('Organizer')),
      body: _error != null
          ? EmptyState(icon: Icons.lock_outline_rounded, title: 'Not available', message: _error)
          : d == null
              ? const LoadingList(count: 3, height: 90)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [
                    Avatar(name: '${_m(d['user'])['name']}', size: 56, url: Api.absolute(_m(d['user'])['avatar'] as String?)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_m(d['user'])['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text([_m(d['user'])['city'], 'member since ${shortDate(parseDate(_m(d['user'])['memberSince']))}'].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                            style: TextStyle(color: p.muted)),
                      ]),
                    ),
                  ]),
                  if ((_m(d['user'])['bio'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${_m(d['user'])['bio']}')),
                  const SizedBox(height: 16),
                  _statGrid([
                    _Stat('${_m(d['stats'])['bookings'] ?? 0}', 'Bookings'),
                    _Stat('${_m(d['stats'])['completed'] ?? 0}', 'Completed'),
                    _Stat('${_m(d['stats'])['cancelled'] ?? 0}', 'Cancelled'),
                    _Stat(_m(d['stats'])['completionRate'] == null ? 'New' : '${_m(d['stats'])['completionRate']}%', 'Completion rate'),
                    _Stat('${_m(d['stats'])['disputed'] ?? 0}', 'Disputes'),
                    _Stat('${_m(d['stats'])['reviews'] ?? 0}', 'Reviews given'),
                  ]),
                  if (_l(d['reviews']).isNotEmpty) ...[
                    const SectionTitle('Reviews they wrote'),
                    for (final r in _l(d['reviews']))
                      Card(child: ListTile(title: Text('${_m(r['event'])['title'] ?? 'Event'}'), subtitle: Text('${'★' * ((r['rating'] as num?)?.round() ?? 0)}  ${r['comment'] ?? ''}'))),
                  ],
                ]),
    );
  }
}

// ---------------------------------------------------------------- booking -> event (plan)

/// Files a booking under one of the organizer's events (or takes it out).
Future<bool> fileUnderEvent(BuildContext context, Booking b) async {
  List<PlanRef> plans;
  try {
    final r = await Api.instance.get('/plans');
    plans = (r['data'] as List? ?? []).whereType<Map>().map((m) => PlanRef(Map<String, dynamic>.from(m))).toList();
  } catch (e) {
    if (context.mounted) showMessage(context, Api.messageOf(e), error: true);
    return false;
  }
  if (!context.mounted) return false;
  final picked = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('File under which event?', style: TextStyle(fontWeight: FontWeight.w800))),
        for (final pl in plans)
          ListTile(
            leading: Icon(pl.id == b.plan?.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
            title: Text(pl.title),
            subtitle: Text(dateRange(pl.date, pl.endDate, withDays: false)),
            onTap: () => Navigator.pop(c, pl.id),
          ),
        if (plans.isEmpty) const ListTile(title: Text('You have no events yet. Create one under "My events".')),
        ListTile(leading: const Icon(Icons.link_off_rounded), title: const Text('Not linked to an event'), onTap: () => Navigator.pop(c, '')),
      ]),
    ),
  );
  if (picked == null || !context.mounted) return false;
  try {
    await Api.instance.put('/bookings/${b.id}/plan', {'planId': picked.isEmpty ? null : picked});
    if (context.mounted) showMessage(context, picked.isEmpty ? 'Taken out of the event.' : 'Filed under the event.');
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, Api.messageOf(e), error: true);
    return false;
  }
}

// ---------------------------------------------------------------- listing insights

/// For a vendor's own listing: how ready it is and how its passes are selling.
class ListingInsightsSheet extends StatefulWidget {
  const ListingInsightsSheet({super.key, required this.event});
  final EventItem event;
  @override
  State<ListingInsightsSheet> createState() => _ListingInsightsSheetState();
}

class _ListingInsightsSheetState extends State<ListingInsightsSheet> {
  Map<String, dynamic>? _ready;
  Map<String, dynamic>? _sales;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.wait([
      Api.instance.get('/events/${widget.event.id}/readiness'),
      Api.instance.get('/tickets/event/${widget.event.id}'),
    ]).then((r) {
      if (mounted) {
        setState(() {
          _ready = _m(r[0]['data']);
          _sales = _m(r[1]['data']);
        });
      }
    }).catchError((e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = _m(_sales?['summary']);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _error != null
            ? Text(_error!)
            : _ready == null
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                : ListView(shrinkWrap: true, children: [
                    Text(widget.event.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    Row(children: [
                      Text('${_ready!['score'] ?? 0}%', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: p.success)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Listing readiness', style: TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                    LinearProgressIndicator(value: ((_ready!['score'] as num?) ?? 0) / 100, minHeight: 8, borderRadius: BorderRadius.circular(9)),
                    const SizedBox(height: 10),
                    for (final c in _l(_ready!['checks']))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(c['status'] == 'pass' ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: c['status'] == 'pass' ? p.success : p.warning),
                        title: Text('${c['label']}'),
                      ),
                    const SectionTitle('Passes'),
                    _statGrid([
                      _Stat('${s['sold'] ?? 0}/${s['capacity'] ?? 0}', 'Sold'),
                      _Stat('${s['checkedIn'] ?? 0}', 'Checked in'),
                      _Stat('${s['cancelled'] ?? 0}', 'Cancelled'),
                      _Stat(money(s['revenue'] as num?), 'Revenue'),
                    ]),
                    const SizedBox(height: 8),
                    for (final t in _l(_sales?['tickets']).take(30))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${_m(t['attendee'])['name'] ?? 'Guest'}'),
                        subtitle: Text('${t['ticketNumber'] ?? ''}'),
                        trailing: StatusChip('${t['status'] ?? 'valid'}'),
                      ),
                  ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- vendor profile details

/// What sits behind a vendor's numbers: followers, delivered events, the trust score.
Future<void> showVendorStat(BuildContext context, String vendorUserId, String kind) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VendorStatSheet(id: vendorUserId, kind: kind),
    );

class _VendorStatSheet extends StatelessWidget {
  const _VendorStatSheet({required this.id, required this.kind});
  final String id;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title = const {'followers': 'Followers', 'delivered': 'Delivered events', 'trust': 'How the trust score works'}[kind] ?? kind;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: FutureBuilder<Map<String, dynamic>>(
          future: Api.instance.get('/vendor/profile/$id/$kind'),
          builder: (context, snap) {
            if (snap.hasError) return Padding(padding: const EdgeInsets.all(24), child: Text(Api.messageOf(snap.error!)));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            final data = snap.data!['data'];
            return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (kind == 'trust') ...[
                Text('${_m(data)['score'] ?? 70}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: p.success)),
                Text('${_m(data)['explanation'] ?? ''}', style: TextStyle(color: p.muted, height: 1.5)),
                const SizedBox(height: 12),
                _statGrid([
                  _Stat('${_m(data)['completed'] ?? 0}', 'Completed'),
                  _Stat('${_m(data)['cancelledByVendor'] ?? 0}', 'Cancelled by vendor'),
                  _Stat('${_m(data)['noShows'] ?? 0}', 'No-shows'),
                  _Stat('${_m(data)['lostDisputes'] ?? 0}', 'Disputes lost'),
                  _Stat('${_m(data)['reviews'] ?? 0}', 'Reviews'),
                  _Stat(((_m(data)['averageRating'] as num?) ?? 0).toStringAsFixed(1), 'Average rating'),
                ]),
              ] else if (_l(data).isEmpty)
                Text('Nothing here yet.', style: TextStyle(color: p.muted))
              else
                for (final r in _l(data))
                  kind == 'followers'
                      ? ListTile(contentPadding: EdgeInsets.zero, leading: Avatar(name: '${r['name']}'), title: Text('${r['name']}'), subtitle: Text('Member since ${shortDate(parseDate(r['memberSince']))}'))
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.task_alt_rounded),
                          title: Text('${r['title']}'),
                          subtitle: Text('${shortDate(parseDate(r['date']))} · ${r['location'] ?? ''}'),
                          trailing: r['rating'] == null ? null : Text('${r['rating']} ★'),
                        ),
            ]);
          },
        ),
      ),
    );
  }
}

/// The vendor's reviews with the average and the 1-5 star spread.
class VendorReviewsList extends StatelessWidget {
  const VendorReviewsList({super.key, required this.vendorUserId});
  final String vendorUserId;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: Api.instance.get('/reviews/vendor/$vendorUserId'),
      builder: (context, snap) {
        if (snap.hasError) return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load reviews', message: Api.messageOf(snap.error!));
        if (!snap.hasData) return const LoadingList(count: 3, height: 80);
        final d = _m(snap.data!['data']);
        final sum = _m(d['summary']);
        final dist = _m(sum['distribution']);
        final count = (sum['count'] as num?) ?? 0;
        final reviews = _l(d['reviews']);
        if (count == 0) return const EmptyState(icon: Icons.star_outline_rounded, title: 'No reviews yet', message: 'Organizers review an event once it is delivered.');
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Text(((sum['average'] as num?) ?? 0).toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(children: [
                for (var s = 5; s >= 1; s--)
                  Row(children: [
                    SizedBox(width: 16, child: Text('$s', style: TextStyle(fontSize: 12, color: p.muted))),
                    Expanded(child: LinearProgressIndicator(value: count == 0 ? 0 : (((dist['$s'] as num?) ?? 0) / count), minHeight: 6, borderRadius: BorderRadius.circular(9))),
                  ]),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          for (final r in reviews)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${_m(r['user'])['name'] ?? 'Organizer'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text('★' * ((r['rating'] as num?)?.round() ?? 0), style: const TextStyle(color: Color(0xFFF59E0B))),
                  ]),
                  if (_m(r['event'])['title'] != null) Text('${_m(r['event'])['title']}', style: TextStyle(color: p.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('${r['comment'] ?? ''}'),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
