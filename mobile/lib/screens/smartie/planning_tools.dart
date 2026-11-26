import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

const _fields = {'venue': 'Venue', 'catering': 'Catering', 'decoration': 'Decoration', 'photography': 'Photography', 'music': 'Music & sound', 'makeup': 'Makeup'};
const _types = ['Nikah', 'Wedding', 'Mehndi', 'Walima', 'Birthday', 'Corporate', 'Conference', 'Concert'];

/// Smartie's planning tools from the website: budget planner (books packages
/// together), event timeline, budget check, and the package list.
class PlanningToolsScreen extends StatelessWidget {
  const PlanningToolsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Planning tools'),
            bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(text: 'Budget planner'),
              Tab(text: 'Timeline'),
              Tab(text: 'Budget check'),
              Tab(text: 'Packages'),
            ]),
          ),
          body: const TabBarView(children: [_BudgetPlanner(), _Timeline(), _BudgetCheck(), PackagesView()]),
        ),
      );
}

// ---------------------------------------------------------------- budget planner

class _BudgetPlanner extends StatefulWidget {
  const _BudgetPlanner();
  @override
  State<_BudgetPlanner> createState() => _BudgetPlannerState();
}

class _BudgetPlannerState extends State<_BudgetPlanner> with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _budget = TextEditingController();
  final _city = TextEditingController();
  final _title = TextEditingController();
  String _type = 'Nikah';
  DateTime? _date;
  int _days = 1;
  Map<String, dynamic>? _result;
  final Map<String, String> _choice = {}; // field -> package id ('' = skip)
  String? _busy;

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _options(Map<String, dynamic> item) => [if (item['package'] is Map) _m(item['package']), ..._l(item['alternatives'])];

  List<Map<String, dynamic>> get _chosen => _result == null
      ? []
      : _l(_result!['items']).map((i) => _options(i).where((p) => idOf(p) == _choice[i['field']]).firstOrNull).whereType<Map<String, dynamic>>().toList();

  Future<void> _plan() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = 'plan');
    try {
      final r = await Api.instance.post('/plans/budget', {
        'budget': Money.toBase(num.parse(_budget.text.trim())),
        'eventType': _type,
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      });
      final d = _m(r['data']);
      setState(() {
        _result = d;
        _choice
          ..clear()
          ..addAll({for (final i in _l(d['items'])) '${i['field']}': idOf(i['package']) ?? ''});
      });
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _book() async {
    if (_date == null) return showMessage(context, 'Add the event date to send the offers.', error: true);
    if (_chosen.isEmpty) return showMessage(context, 'Pick at least one package.', error: true);
    setState(() => _busy = 'book');
    try {
      final r = await Api.instance.post('/plans/budget/book', {
        'serviceIds': _chosen.map(idOf).toList(),
        'title': _title.text.trim().isNotEmpty ? _title.text.trim() : '$_type${_city.text.trim().isNotEmpty ? ' in ${_city.text.trim()}' : ''}',
        'eventType': _type,
        'date': DateTime(_date!.year, _date!.month, _date!.day, 12).toUtc().toIso8601String(),
        'days': _days.clamp(1, 30),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      });
      final d = _m(r['data']);
      final sent = (d['sent'] as List? ?? []).length;
      final failed = (d['failed'] as List? ?? []).length;
      if (!mounted) return;
      showMessage(context, '$sent offer${sent == 1 ? '' : 's'} sent${failed > 0 ? ', $failed failed' : ''}. Your event is ready.');
      if (d['planId'] != null) context.push('/events/${d['planId']}');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = AppPalette.of(context);
    final total = _chosen.fold<num>(0, (t, x) => t + ((x['price'] as num?) ?? 0));
    final budget = (_result?['budget'] as num?) ?? 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Say what you want to spend. Smartie picks a vendor package for each part of the event that fits, and books them together.',
          style: TextStyle(color: p.muted, height: 1.5)),
      const SizedBox(height: 14),
      Form(
        key: _form,
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'Total budget', prefixText: '${Money.symbol} '),
                validator: (v) => V.positive(v) == null ? null : 'Enter your total budget.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City (optional)', hintText: 'Lahore')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy != null ? null : _plan,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(_busy == 'plan' ? 'Planning…' : 'Plan my budget'),
          ),
        ]),
      ),
      if (_result != null) ...[
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: Text('Picked ${money(total)} of ${money(budget)}', style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(total <= budget ? '${money(budget - total)} left' : '${money(total - budget)} over',
                  style: TextStyle(fontWeight: FontWeight.w800, color: total <= budget ? p.success : AppColors.danger)),
            ]),
          ),
        ),
        for (final i in _l(_result!['items']))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_fields[i['field']] ?? titleCase('${i['field']}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Text('share ${money(i['allocation'] as num?)}', style: TextStyle(color: p.muted, fontSize: 12)),
                ]),
                const SizedBox(height: 6),
                if (_options(i).isEmpty)
                  Text('${i['note'] ?? 'No packages listed yet.'}', style: TextStyle(color: p.muted))
                else
                  RadioGroup<String>(
                    groupValue: _choice['${i['field']}'] ?? '',
                    onChanged: (v) => setState(() => _choice['${i['field']}'] = v ?? ''),
                    child: Column(children: [
                      for (final pk in _options(i))
                        RadioListTile<String>(
                          value: idOf(pk) ?? '',
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${pk['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${_m(pk['vendor'])['businessName'] ?? ''} · ${_m(pk['vendor'])['location'] ?? ''}'
                              '${((_m(pk['vendor'])['rating'] as num?) ?? 0) > 0 ? ' · ${(_m(pk['vendor'])['rating'] as num).toStringAsFixed(1)} ★' : ''}'),
                          secondary: Text(money(pk['price'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      const RadioListTile<String>(value: '', dense: true, contentPadding: EdgeInsets.zero, title: Text('Skip this part')),
                    ]),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Name of your event (optional)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 3), initialDate: _date ?? now.add(const Duration(days: 30)));
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(decoration: const InputDecoration(labelText: 'Event date'), child: Text(_date == null ? 'Pick a date' : shortDate(_date))),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<int>(
              initialValue: _days,
              decoration: const InputDecoration(labelText: 'Days'),
              items: [for (var d = 1; d <= 30; d++) DropdownMenuItem(value: d, child: Text('$d'))],
              onChanged: (v) => setState(() => _days = v ?? 1),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy != null ? null : _book,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.send_rounded),
          label: Text(_busy == 'book' ? 'Sending…' : 'Send ${_chosen.length} offer${_chosen.length == 1 ? '' : 's'}'),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- timeline

class _Timeline extends StatefulWidget {
  const _Timeline();
  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> with AutomaticKeepAliveClientMixin {
  String _type = 'Wedding';
  DateTime? _date;
  bool _busy = false;
  List<Map<String, dynamic>>? _steps;

  @override
  bool get wantKeepAlive => true;

  Future<void> _go() async {
    if (_date == null) return showMessage(context, 'Please specify event date.', error: true);
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('/ai/timeline', {
        'eventDetails': {'date': _date!.toUtc().toIso8601String(), 'eventType': _type},
      });
      setState(() => _steps = _l(r['data']));
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = AppPalette.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Smartie lays out what to do and when, counting back from your event day.', style: TextStyle(color: p.muted, height: 1.5)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Event'),
            items: [..._types, 'Exhibition'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(context: context, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 3), initialDate: _date ?? now.add(const Duration(days: 60)));
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Event date'), child: Text(_date == null ? 'Pick a date' : shortDate(_date))),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _busy ? null : _go, icon: const Icon(Icons.timeline_rounded), label: Text(_busy ? 'Building…' : 'Build my timeline')),
      const SizedBox(height: 16),
      if (_steps != null && _steps!.isEmpty) Text('No timeline came back. Try again.', style: TextStyle(color: p.muted)),
      for (final (i, s) in (_steps ?? const <Map<String, dynamic>>[]).indexed)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              CircleAvatar(radius: 14, backgroundColor: Theme.of(context).colorScheme.primary, child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary))),
              if (i < _steps!.length - 1) Expanded(child: Container(width: 2, color: p.border)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['milestone']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${s['daysBefore']} days before${_date != null ? ' · ${shortDate(_date!.subtract(Duration(days: (s['daysBefore'] as num?)?.toInt() ?? 0)))}' : ''}',
                      style: TextStyle(color: p.success, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${s['description'] ?? ''}', style: TextStyle(color: p.muted, height: 1.45)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- budget check

class _BudgetCheck extends StatefulWidget {
  const _BudgetCheck();
  @override
  State<_BudgetCheck> createState() => _BudgetCheckState();
}

class _BudgetCheckState extends State<_BudgetCheck> with AutomaticKeepAliveClientMixin {
  final _total = TextEditingController();
  final _name = TextEditingController();
  final _cost = TextEditingController();
  final List<(String, num)> _items = []; // name, cost in dollars
  bool _busy = false;
  Map<String, dynamic>? _report;

  @override
  bool get wantKeepAlive => true;

  void _add() {
    final n = _name.text.trim();
    final c = num.tryParse(_cost.text.trim());
    if (n.isEmpty || c == null || c <= 0) return showMessage(context, 'Give the item a name and a cost above zero.', error: true);
    setState(() => _items.add((n, Money.toBase(c))));
    _name.clear();
    _cost.clear();
  }

  Future<void> _go() async {
    final total = num.tryParse(_total.text.trim());
    if (total == null || total <= 0) return showMessage(context, 'Enter your total budget.', error: true);
    if (_items.isEmpty) return showMessage(context, 'Add at least one item.', error: true);
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('/ai/budget/analyze', {
        'totalBudget': Money.toBase(total),
        'services': _items.map((x) => '${x.$1}: USD ${x.$2}').toList(),
      });
      setState(() => _report = _m(r['data']));
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = AppPalette.of(context);
    final spent = _items.fold<num>(0, (t, x) => t + x.$2);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('List what you plan to spend and Smartie checks it against your budget.', style: TextStyle(color: p.muted, height: 1.5)),
      const SizedBox(height: 14),
      TextField(
        controller: _total,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: 'Total budget', prefixText: '${Money.symbol} '),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(flex: 3, child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item', hintText: 'Catering'))),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(controller: _cost, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Cost', prefixText: '${Money.symbol} ')),
        ),
        IconButton(onPressed: _add, icon: const Icon(Icons.add_circle_rounded)),
      ]),
      for (final (i, x) in _items.indexed)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(x.$1),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(money(x.$2), style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(onPressed: () => setState(() => _items.removeAt(i)), icon: const Icon(Icons.close_rounded, size: 18)),
          ]),
        ),
      if (_items.isNotEmpty) Text('Planned: ${money(spent)}', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _busy ? null : _go, icon: const Icon(Icons.fact_check_rounded), label: Text(_busy ? 'Checking…' : 'Check my budget')),
      if (_report != null) ...[
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('${_report!['analysis'] ?? ''}', style: const TextStyle(height: 1.5)))),
        if ((_report!['warnings'] as List? ?? []).isNotEmpty)
          Card(
            color: p.warning.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final w in _report!['warnings'] as List) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $w')),
              ]),
            ),
          ),
        if (_report!['breakdown'] is Map)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                for (final e in _m(_report!['breakdown']).entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(width: 110, child: Text(titleCase(e.key))),
                      Expanded(child: LinearProgressIndicator(value: (((e.value as num?) ?? 0) / 100).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(9))),
                      const SizedBox(width: 8),
                      Text('${e.value}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
          ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- packages

/// Vendor packages by field, bookable in one tap (optionally into an event).
class PackagesView extends StatefulWidget {
  const PackagesView({super.key, this.planId});
  final String? planId;
  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> with AutomaticKeepAliveClientMixin {
  String _field = 'venue';
  List<Map<String, dynamic>>? _items;
  String? _busy;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _items = null);
    try {
      final r = await Api.instance.get('/plans/packages', query: {'category': _field});
      if (mounted) setState(() => _items = _l(r['data']));
    } catch (_) {
      if (mounted) setState(() => _items = []);
    }
  }

  Future<void> _book(Map<String, dynamic> pkg) async {
    setState(() => _busy = idOf(pkg));
    try {
      final r = await Api.instance.post('/plans/book-package', {'serviceId': idOf(pkg), 'planId': ?widget.planId});
      final id = idOf(_m(r['data'])['bookingId']);
      if (mounted && id != null) context.push('/negotiate/$id');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = AppPalette.of(context);
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), children: [
          for (final e in _fields.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(e.value),
                selected: _field == e.key,
                onSelected: (_) {
                  _field = e.key;
                  _load();
                },
              ),
            ),
        ]),
      ),
      Expanded(
        child: _items == null
            ? const LoadingList(count: 3, height: 90)
            : _items!.isEmpty
                ? EmptyState(icon: Icons.inventory_2_outlined, title: 'No ${_fields[_field]!.toLowerCase()} packages yet')
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final pk in _items!)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${pk['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                              Text(money(pk['price'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                            ]),
                            const SizedBox(height: 2),
                            Text('${_m(pk['vendor'])['businessName'] ?? ''} · ${_m(pk['vendor'])['location'] ?? ''}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                            if ((pk['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${pk['description']}')),
                            const SizedBox(height: 10),
                            Row(children: [
                              TextButton(onPressed: () => context.push('/vendor/${_m(pk['vendor'])['userId'] ?? idOf(pk['vendor'])}'), child: const Text('See vendor')),
                              const Spacer(),
                              FilledButton(
                                onPressed: _busy != null ? null : () => _book(pk),
                                child: Text(_busy == idOf(pk) ? 'Booking…' : 'Make an offer'),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                  ]),
      ),
    ]);
  }
}
