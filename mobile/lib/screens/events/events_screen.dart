import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

const _eventTypes = ['Wedding', 'Nikah', 'Mehndi', 'Walima', 'Birthday', 'Corporate', 'Conference', 'Concert', 'Exhibition'];

/// The organizer's events (plans): one or several days, with a checklist.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<EventPlan>? _plans;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/plans');
      if (!mounted) return;
      setState(() => _plans = (res['data'] as List? ?? []).whereType<Map>().map((m) => EventPlan(Map<String, dynamic>.from(m))).toList());
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<EventPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewEventSheet(),
    );
    if (created != null && mounted) {
      await _load();
      if (mounted) context.push('/events/${created.id}').then((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My events')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('New event')),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _plans == null
              ? const LoadingList(height: 120)
              : _plans!.isEmpty
                  ? EmptyState(
                      icon: Icons.event_note_rounded,
                      title: 'No events yet',
                      message: 'Add your event, for one day or several, and Smartie lays out every step with dates.',
                      action: FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('New event')),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _plans!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _PlanCard(_plans![i], onReturn: _load).animate().fadeIn(delay: (40 * i).ms).slideY(begin: 0.06),
                      ),
                    ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.plan, {required this.onReturn});
  final EventPlan plan;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = plan.tasks.length;
    final pct = total == 0 ? 0.0 : plan.doneCount / total;
    final days = dayCount(plan.date, plan.endDate);
    final left = plan.date?.difference(DateTime.now()).inDays;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/events/${plan.id}');
          onReturn();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(plan.date == null ? '--' : '${plan.date!.day}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
                  Text(plan.date == null ? '' : shortDate(plan.date).split(' ')[1].toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5)),
                  const SizedBox(height: 2),
                  Text([plan.eventType, dateRange(plan.date, plan.endDate), if (plan.location.isNotEmpty) plan.location].join(' · '),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5)),
                ]),
              ),
              if (days > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text('$days days', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: p.surface2, color: p.success),
                ),
              ),
              const SizedBox(width: 10),
              Text('${plan.doneCount}/$total done', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            if (left != null && left >= 0) ...[
              const SizedBox(height: 8),
              Text(left == 0 ? 'Today' : '$left days to go', style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Bottom sheet that creates an event over one or several days.
class _NewEventSheet extends StatefulWidget {
  const _NewEventSheet();
  @override
  State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet> {
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _budget = TextEditingController();
  String _type = 'Wedding';
  DateTime? _date;
  int _days = 1;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 730)), initialDate: _date ?? now.add(const Duration(days: 30)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _date == null) {
      showMessage(context, 'Give the event a name and its first day.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.instance.post('/plans', {
        'title': _title.text.trim(),
        'eventType': _type,
        'date': _date!.toIso8601String().substring(0, 10),
        'days': _days,
        'location': _city.text.trim(),
        if (num.tryParse(_budget.text.trim()) != null) 'budget': Money.toBase(num.parse(_budget.text.trim())),
      });
      if (!mounted) return;
      showMessage(context, 'Your event is ready with its checklist.');
      Navigator.pop(context, EventPlan(Map<String, dynamic>.from(res['data'] as Map)));
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final end = _date?.add(Duration(days: _days - 1));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('New event', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _title, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Event name', hintText: 'AI Summit 2027')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'First day', suffixIcon: Icon(Icons.calendar_month_rounded)),
                  child: Text(_date == null ? 'Choose' : shortDate(_date), style: TextStyle(color: _date == null ? p.muted : null)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _DayStepper(days: _days, onChanged: (d) => setState(() => _days = d)),
          ]),
          if (_date != null && _days > 1) ...[
            const SizedBox(height: 6),
            Text(dateRange(_date, end), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City', hintText: 'Lahore'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _budget, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Budget (optional)', prefixText: '${Money.symbol} '))),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
            label: Text(_busy ? 'Planning…' : 'Plan it'),
          ),
        ]),
      ),
    );
  }
}

/// "Number of days" control: minus / count / plus (1 to 30).
class _DayStepper extends StatelessWidget {
  const _DayStepper({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: days > 1 ? () => onChanged(days - 1) : null, icon: const Icon(Icons.remove_rounded), tooltip: 'One day fewer'),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$days', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(days == 1 ? 'day' : 'days', style: TextStyle(color: p.muted, fontSize: 10.5)),
        ]),
        IconButton(onPressed: days < 30 ? () => onChanged(days + 1) : null, icon: const Icon(Icons.add_rounded), tooltip: 'One more day'),
      ]),
    );
  }
}

