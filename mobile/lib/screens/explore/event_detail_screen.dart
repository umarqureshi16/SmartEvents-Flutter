import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/firebase_service.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventItem? _event;
  String? _error;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/events/${widget.id}');
      setState(() => _event = EventItem(Map<String, dynamic>.from(res['data'] as Map)));
      FirebaseService.instance.logEvent('view_item', {'item_id': widget.id, 'item_category': _event!.category});
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _offer() async {
    final e = _event!;
    final bookingId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OfferSheet(event: e),
    );
    if (bookingId != null && mounted) context.push('/negotiate/$bookingId');
  }

  Future<void> _getPass() async {
    final e = _event!;
    final ok = await confirmDialog(context,
        title: 'Get an entry pass?', message: 'A QR pass for "${e.title}" is added to your wallet.', confirm: 'Get pass');
    if (!ok || !mounted) return;
    setState(() => _buying = true);
    try {
      await Api.instance.post('/tickets/purchase', {'eventId': e.id});
      FirebaseService.instance.logEvent('purchase_ticket', {'item_id': e.id});
      if (!mounted) return;
      showMessage(context, 'Pass added to your wallet.');
      context.push('/tickets');
    } catch (err) {
      if (mounted) showMessage(context, Api.messageOf(err), error: true);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppState>().user;
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorState(message: _error!, onRetry: _load));
    final e = _event;
    if (e == null) return Scaffold(appBar: AppBar(), body: const LoadingList(count: 3, height: 160));
    final p = AppPalette.of(context);
    final isCustomer = me?.role == 'customer';
    final mine = me?.id == e.vendorId;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          stretch: true,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'event-${e.id}', child: NetImage(e.image, label: e.category)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                StatusChip(e.status),
                const SizedBox(width: 8),
                Text(e.category, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Text(e.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: [
                  InfoTile(icon: Icons.calendar_today_rounded, label: 'Date', value: dayCount(e.date, e.endDate) > 1 ? dateRange(e.date, e.endDate) : dayLabel(e.date)),
                  InfoTile(icon: Icons.place_outlined, label: 'Location', value: e.location.isEmpty ? 'To be agreed' : e.location),
                  InfoTile(icon: Icons.groups_rounded, label: 'Capacity', value: '${e.capacity} guests'),
                  InfoTile(icon: Icons.sell_outlined, label: 'Listed price', value: money(e.price)),
                ],
              ),
              const SizedBox(height: 22),
              Text('About', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(e.description, style: TextStyle(height: 1.55, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85))),
              const SizedBox(height: 22),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Avatar(name: e.vendorName ?? 'Vendor'),
                  title: Text(e.vendorName ?? 'Vendor', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('See profile, packages and reviews'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: e.vendorId == null ? null : () => context.push('/vendor/${e.vendorId}'),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Icon(Icons.verified_user_rounded, color: p.success),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Make an offer below the listed price. Once agreed, your payment is held in escrow until the event is delivered.',
                        style: TextStyle(height: 1.4)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: p.border))),
          child: mine
              ? const Text('This is your listing. Offers on it appear in Bookings.', textAlign: TextAlign.center)
              : !isCustomer
                  ? Text('Sign in as an organizer to make offers.', textAlign: TextAlign.center, style: TextStyle(color: p.muted))
                  : Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _buying ? null : _getPass,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Pass', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(onPressed: _offer, icon: const Icon(Icons.handshake_rounded), label: const Text('Make an offer')),
                      ),
                    ]),
        ),
      ),
    );
  }
}

/// Bottom sheet to open a negotiation on an event. Returns the booking id.
class OfferSheet extends StatefulWidget {
  const OfferSheet({super.key, required this.event});
  final EventItem event;
  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  late final _price = TextEditingController(text: Money.fromBase(widget.event.price * 0.9).toString());
  final _note = TextEditingController();
  bool _busy = false;
  // The organizer's own events, so the offer can be filed under one of them.
  List<PlanRef> _plans = [];
  String? _planId;

  @override
  void initState() {
    super.initState();
    Api.instance.get('/plans').then((r) {
      if (mounted) setState(() => _plans = (r['data'] as List? ?? []).whereType<Map>().map((m) => PlanRef(Map<String, dynamic>.from(m))).toList());
    }).catchError((_) {});
  }

  Future<void> _send() async {
    final price = num.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      showMessage(context, 'Enter a price greater than zero.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.instance.post('/bookings', {
        'eventId': widget.event.id,
        'offerPrice': Money.toBase(price),
        if (_note.text.trim().isNotEmpty) 'message': _note.text.trim(),
        if (_planId != null) 'planId': _planId,
      });
      FirebaseService.instance.logEvent('make_offer', {'item_id': widget.event.id, 'value': Money.toBase(price)});
      if (mounted) Navigator.pop(context, idOf(res['data']));
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final listed = widget.event.price;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Make an offer', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Listed at ${money(listed)}. The vendor can accept, decline or counter.', style: TextStyle(color: p.muted)),
        const SizedBox(height: 18),
        Wrap(spacing: 8, children: [
          for (final pct in [0.8, 0.9, 1.0])
            ActionChip(
              label: Text(pct == 1.0 ? 'Listed ${money(listed)}' : '${((1 - pct) * 100).round()}% off · ${money(listed * pct)}'),
              onPressed: () => setState(() => _price.text = Money.fromBase(listed * pct).toString()),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          decoration: InputDecoration(labelText: 'Your price', prefixText: '${Money.symbol} '),
        ),
        if (_plans.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _planId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'For which of your events? (optional)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Not linked to an event')),
              ..._plans.map((pl) => DropdownMenuItem<String?>(value: pl.id, child: Text('${pl.title} · ${dateRange(pl.date, pl.endDate, withDays: false)}', overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _planId = v),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Message to the vendor (optional)', hintText: 'Date, guest count, what you need…'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          icon: const Icon(Icons.send_rounded),
          label: Text(_busy ? 'Sending…' : 'Send offer'),
        ),
      ]),
    );
  }
}
