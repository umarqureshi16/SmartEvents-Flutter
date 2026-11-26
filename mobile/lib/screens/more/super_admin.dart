import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

/// Loads one GET endpoint and shows it, with pull to refresh.
class ApiView extends StatefulWidget {
  const ApiView({super.key, required this.path, required this.builder, this.query});
  final String path;
  final Map<String, dynamic>? query;
  final Widget Function(BuildContext context, dynamic data, Future<void> Function() reload) builder;
  @override
  State<ApiView> createState() => _ApiViewState();
}

class _ApiViewState extends State<ApiView> {
  dynamic _data;
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ApiView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.query.toString() != widget.query.toString()) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get(widget.path, query: widget.query);
      if (mounted) {
        setState(() {
          _data = r['data'];
          _error = null;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (!_loaded) return const LoadingList(count: 4, height: 80);
    return RefreshIndicator(onRefresh: _load, child: widget.builder(context, _data, _load));
  }
}

class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.icon, this.color});
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) Icon(icon, color: color ?? Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(height: 6),
          FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
        ]),
      ),
    );
  }
}

Widget tileGrid(List<Widget> tiles) => LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 500 ? 3 : 2;
      final w = (box.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });

/// Simple bar chart for month series ([{label, value}]).
class MonthBars extends StatelessWidget {
  const MonthBars(this.points, {super.key, this.format});
  final List<(String, num)> points;
  final String Function(num)? format;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final max = points.fold<num>(0, (m, e) => e.$2 > m ? e.$2 : m);
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (label, v) in points)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (v > 0) FittedBox(child: Text(format?.call(v) ?? '$v', style: TextStyle(fontSize: 10, color: p.muted))),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: max == 0 ? 4 : 4 + 96 * (v / max),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 11, color: p.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}

String _monthLabel(String ym) {
  final d = DateTime.tryParse('$ym-01');
  return d == null ? ym : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];
}

