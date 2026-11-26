import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../explore/explore_screen.dart' show EventCard;
import '../more/extras.dart' show VendorReviewsList, showVendorStat;

const vendorCategories = {
  'All': Icons.apps_rounded,
  'venue': Icons.location_city_rounded,
  'catering': Icons.restaurant_rounded,
  'decoration': Icons.local_florist_rounded,
  'photography': Icons.photo_camera_rounded,
  'music': Icons.music_note_rounded,
  'makeup': Icons.brush_rounded,
};

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});
  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _category = 'All';
  List<VendorItem>? _vendors;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/vendor/list', query: {
        'limit': 40,
        if (_category != 'All') 'category': _category,
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      });
      setState(() => _vendors = (res['data'] as List? ?? []).whereType<Map>().map((m) => VendorItem(Map<String, dynamic>.from(m))).toList());
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 450), _load);
            },
            decoration: const InputDecoration(hintText: 'Search vendors by name or city', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in vendorCategories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(e.value, size: 16, color: _category == e.key ? Colors.white : null),
                    label: Text(titleCase(e.key)),
                    selected: _category == e.key,
                    labelStyle: TextStyle(color: _category == e.key ? Colors.white : null, fontWeight: FontWeight.w700),
                    onSelected: (_) {
                      setState(() {
                        _category = e.key;
                        _vendors = null;
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _vendors == null
                  ? const LoadingList(height: 110)
                  : _vendors!.isEmpty
                      ? const EmptyState(icon: Icons.storefront_outlined, title: 'No vendors here yet', message: 'Try another category.')
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _vendors!.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => VendorCard(_vendors![i]).animate().fadeIn(duration: 250.ms, delay: (30 * (i % 12)).ms),
                          ),
                        ),
        ),
      ]),
    );
  }
}

