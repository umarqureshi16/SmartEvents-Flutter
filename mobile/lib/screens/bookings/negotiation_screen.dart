import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/firebase_service.dart';
import '../../core/format.dart';
import '../../core/socket_service.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

const _quick = {
  'customer': ['Is this date available?', 'What exactly is included?', 'Can you share photos of past setups?', 'Is there any flexibility on price?'],
  'vendor': ['Yes, the date is available.', 'Everything in the package is included.', 'I can share photos of past setups.', 'This is my best price for the date.'],
};

/// One item in the conversation: an offer or a chat message.
class _Item {
  _Item.offer(this.offer) : chat = null;
  _Item.chat(this.chat) : offer = null;
  final OfferEntry? offer;
  final ChatMessage? chat;
  DateTime get at => offer?.at ?? chat?.at ?? DateTime.now();
  String? get by => offer?.by ?? chat?.by;
}

class NegotiationScreen extends StatefulWidget {
  const NegotiationScreen({super.key, required this.id});
  final String id;
  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  Booking? _b;
  String? _error;
  bool _busy = false;
  bool _sending = false;
  bool _dealOpen = true;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<LiveEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    SocketService.instance.joinBooking(widget.id);
    _live = SocketService.instance.events.listen(_onLive);
  }

  @override
  void dispose() {
    _live?.cancel();
    SocketService.instance.leaveBooking(widget.id);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _me => context.read<AppState>().user!.id;

  void _onLive(LiveEvent e) {
    final d = e.data;
    final actor = idOf(d['actorId'] ?? d['offeredBy']);
    if (actor == _me) return;
    if (d['bookingId'] != null && idOf(d['bookingId']) != widget.id) return;
    switch (e.name) {
      case 'negotiation-message':
        final m = d['message'];
        if (m is Map && _b != null && !_b!.chat.any((c) => c.id == idOf(m))) {
          final raw = Map<String, dynamic>.from(_b!.raw);
          raw['chatMessages'] = [...(raw['chatMessages'] as List? ?? []), Map<String, dynamic>.from(m)];
          setState(() => _b = Booking(raw));
          _toBottom();
        }
      case 'offer-countered':
        _toast('New offer: ${money(d['price'] as num?)}');
        _load();
      case 'offer-revised':
        _toast('Offer changed to ${money(d['price'] as num?)}');
        _load();
      case 'offer-accepted':
        _toast('The offer was accepted');
        _load();
      case 'offer-rejected':
        _toast('The offer was declined');
        _load();
    }
  }

  void _toast(String t) {
    if (mounted) showMessage(context, t);
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/bookings/${widget.id}');
      if (!mounted) return;
      setState(() {
        _b = Booking(Map<String, dynamic>.from(res['data'] as Map));
        _error = null;
      });
      _toBottom();
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _act(Future<void> Function() fn, String ok) async {
    setState(() => _busy = true);
    try {
      await fn();
      _toast(ok);
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final b = _b!;
    if (!await confirmDialog(context,
        title: 'Accept ${money(b.offerPrice)}?',
        message: 'The booking is confirmed at this price and the amount is held in escrow until the event is delivered.',
        confirm: 'Accept offer')) {
      return;
    }
    await _act(() async {
      await Api.instance.put('/bookings/${b.id}/accept');
      FirebaseService.instance.logEvent('accept_offer', {'value': b.offerPrice});
    }, 'Offer accepted. The booking is confirmed.');
  }

  Future<void> _decline() async {
    if (!await confirmDialog(context,
        title: 'Decline this offer?', message: 'This closes the negotiation. You can still send messages.', confirm: 'Decline', danger: true)) {
      return;
    }
    await _act(() => Api.instance.put('/bookings/${widget.id}/reject'), 'Offer declined.');
  }

  Future<void> _priceSheet({required bool revise}) async {
    final b = _b!;
    final last = b.history.isNotEmpty ? b.history.last : null;
    final result = await showModalBottomSheet<(num, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PriceSheet(
        title: revise ? 'Change your offer' : 'Counter-offer',
        subtitle: revise
            ? 'You offered ${money(last?.price)}. ${b.otherName(_me)} sees the new price straight away.'
            : '${b.otherName(_me)} offered ${money(b.offerPrice)}. Listed at ${money(b.listedPrice)}.',
        initial: revise ? (last?.price ?? b.offerPrice) : b.offerPrice,
        initialNote: revise ? (last?.message ?? '') : '',
        listed: b.listedPrice,
        cta: revise ? 'Save offer' : 'Send counter-offer',
      ),
    );
    if (result == null) return;
    final (price, note) = result;
    await _act(() async {
      if (revise) {
        await Api.instance.put('/bookings/${b.id}/offer', {'price': price, if (note.isNotEmpty) 'message': note});
      } else {
        await Api.instance.post('/bookings/${b.id}/negotiate', {'price': price, if (note.isNotEmpty) 'message': note});
      }
      FirebaseService.instance.logEvent(revise ? 'revise_offer' : 'counter_offer', {'value': price});
    }, revise ? 'Your offer was updated.' : 'Counter-offer sent.');
  }

  Future<void> _send([String? quick]) async {
    final text = (quick ?? _text.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await Api.instance.post('/bookings/${widget.id}/messages', {'text': text});
      final raw = Map<String, dynamic>.from(_b!.raw);
      raw['chatMessages'] = [...(raw['chatMessages'] as List? ?? []), Map<String, dynamic>.from(res['data'] as Map)];
      setState(() => _b = Booking(raw));
      if (quick == null) _text.clear();
      _toBottom();
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _b == null) return Scaffold(appBar: AppBar(), body: ErrorState(message: _error!, onRetry: _load));
    final b = _b;
    if (b == null) return Scaffold(appBar: AppBar(), body: const LoadingList(count: 4, height: 90));
    final me = context.watch<AppState>().user!;
    final p = AppPalette.of(context);
    final other = b.otherName(me.id);
    final items = [
      ...b.history.map(_Item.offer),
      ...b.chat.map(_Item.chat),
    ]..sort((a, c) => a.at.compareTo(c.at));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(name: other, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(other, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: _dealOpen ? 'Hide deal' : 'Show deal',
            onPressed: () => setState(() => _dealOpen = !_dealOpen),
            icon: Icon(_dealOpen ? Icons.expand_less_rounded : Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: Column(children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _dealOpen ? _DealPanel(b: b, me: me.id, busy: _busy, onAccept: _accept, onDecline: _decline, onCounter: () => _priceSheet(revise: false), onRevise: () => _priceSheet(revise: true)) : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(icon: Icons.forum_outlined, title: 'No messages yet', message: 'Say hello or ask a question below.')
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final prev = i > 0 ? items[i - 1] : null;
                    final newDay = prev == null || dayLabel(prev.at) != dayLabel(it.at);
                    final mine = it.by == me.id;
                    final name = mine ? 'You' : (it.by == b.customerId ? b.customerName : b.vendorName);
                    return Column(children: [
                      if (newDay) _DayDivider(dayLabel(it.at)),
                      if (it.offer != null)
                        it.offer!.isFinal ? _FinalPill(it.offer!, name) : _OfferBubble(it.offer!, mine: mine, name: name)
                      else
                        _ChatBubble(it.chat!, mine: mine),
                    ]).animate().fadeIn(duration: 200.ms);
                  },
                ),
        ),
        _Composer(
          controller: _text,
          sending: _sending,
          quick: _quick[me.isVendor ? 'vendor' : 'customer']!,
          onSend: _send,
          onOffer: b.isOpen && b.myTurn(me.id) ? () => _priceSheet(revise: false) : null,
          hint: 'Message $other…',
        ),
      ]),
    );
  }
}