// ---------------------------------------------------------------- admin: business overview

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) => ApiView(
        path: '/admin/overview',
        builder: (context, data, _) {
          final d = _m(data);
          final acc = _m(d['accounts']);
          final bk = _m(d['bookings']);
          final rev = _m(d['revenue']);
          final p = AppPalette.of(context);
          return ListView(padding: const EdgeInsets.all(16), children: [
            tileGrid([
              StatTile('Accounts', '${acc['total'] ?? 0}', icon: Icons.groups_rounded),
              StatTile('Suspended', '${acc['suspended'] ?? 0}', icon: Icons.block_rounded, color: AppColors.danger),
              StatTile('Bookings', '${bk['total'] ?? 0}', icon: Icons.receipt_long_rounded),
              StatTile('Open', '${bk['open'] ?? 0}', icon: Icons.handshake_rounded, color: p.warning),
              StatTile('Gross value', money(rev['gross'] as num?), icon: Icons.payments_rounded, color: p.success),
              StatTile('In escrow', money(rev['heldInEscrow'] as num?), icon: Icons.lock_clock_rounded, color: p.warning),
              StatTile('Released', money(rev['released'] as num?), icon: Icons.account_balance_wallet_rounded, color: p.success),
              StatTile('Platform fee (${(((rev['feeRate'] as num?) ?? 0) * 100).toStringAsFixed(1)}%)', money(rev['platformFee'] as num?), icon: Icons.percent_rounded),
            ]),
            const SectionTitle('Revenue by month'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: MonthBars([for (final m in _l(rev['byMonth'])) (_monthLabel('${m['month']}'), (m['value'] as num?) ?? 0)], format: (v) => money(v)),
              ),
            ),
            const SectionTitle('New accounts by month'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: MonthBars([for (final m in _l(acc['signupsByMonth'])) (_monthLabel('${m['month']}'), (m['count'] as num?) ?? 0)]),
              ),
            ),
            const SectionTitle('Accounts by role'),
            Card(
              child: Column(children: [
                for (final e in _m(acc['byRole']).entries)
                  ListTile(dense: true, title: Text(titleCase(e.key == 'customer' ? 'organizer' : e.key == 'provider' ? 'vendor' : e.key)), trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
            const SectionTitle('Bookings by status'),
            Card(
              child: Column(children: [
                for (final e in _m(bk['byStatus']).entries)
                  ListTile(dense: true, title: Text(titleCase(e.key)), trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
            if (_l(rev['topVendors']).isNotEmpty) ...[
              const SectionTitle('Top vendors'),
              for (final v in _l(rev['topVendors']))
                Card(
                  child: ListTile(
                    title: Text('${v['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${titleCase('${v['category'] ?? ''}')} · ${v['deals']} deal${v['deals'] == 1 ? '' : 's'}'),
                    trailing: Text(money(v['value'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
            if (_l(rev['byField']).isNotEmpty) ...[
              const SectionTitle('Value by field'),
              Card(
                child: Column(children: [
                  for (final f in _l(rev['byField']))
                    ListTile(dense: true, title: Text(titleCase('${f['field']}')), trailing: Text(money(f['value'] as num?), style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
              ),
            ],
          ]);
        },
      );
}

class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({super.key});
  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  String _status = 'all';
  String _q = '';
  int _page = 1;

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search bookings'),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() {
              _q = v.trim();
              _page = 1;
            }),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final s in const ['all', 'open', 'confirmed', 'completed', 'disputed', 'cancelled', 'rejected'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(titleCase(s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() {
                    _status = s;
                    _page = 1;
                  }),
                ),
              ),
          ]),
        ),
        Expanded(
          child: ApiView(
            path: '/admin/bookings',
            query: {'status': _status, if (_q.isNotEmpty) 'q': _q, 'page': _page},
            builder: (context, data, _) {
              final d = _m(data);
              final items = _l(d['items']);
              final pages = (d['pages'] as num?)?.toInt() ?? 1;
              if (items.isEmpty) return ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.receipt_long_outlined, title: 'No bookings here')]);
              return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
                for (final b in items)
                  Card(
                    child: ListTile(
                      onTap: () => context.push('/negotiate/${idOf(b)}'),
                      title: Text('${b['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${b['organizer']} → ${b['vendor']}\n${shortDate(parseDate(b['date']))} · escrow ${b['escrow']}'),
                      isThreeLine: true,
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(money(b['price'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                        StatusChip('${b['status']}'),
                      ]),
                    ),
                  ),
                if (pages > 1)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(onPressed: _page > 1 ? () => setState(() => _page--) : null, icon: const Icon(Icons.chevron_left_rounded)),
                    Text('Page $_page of $pages'),
                    IconButton(onPressed: _page < pages ? () => setState(() => _page++) : null, icon: const Icon(Icons.chevron_right_rounded)),
                  ]),
              ]);
            },
          ),
        ),
      ]);
}

/// Audit log (admin: /admin/audit-logs, super admin: /super-admin/logs).
class AuditLogTab extends StatelessWidget {
  const AuditLogTab({super.key, this.path = '/admin/audit-logs'});
  final String path;

  @override
  Widget build(BuildContext context) => ApiView(
        path: path,
        builder: (context, data, _) {
          final logs = _l(data);
          final p = AppPalette.of(context);
          if (logs.isEmpty) return ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.history_rounded, title: 'No activity recorded yet')]);
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final l in logs)
              Card(
                child: ListTile(
                  leading: Icon(
                    l['severity'] == 'critical' ? Icons.warning_amber_rounded : (l['severity'] == 'warning' ? Icons.error_outline_rounded : Icons.info_outline_rounded),
                    color: l['severity'] == 'critical' ? AppColors.danger : (l['severity'] == 'warning' ? p.warning : p.muted),
                  ),
                  title: Text('${l['action'] ?? 'ACTION'}'.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  subtitle: Text('${_m(l['actor'])['name'] ?? _m(l['actor'])['email'] ?? 'System'} · ${l['targetType'] ?? ''}\n${timeAgo(parseDate(l['createdAt']))}'),
                  isThreeLine: true,
                ),
              ),
          ]);
        },
      );
}

// ---------------------------------------------------------------- super admin console

class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Super admin'),
            bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(text: 'Health'),
              Tab(text: 'Risk'),
              Tab(text: 'Vendors'),
              Tab(text: 'Disputes'),
              Tab(text: 'Logs'),
              Tab(text: 'Signup code'),
            ]),
          ),
          body: const TabBarView(children: [
            _Health(),
            _Risk(),
            _Providers(),
            _SaDisputes(),
            AuditLogTab(path: '/super-admin/logs'),
            _SignupCode(),
          ]),
        ),
      );
}