class VendorCard extends StatelessWidget {
  const VendorCard(this.v, {super.key});
  final VendorItem v;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vendor/${v.userId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 86, height: 86, child: NetImage(v.cover, icon: vendorCategories[v.category] ?? Icons.storefront_rounded))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  if (v.verified) ...[const SizedBox(width: 4), Icon(Icons.verified_rounded, size: 16, color: Theme.of(context).colorScheme.primary)],
                ]),
                const SizedBox(height: 2),
                Text('${titleCase(v.category)} · ${v.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.star_rounded, size: 16, color: const Color(0xFFF59E0B)),
                  Text(' ${v.rating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(width: 12),
                  Icon(Icons.shield_rounded, size: 14, color: p.success),
                  Text(' ${v.trustScore.round()}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: p.success)),
                  const Spacer(),
                  if (v.startingPrice != null)
                    Text('from ${money(v.startingPrice)}', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class VendorDetailScreen extends StatefulWidget {
  const VendorDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  VendorItem? _vendor;
  List<EventItem> _events = [];
  List<DesignItem> _designs = [];
  List<Map<String, dynamic>> _services = [];
  String? _error;
  bool _savingFollow = false;

  bool _following(AppState app, VendorItem v) =>
      ((app.user?.raw['favorites'] as List?) ?? const []).map((e) => idOf(e)).contains(v.userId);

  /// Follow / unfollow (the website's "Save vendor"): lists the vendor under Favorites.
  Future<void> _toggleFollow(VendorItem v) async {
    final app = context.read<AppState>();
    final on = _following(app, v);
    setState(() => _savingFollow = true);
    try {
      if (on) {
        await Api.instance.delete('/auth/favorites/${v.userId}');
      } else {
        await Api.instance.post('/auth/favorites', {'vendorId': v.userId});
      }
      await app.refreshMe();
      if (mounted) showMessage(context, on ? 'Removed from your favorites.' : 'Saved to your favorites.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _savingFollow = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/vendor/profile/${widget.id}');
      final designs = await Api.instance.get('/designs', query: {'vendor': widget.id}).catchError((_) => <String, dynamic>{});
      setState(() {
        _vendor = VendorItem(Map<String, dynamic>.from(res['profile'] as Map));
        _events = (res['events'] as List? ?? []).whereType<Map>().map((m) => EventItem(Map<String, dynamic>.from(m))).toList();
        _services = (res['services'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _designs = (designs['data'] as List? ?? []).whereType<Map>().map((m) => DesignItem(Map<String, dynamic>.from(m))).toList();
      });
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  /// Sends an offer straight to this vendor (optionally for one package or
  /// design) and opens the negotiation, like "Request a quote" on the website.
  Future<void> _offer(VendorItem v, {String? title, num? price, String? serviceId, String? eventType, DesignItem? design}) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VendorOfferSheet(vendor: v, title: title, price: price, serviceId: serviceId, eventType: eventType, design: design),
    );
    if (id != null && mounted) context.push('/negotiate/$id');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorState(message: _error!, onRetry: _load));
    final v = _vendor;
    if (v == null) return Scaffold(appBar: AppBar(), body: const LoadingList(count: 3, height: 150));
    final p = AppPalette.of(context);
    final stats = v.stats;

    final organizer = context.watch<AppState>().user?.role == 'customer';
    final services = [
      for (final s in _services)
        (Package(s), idOf(s), s['eventType'] as String?),
      for (final pk in v.packages) (pk, null, null),
    ];
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        bottomNavigationBar: organizer
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: () => _offer(v),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    icon: const Icon(Icons.request_quote_rounded),
                    label: const Text('Request a quote'),
                  ),
                ),
              )
            : null,
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF1E1B4B),
              actions: [
                if (context.watch<AppState>().user?.role == 'customer')
                  Builder(builder: (context) {
                    final on = _following(context.watch<AppState>(), v);
                    return IconButton(
                      tooltip: on ? 'Remove from favorites' : 'Save to favorites',
                      onPressed: _savingFollow ? null : () => _toggleFollow(v),
                      icon: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: on ? const Color(0xFFFB7185) : Colors.white),
                    );
                  }),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  NetImage(v.cover, icon: vendorCategories[v.category] ?? Icons.storefront_rounded),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.black87])),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Avatar(name: v.name, size: 58),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v.name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                          Text('${titleCase(v.category)} · ${v.location}', style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (v.tagline.isNotEmpty) Text(v.tagline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (v.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(v.description, style: TextStyle(color: p.muted, height: 1.45)),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    _Stat(value: v.rating.toStringAsFixed(1), label: 'Rating', icon: Icons.star_rounded, color: const Color(0xFFF59E0B), onTap: () => DefaultTabController.of(context).animateTo(3)),
                    _Stat(value: '${v.trustScore.round()}', label: 'Trust', icon: Icons.shield_rounded, color: p.success, onTap: () => showVendorStat(context, v.userId, 'trust')),
                    _Stat(value: '${stats['completedBookings'] ?? 0}', label: 'Delivered', icon: Icons.task_alt_rounded, color: Theme.of(context).colorScheme.primary, onTap: () => showVendorStat(context, v.userId, 'delivered')),
                    _Stat(value: '${stats['followers'] ?? 0}', label: 'Followers', icon: Icons.favorite_rounded, color: AppColors.danger, onTap: () => showVendorStat(context, v.userId, 'followers')),
                  ]),
                ]),
              ),
            ),
            const SliverToBoxAdapter(
              child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Events'), Tab(text: 'Packages'), Tab(text: 'Designs'), Tab(text: 'Reviews')]),
            ),
          ],
          body: TabBarView(children: [
            _events.isEmpty
                ? const EmptyState(icon: Icons.event_busy_rounded, title: 'No events listed')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => EventCard(_events[i]),
                  ),
            services.isEmpty
                ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No packages yet')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: services.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final (pk, serviceId, type) = services[i];
                      return _PackageCard(pk,
                          onBook: organizer ? () => _offer(v, title: pk.title, price: pk.price, serviceId: serviceId, eventType: type) : null);
                    },
                  ),
            _designs.isEmpty
                ? const EmptyState(icon: Icons.palette_outlined, title: 'No published designs')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _designs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _DesignCard(_designs[i], onBook: organizer ? () => _offer(v, design: _designs[i]) : null),
                  ),
            VendorReviewsList(vendorUserId: v.userId),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon, required this.color, this.onTap});
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 11, color: p.muted)),
        ]),
      ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard(this.pkg, {this.onBook});
  final Package pkg;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(pkg.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(money(pkg.price), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
          ]),
          if (pkg.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(pkg.description, style: TextStyle(color: p.muted)),
          ],
          if (pkg.includes.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final i in pkg.includes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: p.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(i)),
                ]),
              ),
          ],
          if (onBook != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onBook, icon: const Icon(Icons.handshake_outlined, size: 18), label: const Text('Make an offer')),
          ],
        ]),
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard(this.d, {this.onBook});
  final DesignItem d;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 16 / 9, child: NetImage(d.imageUrl, icon: Icons.palette_rounded)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text([d.eventType, d.theme].where((s) => s.isNotEmpty).join(' · ').toUpperCase(),
                style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(money(d.totalCost), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
            if (d.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(d.summary, style: TextStyle(color: p.muted, height: 1.4)),
            ],
            const SizedBox(height: 8),
            for (final e in d.elements.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Expanded(child: Text('${e['item'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(money(e['cost'] as num?), style: TextStyle(color: p.muted)),
                ]),
              ),
            if (onBook != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: onBook, icon: const Icon(Icons.event_available_rounded, size: 18), label: const Text('Book this design')),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// An offer sent straight to a vendor: the price, the event day, where and
/// what for. With [design], it books that design instead.
class VendorOfferSheet extends StatefulWidget {
  const VendorOfferSheet({super.key, required this.vendor, this.title, this.price, this.serviceId, this.eventType, this.design});
  final VendorItem vendor;
  final String? title;
  final num? price;
  final String? serviceId;
  final String? eventType;
  final DesignItem? design;
  @override
  State<VendorOfferSheet> createState() => _VendorOfferSheetState();
}

class _VendorOfferSheetState extends State<VendorOfferSheet> {
  static const _types = ['Wedding', 'Mehndi', 'Walima', 'Nikah', 'Birthday', 'Corporate', 'Conference', 'Concert', 'Exhibition', 'Event'];
  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(
      text: widget.design != null ? '${Money.fromBase(widget.design!.totalCost)}' : (widget.price != null && widget.price! > 0 ? '${Money.fromBase(widget.price)}' : ''));
  late final _location = TextEditingController(text: widget.vendor.location);
  late final _message = TextEditingController(
      text: widget.design != null
          ? 'Hello! I would like the "${widget.design!.title}" design.'
          : widget.title != null
              ? 'Hello! I would like to book "${widget.title}".'
              : 'Hello! Could you quote for my event?');
  late String _type = () {
    final t = widget.design?.eventType ?? widget.eventType;
    final match = _types.where((x) => x.toLowerCase() == (t ?? '').toLowerCase());
    return match.isNotEmpty ? match.first : 'Wedding';
  }();
  DateTime? _date;
  String? _dateError;
  bool _busy = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 3), initialDate: _date ?? now.add(const Duration(days: 30)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _send() async {
    setState(() => _dateError = _date == null ? 'Pick the event date' : null);
    if (!_form.currentState!.validate() || _date == null) return;
    setState(() => _busy = true);
    final date = DateTime(_date!.year, _date!.month, _date!.day, 12).toUtc().toIso8601String();
    final price = Money.toBase(num.parse(_price.text.trim()));
    final message = _message.text.trim();
    try {
      String? id;
      if (widget.design != null) {
        final res = await Api.instance.post('/designs/${widget.design!.id}/book', {'date': date, 'location': _location.text.trim(), 'offerPrice': price, 'message': message});
        id = idOf((res['data'] as Map?)?['bookingId']);
      } else {
        final res = await Api.instance.post('/bookings', {
          'vendorId': widget.vendor.userId,
          'serviceId': ?widget.serviceId,
          'offerPrice': price,
          if (message.isNotEmpty) 'message': message,
          'eventDetails': {'eventType': _type, 'date': date, 'location': _location.text.trim(), if (message.isNotEmpty) 'message': message},
        });
        id = idOf(res['booking'] ?? res['data']);
      }
      if (mounted) Navigator.pop(context, id);
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
            Text(widget.design != null ? 'Book this design' : (widget.title ?? 'Request a quote'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${widget.vendor.name} can accept, decline or counter.', style: TextStyle(color: AppPalette.of(context).muted)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              decoration: InputDecoration(labelText: 'Your offer', prefixText: '${Money.symbol} '),
              validator: (v) => V.positive(v, label: 'Offer price'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: 'Event date', errorText: _dateError),
                    child: Text(_date == null ? 'Pick a date' : shortDate(_date)),
                  ),
                ),
              ),
              if (widget.design == null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Event'),
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Where'), validator: (v) => V.length(v, min: 2, label: 'Location')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
              validator: (v) => (v ?? '').length > 500 ? 'Keep it under 500 characters' : null,
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: Text(_busy ? 'Sending…' : (widget.design != null ? 'Book design' : 'Send offer')),
            ),
          ]),
        ),
      );
}
