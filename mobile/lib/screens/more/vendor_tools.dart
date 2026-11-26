import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../vendors/vendor_screens.dart' show VendorCard;
import 'extras.dart' show ListingInsightsSheet;

const vendorCategoryLabels = {
  'venue': 'Venue', 'catering': 'Catering', 'decoration': 'Decoration',
  'photography': 'Photography', 'music': 'Music', 'makeup': 'Makeup',
};
const listingCategories = ['Wedding', 'Corporate', 'Concert', 'Birthday', 'Conference', 'Exhibition'];
const serviceEventTypes = ['Wedding', 'Mehndi', 'Walima', 'Nikah', 'Birthday', 'Corporate', 'Conference', 'Concert', 'Exhibition'];

List<Map<String, dynamic>> _rows(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

/// A list screen that loads from the API, with pull to refresh and states.
class _Loader extends StatefulWidget {
  const _Loader({super.key, required this.load, required this.builder, this.empty});
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(BuildContext, List<Map<String, dynamic>>, Future<void> Function()) builder;
  final Widget? empty;
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final items = await widget.load();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorState(message: _error!, onRetry: _reload);
    if (_items == null) return const LoadingList(count: 4, height: 90);
    if (_items!.isEmpty && widget.empty != null) {
      return RefreshIndicator(onRefresh: _reload, child: ListView(children: [const SizedBox(height: 60), widget.empty!]));
    }
    return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, _items!, _reload));
  }
}

// ---------------------------------------------------------------- Favorites

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Favorite vendors')),
        body: _Loader(
          load: () async => _rows((await Api.instance.get('/auth/favorites'))['data']),
          empty: EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No favorites yet',
            message: 'Tap the heart on a vendor to keep them here.',
            action: FilledButton(onPressed: () => context.go('/vendors'), child: const Text('Browse vendors')),
          ),
          builder: (_, items, _) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => VendorCard(VendorItem(items[i])),
          ),
        ),
      );
}