class _DealPanel extends StatelessWidget {
  const _DealPanel({required this.b, required this.me, required this.busy, required this.onAccept, required this.onDecline, required this.onCounter, required this.onRevise});
  final Booking b;
  final String me;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;
  final VoidCallback onRevise;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final brand = Theme.of(context).colorScheme.primary;
    final turn = b.myTurn(me);
    final offers = b.history.where((h) => !h.isFinal).toList();
    final last = b.history.isNotEmpty ? b.history.last : null;
    final diff = b.listedPrice > 0 ? ((b.offerPrice - b.listedPrice) / b.listedPrice * 100).round() : 0;
    final other = b.otherName(me);

    final (IconData icon, String text, Color color) = b.isAgreed
        ? (Icons.handshake_rounded, 'Deal agreed. Escrow holds the amount until delivery.', p.success)
        : !b.isOpen
            ? (Icons.cancel_rounded, 'This negotiation was ${b.status}.', AppColors.danger)
            : turn
                ? (Icons.touch_app_rounded, 'Your turn: accept, decline or counter.', brand)
                : (Icons.hourglass_top_rounded, 'Waiting for $other. You can change your offer or chat.', p.muted);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.isAgreed ? 'AGREED PRICE' : 'OFFER ON THE TABLE', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w900, color: p.muted)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: b.offerPrice.toDouble()),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, _) => Text(money(v), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: p.success, letterSpacing: -1)),
              ),
              Text(
                '${last != null && b.isOpen ? 'by ${last.by == me ? 'You' : other} · ' : ''}listed at ${money(b.listedPrice)}',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ]),
          ),
          if (diff != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (diff < 0 ? p.success : p.warning).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(diff < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded, size: 14, color: diff < 0 ? p.success : p.warning),
                const SizedBox(width: 3),
                Text('${diff.abs()}%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: diff < 0 ? p.success : p.warning)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
        ),
        if (offers.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: offers.length,
              separatorBuilder: (_, _) => Icon(Icons.chevron_right_rounded, size: 16, color: p.muted),
              itemBuilder: (_, i) {
                final o = offers[i];
                final lastOne = i == offers.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: lastOne ? brand : p.surface2, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${o.by == me ? 'You' : other.split(' ').first} ${money(o.price)}${o.editedAt != null ? ' ✎' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: lastOne ? Colors.white : p.muted),
                  ),
                );
              },
            ),
          ),
        ],
        if (b.isOpen) ...[
          const SizedBox(height: 14),
          if (turn)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.check_rounded),
                label: Text('Accept ${money(b.offerPrice)}'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onCounter,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    label: const Text('Counter'),
                  ),
                ),
              ]),
            ])
          else if (last != null)
            OutlinedButton.icon(
              onPressed: busy ? null : onRevise,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Change my offer'),
            ),
        ],
      ]),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Divider(color: p.border)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800, color: p.muted))),
        Expanded(child: Divider(color: p.border)),
      ]),
    );
  }
}