class _Health extends StatelessWidget {
  const _Health();
  @override
  Widget build(BuildContext context) => ApiView(
        path: '/super-admin/stats',
        builder: (context, data, _) {
          final s = _m(data);
          final p = AppPalette.of(context);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.monitor_heart_rounded, color: s['health'] == 'Healthy' ? p.success : p.warning),
                title: Text('Platform: ${s['health'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            tileGrid([
              StatTile('People', '${s['totalUsers'] ?? 0}', icon: Icons.groups_rounded),
              StatTile('Vendors', '${s['providers'] ?? 0}', icon: Icons.storefront_rounded),
              StatTile('Organizers', '${s['customers'] ?? 0}', icon: Icons.event_available_rounded),
              StatTile('Active bookings', '${s['activeBookings'] ?? 0}', icon: Icons.handshake_rounded),
              StatTile('Revenue', money(s['revenue'] as num?), icon: Icons.payments_rounded, color: p.success),
              StatTile('Closed deals', '${s['closedDeals'] ?? 0}', icon: Icons.task_alt_rounded),
              StatTile('Average deal', money(s['averageDealValue'] as num?), icon: Icons.analytics_rounded),
              StatTile('Disputes', '${s['disputes'] ?? 0}', icon: Icons.gavel_rounded, color: p.warning),
              StatTile('Banned', '${s['bannedUsers'] ?? 0}', icon: Icons.block_rounded, color: AppColors.danger),
            ]),
            const SectionTitle('Revenue and bookings'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: Api.instance.get('/super-admin/revenue-series'),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                    final rows = _l(snap.data!['data']);
                    return Column(children: [
                      MonthBars([for (final r in rows) ('${r['name']}', (r['revenue'] as num?) ?? 0)], format: (v) => money(v)),
                      const SizedBox(height: 10),
                      Text('Bookings: ${rows.map((r) => '${r['name']} ${r['bookings']}').join(' · ')}', style: TextStyle(fontSize: 11, color: p.muted)),
                    ]);
                  },
                ),
              ),
            ),
          ]);
        },
      );
}

class _Risk extends StatelessWidget {
  const _Risk();

  Future<void> _act(BuildContext context, Map<String, dynamic> u, String action, Future<void> Function() reload) async {
    final name = '${u['name']}';
    final words = const {'ban': 'Ban', 'restrict': 'Restrict', 'reinstate': 'Reinstate'}[action]!;
    if (!await confirmDialog(context,
        title: '$words $name?',
        message: action == 'reinstate' ? 'Their account works normally again.' : 'They lose access until reinstated.',
        confirm: words,
        danger: action != 'reinstate')) {
      return;
    }
    try {
      final r = await Api.instance.post('/super-admin/user-governance', {'userId': u['userId'] ?? idOf(u), 'action': action});
      if (context.mounted) showMessage(context, r['message'] as String? ?? '$name updated.');
      await reload();
    } catch (e) {
      if (context.mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ApiView(
        path: '/super-admin/fraud-risks',
        builder: (context, data, reload) {
          final rows = _l(data);
          final p = AppPalette.of(context);
          if (rows.isEmpty) return ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.shield_rounded, title: 'No vendors to assess yet')]);
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final u in rows)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (u['classification'] == 'HIGH' ? AppColors.danger : u['classification'] == 'MEDIUM' ? p.warning : p.success).withValues(alpha: 0.15),
                    child: Text('${u['score'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${u['email']}\nRisk ${u['classification']} · trust ${u['trustScore']} · ${u['status']}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) => _act(context, u, a, reload),
                    itemBuilder: (_) => [
                      if (u['status'] != 'active') const PopupMenuItem(value: 'reinstate', child: Text('Reinstate')),
                      if (u['status'] != 'restricted') const PopupMenuItem(value: 'restrict', child: Text('Restrict')),
                      if (u['status'] != 'banned') const PopupMenuItem(value: 'ban', child: Text('Ban')),
                    ],
                  ),
                ),
              ),
          ]);
        },
      );
}

