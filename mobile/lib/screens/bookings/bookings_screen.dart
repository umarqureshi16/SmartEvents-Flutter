import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/socket_service.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Booking>? _all;
  String? _error;
  String _filter = 'open';
  StreamSubscription<LiveEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Any offer or message on one of my bookings refreshes the list.
    _live = SocketService.instance.events.listen((e) {
      if (e.name != 'notification') _load(silent: true);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _error = null);
    final me = context.read<AppState>().user;
    try {
      final res = await Api.instance.get(me?.isVendor == true ? '/bookings/organizer' : '/bookings/my');
      if (!mounted) return;
      setState(() => _all = (res['data'] as List? ?? []).whereType<Map>().map((m) => Booking(Map<String, dynamic>.from(m))).toList());
    } catch (e) {
      if (!silent && mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppState>().user!;
    final all = _all ?? [];
    final groups = {
      'open': all.where((b) => b.isOpen).toList(),
      'agreed': all.where((b) => b.isAgreed).toList(),
      'closed': all.where((b) => b.isClosed).toList(),
    };
    final list = groups[_filter]!;
    final yourTurn = groups['open']!.where((b) => b.myTurn(me.id)).length;

    return Scaffold(
      appBar: AppBar(title: Text(me.isVendor ? 'Offers & bookings' : 'My bookings')),
      body: Column(children: [
        if (_all != null && yourTurn > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('$yourTurn ${yourTurn == 1 ? 'offer is' : 'offers are'} waiting for your answer',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'open', label: Text('Open · ${groups['open']!.length}')),
                ButtonSegment(value: 'agreed', label: Text('Agreed · ${groups['agreed']!.length}')),
                ButtonSegment(value: 'closed', label: Text('Closed · ${groups['closed']!.length}')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _all == null
                  ? const LoadingList(height: 130)
                  : list.isEmpty
                      ? EmptyState(
                          icon: Icons.handshake_outlined,
                          title: _filter == 'open' ? 'No open negotiations' : _filter == 'agreed' ? 'No agreed bookings yet' : 'Nothing closed',
                          message: me.isVendor ? 'Offers from organizers appear here.' : 'Find an event and make an offer to start.',
                          action: me.isVendor ? null : FilledButton(onPressed: () => context.go('/'), child: const Text('Explore events')),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _BookingCard(list[i], myId: me.id, onReturn: () => _load(silent: true)),
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard(this.b, {required this.myId, required this.onReturn});
  final Booking b;
  final String myId;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final turn = b.myTurn(myId);
    final other = b.otherName(myId);
    final last = b.history.isNotEmpty ? b.history.last : null;
    final lastChat = b.chat.isNotEmpty ? b.chat.last : null;
    final preview = (lastChat != null && (last?.at == null || (lastChat.at?.isAfter(last!.at!) ?? false)))
        ? lastChat.text
        : (last?.message.isNotEmpty == true ? last!.message : 'Offer of ${money(b.offerPrice)}');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/negotiate/${b.id}');
          onReturn();
        },
        child: Container(
          decoration: turn ? BoxDecoration(border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4))) : null,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(name: other, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text('with $other', style: TextStyle(color: p.muted, fontSize: 13)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(b.offerPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 4),
                turn ? const StatusChip('pending', label: 'your turn') : StatusChip(b.status, label: b.isOpen ? 'waiting' : null),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: p.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted))),
              if (b.eventDate != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.event_rounded, size: 15, color: p.muted),
                const SizedBox(width: 4),
                Text(shortDate(b.eventDate), style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