// ---------------------------------------------------------------- Services

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  Key _key = UniqueKey();

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _ServiceSheet());
    if (ok == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My services')),
        floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Add service')),
        body: _Loader(
          key: _key,
          load: () async => _rows((await Api.instance.get('/vendor/services'))['data']),
          empty: const EmptyState(icon: Icons.design_services_outlined, title: 'No services yet', message: 'Add the packages organizers can book.'),
          builder: (context, items, reload) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = items[i];
              return Card(
                child: ListTile(
                  title: Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${s['eventType'] ?? ''} · ${vendorCategoryLabels[s['category']] ?? 'Your category'}\n${s['description'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(s['price'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                    InkWell(
                      onTap: () async {
                        if (!await confirmDialog(context, title: 'Remove this service?', message: '"${s['title']}" will no longer be offered.', confirm: 'Remove', danger: true)) return;
                        try {
                          await Api.instance.delete('/vendor/services/${idOf(s)}');
                          await reload();
                        } catch (e) {
                          if (context.mounted) showMessage(context, Api.messageOf(e), error: true);
                        }
                      },
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      );
}

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet();
  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  String _category = 'decoration';
  String _eventType = 'Wedding';
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.post('/vendor/services', {
        'title': _title.text.trim(),
        'category': _category,
        'eventType': _eventType,
        'price': Money.toBase(num.parse(_price.text.trim())),
        'description': _description.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
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
            Text('New service', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'Title', counterText: ''), validator: (v) => V.length(v, min: 2, max: 100, label: 'Title')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: vendorCategoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _eventType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'For'),
                  items: serviceEventTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _eventType = v ?? _eventType),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Price', prefixText: '${Money.symbol} '),
              validator: (v) => V.positive(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'What is included', alignLabelWithHint: true),
              validator: (v) => V.length(v, min: 10, max: 1000, label: 'Description'),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(_busy ? 'Saving…' : 'Add service')),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- Event listings

/// The vendor's public event listings (what organizers browse and make offers on).
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});
  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  Key _key = UniqueKey();

  Future<void> _edit([EventItem? e]) async {
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _ListingSheet(event: e));
    if (ok == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My event listings')),
        floatingActionButton: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add_rounded), label: const Text('New listing')),
        body: _Loader(
          key: _key,
          load: () async => _rows((await Api.instance.get('/events/organizer/my-events'))['data']),
          empty: const EmptyState(icon: Icons.event_available_outlined, title: 'No listings yet', message: 'Publish an event package so organizers can find you and make offers.'),
          builder: (context, items, reload) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = EventItem(items[i]);
              return Card(
                child: ListTile(
                  onTap: () => _edit(e),
                  leading: IconButton(
                    tooltip: 'Readiness and passes',
                    onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => ListingInsightsSheet(event: e)),
                    icon: const Icon(Icons.insights_rounded),
                  ),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${e.category} · ${dateRange(e.date, e.endDate)}\n${e.location} · ${e.capacity} guests'),
                  isThreeLine: true,
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(e.price), style: const TextStyle(fontWeight: FontWeight.w900)),
                    InkWell(
                      onTap: () async {
                        if (!await confirmDialog(context, title: 'Delete this listing?', message: '"${e.title}" will be removed.', confirm: 'Delete', danger: true)) return;
                        try {
                          await Api.instance.delete('/events/${e.id}');
                          await reload();
                        } catch (err) {
                          if (context.mounted) showMessage(context, Api.messageOf(err), error: true);
                        }
                      },
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      );
}

class _ListingSheet extends StatefulWidget {
  const _ListingSheet({this.event});
  final EventItem? event;
  @override
  State<_ListingSheet> createState() => _ListingSheetState();
}

class _ListingSheetState extends State<_ListingSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _price = TextEditingController(text: widget.event == null ? '' : '${Money.fromBase(widget.event!.price)}');
  late final _location = TextEditingController(text: widget.event?.location ?? '');
  late final _description = TextEditingController(text: widget.event?.description ?? '');
  late final _capacity = TextEditingController(text: '${widget.event?.capacity ?? 100}');
  late String _category = listingCategories.contains(widget.event?.category) ? widget.event!.category : 'Wedding';
  late DateTime? _date = widget.event?.date;
  late int _days = dayCount(widget.event?.date, widget.event?.endDate);
  bool _busy = false;
  String? _dateError;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 3), initialDate: _date != null && _date!.isAfter(now) ? _date! : now);
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    setState(() => _dateError = _date == null ? 'An event date is required.' : null);
    if (!_form.currentState!.validate() || _date == null) return;
    setState(() => _busy = true);
    final start = DateTime(_date!.year, _date!.month, _date!.day, 12);
    final body = {
      'title': _title.text.trim(),
      'category': _category,
      'price': Money.toBase(num.parse(_price.text.trim())),
      'location': _location.text.trim(),
      'description': _description.text.trim(),
      'capacity': int.parse(_capacity.text.trim()),
      'date': start.toUtc().toIso8601String(),
      'endDate': _days > 1 ? start.add(Duration(days: _days - 1)).toUtc().toIso8601String() : null,
    };
    try {
      if (widget.event == null) {
        await Api.instance.post('/events', body);
      } else {
        await Api.instance.put('/events/${widget.event!.id}', body);
      }
      if (!mounted) return;
      showMessage(context, widget.event == null ? 'Event published.' : 'Event updated.');
      Navigator.pop(context, true);
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
            Text(widget.event == null ? 'New event listing' : 'Edit listing', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Grand Royal Wedding Package', counterText: ''), validator: (v) => V.length(v, min: 3, max: 100, label: 'Title')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: listingCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Asking price', prefixText: '${Money.symbol} '),
                  validator: (v) => V.nonNegative(v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location'), validator: (v) => V.length(v, min: 2, label: 'Location')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: 'First day', errorText: _dateError),
                    child: Text(_date == null ? 'Pick a date' : shortDate(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<int>(
                  initialValue: _days.clamp(1, 30),
                  decoration: const InputDecoration(labelText: 'Days'),
                  items: [for (var d = 1; d <= 30; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                  onChanged: (v) => setState(() => _days = v ?? 1),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Capacity (guests)'),
              validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1 ? 'Capacity must be at least 1.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
              validator: (v) => V.length(v, min: 10, max: 2000, label: 'Description'),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(_busy ? 'Saving…' : (widget.event == null ? 'Publish' : 'Save changes'))),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- Availability

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});
  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  List<DateTime>? _blocked;
  String? _error;
  bool _busy = false;

  static String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/vendor/calendar');
      final list = (res['data'] as List? ?? []).map((e) => e is Map ? e['date'] : e).map((e) => DateTime.tryParse('$e')).whereType<DateTime>().toList()
        ..sort();
      setState(() {
        _blocked = list;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _toggle(DateTime d, bool block) async {
    setState(() => _busy = true);
    try {
      await Api.instance.post(block ? '/vendor/calendar/block' : '/vendor/calendar/unblock', {'date': _key(d)});
      await _load();
      if (mounted) showMessage(context, block ? '${shortDate(d)} is now marked busy.' : '${shortDate(d)} is open again.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 2), helpText: 'Mark a day as busy');
    if (d != null) await _toggle(d, true);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _busy ? null : _pick, icon: const Icon(Icons.event_busy_rounded), label: const Text('Block a day')),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : blocked == null
              ? const LoadingList(count: 4, height: 60)
              : blocked.isEmpty
                  ? const EmptyState(icon: Icons.event_available_rounded, title: 'You are open every day', message: 'Block the days you are already booked or away, so organizers do not ask for them.')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
                      for (final d in blocked)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.event_busy_rounded, color: AppColors.danger),
                            title: Text(dayLabel(d), style: const TextStyle(fontWeight: FontWeight.w700)),
                            trailing: TextButton(onPressed: _busy ? null : () => _toggle(d, false), child: const Text('Open')),
                          ),
                        ),
                    ]),
    );
  }
}

// ---------------------------------------------------------------- Reviews

class ProviderReviewsScreen extends StatelessWidget {
  const ProviderReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My reviews')),
        body: _Loader(
          load: () async => _rows((await Api.instance.get('/reviews/provider'))['data']),
          empty: const EmptyState(icon: Icons.star_outline_rounded, title: 'No reviews yet', message: 'Organizers can review an event once it is delivered.'),
          builder: (context, items, _) {
            final avg = items.fold<num>(0, (a, r) => a + ((r['rating'] as num?) ?? 0)) / items.length;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Stars(avg),
                        Text('${items.length} review${items.length == 1 ? '' : 's'}', style: TextStyle(color: AppPalette.of(context).muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              for (final r in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${((r['user'] ?? r['userId']) is Map ? (r['user'] ?? r['userId'])['name'] : null) ?? 'Organizer'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        _Stars((r['rating'] as num?) ?? 0),
                      ]),
                      if ((r['event'] ?? r['eventId']) is Map) Text('${(r['event'] ?? r['eventId'])['title']}', style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Text('${r['comment'] ?? ''}'),
                      const SizedBox(height: 4),
                      Text(timeAgo(parseDate(r['createdAt'])), style: TextStyle(color: AppPalette.of(context).muted, fontSize: 11.5)),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _Stars extends StatelessWidget {
  const _Stars(this.value);
  final num value;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(value >= i ? Icons.star_rounded : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded), size: 18, color: const Color(0xFFF59E0B)),
      ]);
}

// ---------------------------------------------------------------- Revenue

/// Earnings from bookings: released, held in escrow, and in negotiation.
class RevenueScreen extends StatelessWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Revenue')),
        body: _Loader(
          load: () async => _rows((await Api.instance.get('/bookings/organizer'))['data']),
          builder: (context, items, _) {
            final bookings = items.map(Booking.new).toList();
            num sum(bool Function(Booking) f) => bookings.where(f).fold<num>(0, (a, b) => a + b.offerPrice);
            final released = sum((b) => b.status == 'completed');
            final held = sum((b) => b.status == 'confirmed' || b.status == 'disputed');
            final pipeline = sum((b) => b.isOpen);
            final p = AppPalette.of(context);
            Widget tile(String label, String v, Color c, IconData icon) => Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(icon, color: c),
                        const SizedBox(height: 8),
                        FittedBox(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                        Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                );
            final done = bookings.where((b) => b.status == 'completed' || b.status == 'confirmed').toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                tile('Paid out', money(released), p.success, Icons.account_balance_wallet_rounded),
                tile('In escrow', money(held), p.warning, Icons.lock_clock_rounded),
              ]),
              Row(children: [
                tile('In negotiation', money(pipeline), Theme.of(context).colorScheme.primary, Icons.handshake_rounded),
                tile('Bookings', '${bookings.length}', p.muted, Icons.receipt_long_rounded),
              ]),
              const SizedBox(height: 8),
              const SectionTitle('Confirmed and delivered'),
              if (done.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text('No confirmed bookings yet.', style: TextStyle(color: p.muted))),
              for (final b in done)
                Card(
                  child: ListTile(
                    onTap: () => context.push('/negotiate/${b.id}'),
                    title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${b.customerName} · ${shortDate(b.eventDate)}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(b.offerPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                      StatusChip(b.status),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- Ticket scanner

/// Checks people in at the door: scan the QR on their pass, or type its code.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _code = TextEditingController();
  final _camera = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  (bool, String)? _result;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _check(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final res = await Api.instance.post('/tickets/scan', {'ticketNumber': code});
      setState(() => _result = (true, res['message'] as String? ?? 'Valid pass. Checked in.'));
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() => _result = (false, Api.messageOf(e)));
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Check in guests')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _camera,
              onDetect: (capture) {
                final v = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
                if (v != null) _check(v);
              },
              errorBuilder: (context, error) => Container(
                color: p.surface2,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20),
                child: Text('The camera is not available (${error.errorCode.name}). Type the pass code below.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (r != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: (r.$1 ? p.success : AppColors.danger).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(r.$1 ? Icons.verified_rounded : Icons.block_rounded, color: r.$1 ? p.success : AppColors.danger, size: 30),
              const SizedBox(width: 12),
              Expanded(child: Text(r.$2, style: TextStyle(fontWeight: FontWeight.w700, color: r.$1 ? p.success : AppColors.danger))),
            ]),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Pass code', hintText: 'TKT-…'),
              onSubmitted: _check,
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: _busy ? null : () => _check(_code.text), child: const Text('Check')),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Business profile

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});
  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _cover = TextEditingController();
  String _category = 'decoration';
  Map<String, dynamic>? _raw;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/vendor/profile');
      final d = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : res;
      setState(() {
        _raw = d;
        _error = null;
        _name.text = '${d['businessName'] ?? ''}';
        _location.text = '${d['location'] ?? ''}';
        _tagline.text = '${d['tagline'] ?? ''}';
        _description.text = '${d['description'] ?? ''}';
        _cover.text = '${d['coverImage'] ?? ''}';
        if (vendorCategoryLabels.containsKey(d['category'])) _category = d['category'] as String;
      });
    } catch (e) {
      setState(() {
        _raw = {};
        if (!(e is ApiException && e.status == 404)) _error = Api.messageOf(e);
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final packages = (_raw?['packages'] as List? ?? []).whereType<Map>().map((p) => {
            'title': p['title'],
            'price': p['price'],
            if (p['description'] != null) 'description': p['description'],
            if (p['includes'] is List) 'includes': p['includes'],
          }).toList();
      await Api.instance.post('/vendor/profile', {
        'businessName': _name.text.trim(),
        'category': _category,
        'location': _location.text.trim(),
        'tagline': _tagline.text.trim(),
        'description': _description.text.trim(),
        'coverImage': _cover.text.trim(),
        'packages': packages,
        'portfolioImages': (_raw?['portfolioImages'] as List? ?? []).map((e) => '$e').toList(),
      });
      if (mounted) showMessage(context, 'Your business profile is saved.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Business profile')),
        body: _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _raw == null
                ? const LoadingList(count: 4, height: 60)
                : Form(
                    key: _form,
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Business name'), validator: (v) => (v ?? '').trim().length < 2 ? 'Business name is too short' : null),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: vendorCategoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location'), validator: (v) => V.length(v, min: 2, label: 'Location')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _tagline, maxLength: 140, decoration: const InputDecoration(labelText: 'Tagline (optional)')),
                      const SizedBox(height: 4),
                      TextFormField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'About your business', alignLabelWithHint: true)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cover,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'Cover picture link (optional)', hintText: 'https://…'),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final u = Uri.tryParse(s);
                          return u != null && u.hasScheme && u.host.isNotEmpty ? null : 'Enter a full link starting with https://';
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(_busy ? 'Saving…' : 'Save profile')),
                    ]),
                  ),
      );
}