class _Providers extends StatelessWidget {
  const _Providers();
  @override
  Widget build(BuildContext context) => ApiView(
        path: '/super-admin/providers',
        builder: (context, data, _) {
          final rows = _l(data);
          if (rows.isEmpty) return ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.storefront_outlined, title: 'No vendors yet')]);
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final v in rows)
              Card(
                child: ListTile(
                  onTap: () => context.push('/vendor/${idOf(v)}'),
                  leading: Avatar(name: '${v['name']}'),
                  title: Text('${v['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${v['email']}\n${_m(v['analytics'])['totalBookings'] ?? 0} bookings · ${_m(v['analytics'])['completedEvents'] ?? 0} delivered · trust ${v['trustScore']}'),
                  isThreeLine: true,
                  trailing: StatusChip('${v['status'] ?? 'active'}'),
                ),
              ),
          ]);
        },
      );
}

class _SaDisputes extends StatelessWidget {
  const _SaDisputes();

  Future<void> _resolve(BuildContext context, Booking b, String resolution, Future<void> Function() reload) async {
    final refund = resolution == 'refunded_customer';
    if (!await confirmDialog(context,
        title: refund ? 'Refund the organizer?' : 'Pay the vendor?',
        message: '${money(b.offerPrice)} held in escrow goes to ${refund ? b.customerName : b.vendorName}. This cannot be undone.',
        confirm: refund ? 'Refund' : 'Release payment')) {
      return;
    }
    try {
      await Api.instance.put('/admin/bookings/${b.id}/resolve-dispute', {'resolution': resolution});
      if (context.mounted) showMessage(context, 'Dispute resolved. Escrow settled.');
      await reload();
    } catch (e) {
      if (context.mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ApiView(
        path: '/super-admin/disputes',
        builder: (context, data, reload) {
          final rows = _l(data).map(Booking.new).toList();
          if (rows.isEmpty) return ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.gavel_rounded, title: 'No open disputes')]);
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final b in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      Text(money(b.offerPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ]),
                    Text('${b.customerName} (organizer) · ${b.vendorName} (vendor)', style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12.5)),
                    if (b.history.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(b.history.last.message, style: const TextStyle(fontStyle: FontStyle.italic))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => _resolve(context, b, 'refunded_customer', reload), child: const Text('Refund organizer'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(onPressed: () => _resolve(context, b, 'released_vendor', reload), child: const Text('Pay vendor'))),
                    ]),
                  ]),
                ),
              ),
          ]);
        },
      );
}

/// The admin signup code: whether it is on, and changing it (8-100 characters).
class _SignupCode extends StatefulWidget {
  const _SignupCode();
  @override
  State<_SignupCode> createState() => _SignupCodeState();
}

class _SignupCodeState extends State<_SignupCode> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  Key _key = UniqueKey();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.put('/super-admin/signup-code', {'code': _code.text.trim()});
      _code.clear();
      _confirm.clear();
      if (mounted) {
        showMessage(context, 'Admin signup code updated. Share it only with people who should become admins.');
        setState(() => _key = UniqueKey());
      }
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 90,
          child: ApiView(
            key: _key,
            path: '/super-admin/signup-code',
            builder: (context, data, _) {
              final d = _m(data);
              return ListView(physics: const NeverScrollableScrollPhysics(), children: [
                Card(
                  child: ListTile(
                    leading: Icon(d['enabled'] == true ? Icons.lock_open_rounded : Icons.lock_rounded),
                    title: Text(d['enabled'] == true ? 'Admin signup is on' : 'Admin signup is off', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Set ${d['source'] == 'environment' ? 'on the server' : 'here'}${d['updatedAt'] != null ? ' · changed ${timeAgo(parseDate(d['updatedAt']))}' : ''}'),
                  ),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 8),
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Set a new admin signup code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _code,
              obscureText: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'New code', counterText: ''),
              validator: (v) {
                final s = (v ?? '').trim();
                return s.length < 8 || s.length > 100 ? 'The signup code must be between 8 and 100 characters.' : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Type it again'),
              validator: (v) => (v ?? '').trim() == _code.text.trim() ? null : 'The codes do not match',
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Change code')),
          ]),
        ),
      ]);
}
