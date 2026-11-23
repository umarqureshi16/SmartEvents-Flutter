import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/notifications');
      final list = (res['data'] as List? ?? []).whereType<Map>().map((m) => AppNotification(Map<String, dynamic>.from(m))).toList();
      setState(() => _items = list);
      if (mounted) context.read<AppState>().setUnread(list.where((n) => !n.read).length);
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _readAll() async {
    try {
      await Api.instance.put('/notifications/read-all');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      Api.instance.put('/notifications/${n.id}/read').catchError((_) => <String, dynamic>{});
    }
    if (n.type == 'booking' && n.relatedId != null) {
      await context.push('/negotiate/${n.relatedId}');
    } else if (n.type == 'ticket') {
      await context.push('/tickets');
    }
    _load();
  }

  IconData _icon(String type) => switch (type) {
        'booking' => Icons.handshake_rounded,
        'ticket' => Icons.qr_code_2_rounded,
        'payment' => Icons.account_balance_wallet_rounded,
        'review' => Icons.star_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasUnread = _items?.any((n) => !n.read) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (hasUnread) TextButton(onPressed: _readAll, child: const Text('Mark all read'))],
      ),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _items == null
              ? const LoadingList(height: 76)
              : _items!.isEmpty
                  ? const EmptyState(icon: Icons.notifications_off_outlined, title: 'You are all caught up')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items!.length,
                        separatorBuilder: (_, _) => const Divider(indent: 72),
                        itemBuilder: (_, i) {
                          final n = _items![i];
                          final brand = Theme.of(context).colorScheme.primary;
                          return ListTile(
                            onTap: () => _open(n),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: brand.withValues(alpha: n.read ? 0.06 : 0.14),
                              child: Icon(_icon(n.type), color: n.read ? p.muted : brand, size: 20),
                            ),
                            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800)),
                            subtitle: Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(timeAgo(n.at), style: TextStyle(fontSize: 11.5, color: p.muted)),
                              if (!n.read) ...[const SizedBox(height: 6), CircleAvatar(radius: 4, backgroundColor: brand)],
                            ]),
                          );
                        },
                      ),
                    ),
    );
  }
}
