import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

const eventCategories = ['All', 'Wedding', 'Corporate', 'Concert', 'Birthday', 'Conference', 'Exhibition'];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _category = 'All';
  final List<EventItem> _events = [];
  List<VendorItem> _vendors = [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadVendors();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400 && !_more && _page < _pages) {
        _load(next: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    try {
      final res = await Api.instance.get('/vendor/list', query: {'limit': 10});
      setState(() => _vendors = (res['data'] as List? ?? []).whereType<Map>().map((m) => VendorItem(Map<String, dynamic>.from(m))).toList());
    } catch (_) {}
  }

  Future<void> _load({bool next = false}) async {
    setState(() {
      if (next) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = next ? _page + 1 : 1;
      final res = await Api.instance.get('/events', query: {
        'page': page,
        'limit': 10,
        if (_category != 'All') 'category': _category,
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      });
      final list = (res['events'] as List? ?? res['data'] as List? ?? []).whereType<Map>().map((m) => EventItem(Map<String, dynamic>.from(m)));
      final meta = res['meta'] as Map? ?? {};
      setState(() {
        if (!next) _events.clear();
        _events.addAll(list);
        _page = page;
        _pages = (meta['totalPages'] as num?)?.toInt() ?? 1;
      });
    } catch (e) {
      if (!next) setState(() => _error = Api.messageOf(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = AppPalette.of(context);
    final first = (app.user?.name ?? '').split(' ').first;
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), _loadVendors()]);
      },
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            floating: true,
            titleSpacing: 16,
            toolbarHeight: 72,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello${first.isEmpty ? '' : ', $first'}', style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
              const Text('Find your next event'),
            ]),
            actions: [
              _BellButton(count: app.unread),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search weddings, venues, decor…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            _load();
                          }),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                scrollDirection: Axis.horizontal,
                itemCount: eventCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = eventCategories[i];
                  return ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    labelStyle: TextStyle(color: _category == c ? Colors.white : null, fontWeight: FontWeight.w700),
                    onSelected: (_) {
                      setState(() => _category = c);
                      _load();
                    },
                  );
                },
              ),
            ),
          ),
          if (_vendors.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionTitle('Top vendors', trailing: TextButton(onPressed: () => context.go('/vendors'), child: const Text('See all')))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _vendors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _VendorMini(_vendors[i]),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SectionTitle(_category == 'All' ? 'Upcoming events' : '$_category events')),
          if (_loading)
            const SliverToBoxAdapter(child: SizedBox(height: 520, child: LoadingList(count: 3, height: 230)))
          else if (_error != null)
            SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: _error!, onRetry: _load))
          else if (_events.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.event_busy_rounded, title: 'No events found', message: 'Try another category or search.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: _events.length + (_more ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => i >= _events.length
                    ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                    : EventCard(_events[i]).animate().fadeIn(duration: 300.ms, delay: (40 * (i % 10)).ms).slideY(begin: 0.06),
              ),
            ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: const Icon(Icons.notifications_none_rounded, size: 27),
        ),
      );
}

class _VendorMini extends StatelessWidget {
  const _VendorMini(this.v);
  final VendorItem v;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/vendor/${v.userId}'),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: v.name, size: 44, url: v.cover),
          const Spacer(),
          Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(titleCase(v.category), style: TextStyle(fontSize: 12, color: p.muted)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.shield_rounded, size: 13, color: p.success),
            const SizedBox(width: 3),
            Text('${v.trustScore.round()} trust', style: TextStyle(fontSize: 11.5, color: p.success, fontWeight: FontWeight.w800)),
          ]),
        ]),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard(this.e, {super.key});
  final EventItem e;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/event/${e.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'event-${e.id}', child: NetImage(e.image, label: e.category)),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                  child: Text(e.category.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                  child: Text('from ${money(e.price)}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: p.muted),
                const SizedBox(width: 5),
                Text(dateRange(e.date, e.endDate), style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(width: 14),
                Icon(Icons.place_outlined, size: 15, color: p.muted),
                const SizedBox(width: 3),
                Expanded(child: Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13))),
              ]),
              const SizedBox(height: 6),
              if (e.vendorName != null)
                Text('by ${e.vendorName}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}