/// One event: dates, checklist and the services booked for it.
class EventPlanScreen extends StatefulWidget {
  const EventPlanScreen({super.key, required this.id});
  final String id;
  @override
  State<EventPlanScreen> createState() => _EventPlanScreenState();
}

class _EventPlanScreenState extends State<EventPlanScreen> {
  EventPlan? _plan;
  List<Booking> _bookings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.instance.get('/plans/${widget.id}');
      final b = await Api.instance.get('/bookings/my');
      if (!mounted) return;
      setState(() {
        _plan = EventPlan(Map<String, dynamic>.from(res['data'] as Map));
        _bookings = (b['data'] as List? ?? []).whereType<Map>().map((m) => Booking(Map<String, dynamic>.from(m))).where((x) => x.plan?.id == widget.id).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _toggle(PlanTask t) async {
    try {
      final res = await Api.instance.patch('/plans/${widget.id}/tasks/${t.id}', {'status': t.done ? 'todo' : 'done'});
      if (mounted) setState(() => _plan = EventPlan(Map<String, dynamic>.from(res['data'] as Map)));
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  Future<void> _changeDates() async {
    final plan = _plan!;
    DateTime date = plan.date ?? DateTime.now();
    int days = dayCount(plan.date, plan.endDate);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Change dates', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: date);
                    if (d != null) set(() => date = d);
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'First day', suffixIcon: Icon(Icons.calendar_month_rounded)), child: Text(shortDate(date))),
                ),
              ),
              const SizedBox(width: 12),
              _DayStepper(days: days, onChanged: (d) => set(() => days = d)),
            ]),
            const SizedBox(height: 8),
            Text(dateRange(date, date.add(Duration(days: days - 1))), style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save dates')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.instance.put('/plans/${widget.id}', {'date': date.toIso8601String().substring(0, 10), 'days': days});
      if (!mounted) return;
      setState(() => _plan = EventPlan(Map<String, dynamic>.from(res['data'] as Map)));
      showMessage(context, 'Dates updated.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final plan = _plan;
    if (_error != null && plan == null) return Scaffold(appBar: AppBar(), body: ErrorState(message: _error!, onRetry: _load));
    if (plan == null) return Scaffold(appBar: AppBar(), body: const LoadingList(height: 90));
    final agreed = _bookings.where((b) => b.isAgreed).fold<num>(0, (t, b) => t + b.offerPrice);
    final total = plan.tasks.length;
    return Scaffold(
      appBar: AppBar(title: Text(plan.title), actions: [
        IconButton(onPressed: _changeDates, tooltip: 'Change dates', icon: const Icon(Icons.edit_calendar_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.eventType.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(dateRange(plan.date, plan.endDate), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              if (plan.location.isNotEmpty) Text(plan.location, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              Row(children: [
                _Stat(label: 'Booked', value: '${_bookings.length}'),
                _Stat(label: 'Agreed', value: money(agreed)),
                _Stat(label: 'Budget', value: plan.budget == null ? '—' : money(plan.budget)),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          SectionTitle('Bookings for this event'),
          if (_bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing booked yet. Offers you make for this event appear here.', style: TextStyle(color: p.muted)),
            )
          else
            ..._bookings.map((b) => Card(
                  child: ListTile(
                    onTap: () => context.push('/negotiate/${b.id}').then((_) => _load()),
                    leading: Avatar(name: b.vendorName, size: 40),
                    title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(b.vendorName),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(b.offerPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      StatusChip(b.status),
                    ]),
                  ),
                )),
          const SizedBox(height: 18),
          SectionTitle('Checklist · ${plan.doneCount} of $total done'),
          ...plan.tasks.map((t) => Card(
                child: CheckboxListTile(
                  value: t.done,
                  onChanged: (_) => _toggle(t),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(t.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? p.muted : null)),
                  subtitle: Text(
                    [if (t.description.isNotEmpty) t.description, '${t.daysBefore} ${t.daysBefore == 1 ? 'day' : 'days'} before${t.due != null ? ' · due ${shortDate(t.due)}' : ''}'].join('\n'),
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ),
              )),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}
