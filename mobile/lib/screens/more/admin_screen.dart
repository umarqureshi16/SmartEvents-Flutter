import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'super_admin.dart';

/// The admin panel: platform numbers, people (restrict, verify vendors,
/// change roles) and disputes to settle, like the website's Admin panel.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Admin'),
            bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(text: 'Numbers'),
              Tab(text: 'Business'),
              Tab(text: 'People'),
              Tab(text: 'Bookings'),
              Tab(text: 'Disputes'),
              Tab(text: 'Activity'),
            ]),
          ),
          body: const TabBarView(children: [_Overview(), AdminOverviewTab(), _People(), AdminBookingsTab(), _Disputes(), AuditLogTab(path: '/admin/audit-logs')]),
        ),
      );
}

class _Overview extends StatefulWidget {
  const _Overview();
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/admin/stats');
      setState(() {
        _stats = Map<String, dynamic>.from(res['data'] as Map);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final s = _stats;
    if (s == null) return const LoadingList(count: 3, height: 90);
    final p = AppPalette.of(context);
    Widget tile(String label, String value, IconData icon, Color c) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(backgroundColor: c.withValues(alpha: 0.14), child: Icon(icon, color: c)),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(color: p.muted, fontWeight: FontWeight.w600))),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
          ),
        );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        tile('People', '${s['totalUsers'] ?? 0}', Icons.groups_rounded, Theme.of(context).colorScheme.primary),
        tile('Event listings', '${s['totalEvents'] ?? 0}', Icons.event_rounded, const Color(0xFF0EA5E9)),
        tile('Bookings', '${s['totalBookings'] ?? 0}', Icons.receipt_long_rounded, p.warning),
        tile('Confirmed bookings', '${s['confirmedBookings'] ?? 0}', Icons.handshake_rounded, p.success),
        tile('Booking value', money(s['totalRevenue'] as num?), Icons.payments_rounded, p.success),
      ]),
    );
  }
}

class _People extends StatefulWidget {
  const _People();
  @override
  State<_People> createState() => _PeopleState();
}

class _PeopleState extends State<_People> {
  List<Map<String, dynamic>>? _users;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/admin/users', query: {if (_search.isNotEmpty) 'search': _search});
      setState(() {
        _users = (res['data'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _do(Future<Map<String, dynamic>> Function() call, String ok) async {
    try {
      final res = await call();
      if (mounted) showMessage(context, res['message'] as String? ?? ok);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  Future<void> _menu(Map<String, dynamic> u, String action) async {
    final id = idOf(u)!;
    final name = '${u['name']}';
    switch (action) {
      case 'status':
        final active = '${u['status'] ?? 'active'}'.toLowerCase() == 'active';
        if (!await confirmDialog(context,
            title: active ? 'Restrict $name?' : 'Restore $name?',
            message: active ? 'They will not be able to use their account until restored.' : 'Their account works again.',
            confirm: active ? 'Restrict' : 'Restore',
            danger: active)) {
          return;
        }
        await _do(() => Api.instance.put('/admin/users/$id/ban', {'status': active ? 'restricted' : 'active'}), 'Status updated.');
      case 'verify':
        final verified = (u['businessDetails'] as Map?)?['verified'] == true;
        await _do(() => Api.instance.put('/admin/users/$id/verify', {'verified': !verified}), verified ? 'Verification revoked.' : 'Vendor verified.');
      default:
        if (!await confirmDialog(context, title: 'Make $name ${titleCase(action)}?', message: 'This changes what they can do on SmartEvents.', confirm: 'Change role')) return;
        await _do(() => Api.instance.put('/admin/users/$id/role', {'role': action}), '$name is now ${titleCase(action)}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search by name or email'),
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _search = v.trim();
            _load();
          },
        ),
      ),
      Expanded(
        child: _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _users == null
                ? const LoadingList(count: 5, height: 70)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _users!.length,
                      itemBuilder: (_, i) {
                        final u = _users![i];
                        final role = '${u['role']}';
                        final status = '${u['status'] ?? 'active'}';
                        final verified = (u['businessDetails'] as Map?)?['verified'] == true;
                        return Card(
                          child: ListTile(
                            leading: Avatar(name: '${u['name']}'),
                            title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${u['email']}\n${titleCase(role)}${role == 'provider' ? (verified ? ' · verified' : ' · not verified') : ''}', style: TextStyle(color: p.muted)),
                            isThreeLine: true,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              StatusChip(status),
                              PopupMenuButton<String>(
                                onSelected: (a) => _menu(u, a),
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'status', child: Text(status.toLowerCase() == 'active' ? 'Restrict account' : 'Restore account')),
                                  if (role == 'provider') PopupMenuItem(value: 'verify', child: Text(verified ? 'Revoke verification' : 'Verify vendor')),
                                  for (final r in const ['customer', 'provider', 'admin'])
                                    if (r != role) PopupMenuItem(value: r, child: Text('Make ${titleCase(r == 'customer' ? 'organizer' : r == 'provider' ? 'vendor' : r)}')),
                                ],
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

class _Disputes extends StatefulWidget {
  const _Disputes();
  @override
  State<_Disputes> createState() => _DisputesState();
}

class _DisputesState extends State<_Disputes> {
  List<Booking>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/admin/disputes');
      setState(() {
        _items = (res['data'] as List? ?? []).whereType<Map>().map((e) => Booking(Map<String, dynamic>.from(e))).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _resolve(Booking b, String resolution) async {
    final refund = resolution == 'refunded_customer';
    if (!await confirmDialog(context,
        title: refund ? 'Refund the organizer?' : 'Pay the vendor?',
        message: '${money(b.offerPrice)} held in escrow goes to ${refund ? b.customerName : b.vendorName}. This cannot be undone.',
        confirm: refund ? 'Refund' : 'Release payment')) {
      return;
    }
    try {
      await Api.instance.put('/admin/bookings/${b.id}/resolve-dispute', {'resolution': resolution});
      if (mounted) showMessage(context, 'Dispute resolved. Escrow settled.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final items = _items;
    if (items == null) return const LoadingList(count: 3, height: 120);
    if (items.isEmpty) return const EmptyState(icon: Icons.gavel_rounded, title: 'No open disputes', message: 'Problems reported on bookings show up here.');
    final p = AppPalette.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final b in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  Text(money(b.offerPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 4),
                Text('${b.customerName} (organizer) · ${b.vendorName} (vendor)', style: TextStyle(color: p.muted, fontSize: 12.5)),
                if (b.history.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(b.history.last.message, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _resolve(b, 'refunded_customer'), child: const Text('Refund organizer'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: () => _resolve(b, 'released_vendor'), child: const Text('Pay vendor'))),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}