class _FinalPill extends StatelessWidget {
  const _FinalPill(this.o, this.name);
  final OfferEntry o;
  final String name;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final ok = o.action == 'accepted';
    final c = ok ? p.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: c),
          const SizedBox(width: 6),
          Text('$name ${ok ? 'accepted' : 'declined'} ${money(o.price)} · ${timeLabel(o.at)}', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

class _OfferBubble extends StatelessWidget {
  const _OfferBubble(this.o, {required this.mine, required this.name});
  final OfferEntry o;
  final bool mine;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final brand = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 6),
            bottomRight: Radius.circular(mine ? 6 : 20),
          ),
          border: Border.all(color: mine ? brand.withValues(alpha: 0.45) : p.border),
        ),
        clipBehavior: Clip.antiAlias,
        width: MediaQuery.of(context).size.width * 0.74,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(
            color: mine ? brand : p.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sell_rounded, size: 13, color: mine ? Colors.white : p.muted),
              const SizedBox(width: 6),
              Text(o.action == 'offer' ? 'OPENING OFFER' : 'COUNTER-OFFER', style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w900, color: mine ? Colors.white : p.muted)),
              const SizedBox(width: 14),
              Text(name.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w900, color: mine ? Colors.white70 : p.muted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(money(o.price), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              if (o.previousPrice != null && o.previousPrice != o.price)
                Text.rich(TextSpan(children: [
                  TextSpan(text: money(o.previousPrice), style: const TextStyle(decoration: TextDecoration.lineThrough)),
                  TextSpan(text: ' · changed ${timeLabel(o.editedAt)}'),
                ]), style: TextStyle(fontSize: 12, color: p.muted)),
              if (o.message.isNotEmpty) ...[const SizedBox(height: 4), Text(o.message, style: const TextStyle(height: 1.4))],
              const SizedBox(height: 4),
              Text(timeLabel(o.at), style: TextStyle(fontSize: 10.5, color: p.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble(this.m, {required this.mine});
  final ChatMessage m;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final brand = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? brand : Theme.of(context).colorScheme.surface,
          border: mine ? null : Border.all(color: p.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 6),
            bottomRight: Radius.circular(mine ? 6 : 20),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(m.text, style: TextStyle(color: mine ? Colors.white : null, height: 1.35)),
          const SizedBox(height: 3),
          Text(timeLabel(m.at), style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : p.muted)),
        ]),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.quick, required this.onSend, required this.onOffer, required this.hint});
  final TextEditingController controller;
  final bool sending;
  final List<String> quick;
  final Future<void> Function([String?]) onSend;
  final VoidCallback? onOffer;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: p.border))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              scrollDirection: Axis.horizontal,
              itemCount: quick.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ActionChip(
                label: Text(quick[i], style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: sending ? null : () => onSend(quick[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (onOffer != null)
                IconButton.filledTonal(tooltip: 'Make a counter-offer', onPressed: onOffer, icon: const Icon(Icons.sell_rounded)),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(hintText: hint, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: sending ? null : () => onSend(),
                icon: sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.title, required this.subtitle, required this.initial, required this.initialNote, required this.listed, required this.cta});
  final String title;
  final String subtitle;
  final num initial;
  final String initialNote;
  final num listed;
  final String cta;
  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final _price = TextEditingController(text: widget.initial.round().toString());
  late final _note = TextEditingController(text: widget.initialNote);

  void _done() {
    final v = num.tryParse(_price.text.trim());
    if (v == null || v <= 0) {
      showMessage(context, 'Enter a price greater than zero.', error: true);
      return;
    }
    Navigator.pop(context, (v, _note.text.trim()));
  }

  void _step(int by) {
    final v = (num.tryParse(_price.text) ?? 0) + by;
    if (v > 0) setState(() => _price.text = v.round().toString());
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: TextStyle(color: p.muted)),
        const SizedBox(height: 18),
        Row(children: [
          IconButton.outlined(tooltip: 'Lower by 50', onPressed: () => _step(-50), icon: const Icon(Icons.remove_rounded)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _price,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(prefixText: '\$ '),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.outlined(tooltip: 'Raise by 50', onPressed: () => _step(50), icon: const Icon(Icons.add_rounded)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 2,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Why this price? (optional)'),
        ),
        const SizedBox(height: 6),
        FilledButton(onPressed: _done, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), child: Text(widget.cta)),
      ]),
    );
  }
}
