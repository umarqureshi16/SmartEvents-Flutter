import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/socket_service.dart';
import '../../core/theme.dart';
import '../../models/models.dart' show idOf;
import '../../state/app_state.dart';
import '../../widgets/common.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

Color? hexColor(String? h) {
  if (h == null) return null;
  final s = h.replaceAll('#', '');
  final full = s.length == 3 ? s.split('').map((c) => '$c$c').join() : s;
  final n = int.tryParse(full, radix: 16);
  return n == null || full.length != 6 ? null : Color(0xFF000000 | n);
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

// ================================================================ booking design studio

/// Both sides of an agreed booking shape the decor together: the brief
/// (theme, style, colours, budget, guests, notes, reference links), three
/// concepts drafted within budget, choosing one, and a design chat.
class BookingDesignScreen extends StatefulWidget {
  const BookingDesignScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingDesignScreen> createState() => _BookingDesignScreenState();
}

class _BookingDesignScreenState extends State<BookingDesignScreen> {
  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');
  Map<String, dynamic>? _d;
  String? _error;
  final _theme = TextEditingController();
  final _style = TextEditingController();
  final _colors = TextEditingController();
  final _budget = TextEditingController();
  final _guests = TextEditingController();
  final _notes = TextEditingController();
  final _refUrl = TextEditingController();
  final _refCaption = TextEditingController();
  final _msg = TextEditingController();
  List<Map<String, dynamic>> _refs = [];
  String? _busy;
  StreamSubscription<LiveEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // The other side's changes arrive live (the brief being edited here is kept).
    SocketService.instance.joinBooking(widget.bookingId);
    final me = context.read<AppState>().user?.id;
    _live = SocketService.instance.events.listen((e) {
      if (e.name == 'design-updated' && '${e.data['bookingId']}' == widget.bookingId && '${e.data['actorId']}' != me) {
        _load(keepBrief: true);
      }
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  void _apply(Map<String, dynamic> d, {bool keepBrief = false}) {
    setState(() {
      _d = d;
      _error = null;
    });
    if (keepBrief) return;
    final b = _m(d['brief']);
    _theme.text = '${b['theme'] ?? ''}';
    _style.text = '${b['style'] ?? ''}';
    _colors.text = ((b['colors'] as List?) ?? []).join(', ');
    final budget = (b['budget'] ?? d['agreedPrice']) as num?;
    _budget.text = budget == null ? '' : '${Money.fromBase(budget)}';
    _guests.text = b['guestCount'] == null ? '' : '${b['guestCount']}';
    _notes.text = '${b['notes'] ?? ''}';
    _refs = _l(b['references']).map((r) => {'url': r['url'], 'caption': r['caption'] ?? ''}).toList();
  }

  Future<void> _load({bool keepBrief = false}) async {
    try {
      final r = await Api.instance.get('/bookings/${widget.bookingId}/design');
      if (mounted) _apply(_m(r['data']), keepBrief: keepBrief);
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  String? _briefError() {
    final colors = _colors.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
    if (colors.length > 8 || !colors.every(_hex.hasMatch)) return 'Colours must be up to 8 hex values such as #c9a227.';
    if (_budget.text.trim().isNotEmpty && (num.tryParse(_budget.text.trim()) ?? -1) < 0) return 'Budget must be a positive number.';
    if (_guests.text.trim().isNotEmpty && (int.tryParse(_guests.text.trim()) ?? -1) < 0) return 'Guests must be a positive number.';
    if (_refs.length > 12) return 'Up to 12 reference images.';
    return null;
  }

  Future<bool> _saveBrief() async {
    final err = _briefError();
    if (err != null) {
      showMessage(context, err, error: true);
      return false;
    }
    setState(() => _busy = 'brief');
    try {
      final r = await Api.instance.put('/bookings/${widget.bookingId}/design/brief', {
        'theme': _theme.text.trim(),
        'style': _style.text.trim(),
        'colors': _colors.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList(),
        'notes': _notes.text.trim(),
        if (_budget.text.trim().isNotEmpty) 'budget': Money.toBase(num.parse(_budget.text.trim())),
        if (_guests.text.trim().isNotEmpty) 'guestCount': int.parse(_guests.text.trim()),
        'references': _refs,
      });
      if (!mounted) return false;
      _apply(_m(r['data']));
      showMessage(context, 'Design brief saved and shared.');
      return true;
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _draft() async {
    if (!await _saveBrief()) return;
    setState(() => _busy = 'draft');
    try {
      final r = await Api.instance.post('/bookings/${widget.bookingId}/design/concepts');
      if (mounted) {
        _apply(_m(r['data']), keepBrief: true);
        showMessage(context, 'Three concepts drafted within your budget.');
      }
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _choose(String conceptId) async {
    setState(() => _busy = conceptId);
    try {
      final r = await Api.instance.put('/bookings/${widget.bookingId}/design/concepts/$conceptId/select');
      if (mounted) {
        _apply(_m(r['data']), keepBrief: true);
        showMessage(context, 'Concept chosen. Both of you will follow this design.');
      }
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _send() async {
    final t = _msg.text.trim();
    if (t.isEmpty) return;
    try {
      final r = await Api.instance.post('/bookings/${widget.bookingId}/design/messages', {'text': t});
      _msg.clear();
      if (mounted) _apply(_m(r['data']), keepBrief: true);
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  void _addRef() {
    final u = _refUrl.text.trim();
    if (!RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(u)) {
      showMessage(context, 'Each reference must be a web link starting with http.', error: true);
      return;
    }
    if (_refs.length >= 12) return showMessage(context, 'Up to 12 reference images.', error: true);
    setState(() => _refs.add({'url': u, 'caption': _refCaption.text.trim()}));
    _refUrl.clear();
    _refCaption.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorState(message: _error!, onRetry: _load));
    final d = _d;
    if (d == null) return Scaffold(appBar: AppBar(), body: const LoadingList(count: 3, height: 120));
    final p = AppPalette.of(context);
    final event = _m(d['event']);
    final concepts = _l(d['concepts']);
    final me = context.watch<AppState>().user?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Design studio'), actions: [
        IconButton(
          tooltip: 'Open in Design Lab',
          onPressed: () => context.push('/design-lab/booking/${widget.bookingId}?eventType=${Uri.encodeComponent('${event['category'] ?? ''}')}&theme=${Uri.encodeComponent(_theme.text)}'),
          icon: const Icon(Icons.brush_rounded),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (event.isNotEmpty) Text('${event['title']} · ${shortDate(parseDate(event['date']))}', style: TextStyle(color: p.muted)),
        Text('Agreed price ${money(d['agreedPrice'] as num?)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SectionTitle('The brief'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              TextField(controller: _theme, maxLength: 120, decoration: const InputDecoration(labelText: 'Theme', hintText: 'Royal Mughal', counterText: '')),
              const SizedBox(height: 10),
              TextField(controller: _style, maxLength: 120, decoration: const InputDecoration(labelText: 'Style', hintText: 'Elegant, floral', counterText: '')),
              const SizedBox(height: 10),
              TextField(
                controller: _colors,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Colours', hintText: '#c9a227, #2f3e46'),
              ),
              const SizedBox(height: 6),
              Row(children: [
                for (final c in _colors.text.split(RegExp(r'[\s,]+')).map(hexColor).whereType<Color>())
                  Container(width: 26, height: 26, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: p.border))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(controller: _budget, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Decor budget', prefixText: '${Money.symbol} ')),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _guests, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Guests'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _notes, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true)),
              Align(alignment: Alignment.centerLeft, child: Text('Reference pictures (${_refs.length}/12)', style: const TextStyle(fontWeight: FontWeight.w700))),
              for (final (i, r) in _refs.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 44, height: 44, child: NetImage('${r['url']}'))),
                  title: Text('${r['caption'] ?? ''}'.isEmpty ? '${r['url']}' : '${r['caption']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(onPressed: () => setState(() => _refs.removeAt(i)), icon: const Icon(Icons.close_rounded, size: 18)),
                ),
              Row(children: [
                Expanded(flex: 3, child: TextField(controller: _refUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Picture link', hintText: 'https://…'))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: TextField(controller: _refCaption, maxLength: 160, decoration: const InputDecoration(labelText: 'Caption', counterText: ''))),
                IconButton(onPressed: _addRef, icon: const Icon(Icons.add_circle_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy != null ? null : _saveBrief, child: Text(_busy == 'brief' ? 'Saving…' : 'Save brief'))),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy != null ? null : _draft,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_busy == 'draft' ? 'Drafting…' : 'Draft 3 concepts'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        if (concepts.isNotEmpty) ...[
          const SectionTitle('Concepts'),
          for (final c in concepts)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: c['selected'] == true ? p.success : p.border, width: c['selected'] == true ? 2 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AspectRatio(aspectRatio: 16 / 9, child: NetImage(Api.absolute('/api/v1/designs/concepts/${widget.bookingId}/${idOf(c)}/image'), icon: Icons.palette_rounded)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${c['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      Text(money(c['totalCost'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ]),
                    if ((c['summary'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c['summary']}', style: TextStyle(color: p.muted))),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final h in (c['palette'] as List? ?? []).map((e) => hexColor('$e')).whereType<Color>())
                        Container(width: 22, height: 22, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: h, shape: BoxShape.circle, border: Border.all(color: p.border))),
                    ]),
                    for (final e in _l(c['elements']).take(6))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Expanded(child: Text('${e['item'] ?? ''}')),
                          Text(money(e['cost'] as num?), style: TextStyle(color: p.muted)),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    c['selected'] == true
                        ? Row(children: [Icon(Icons.check_circle_rounded, color: p.success), const SizedBox(width: 6), const Text('Chosen design', style: TextStyle(fontWeight: FontWeight.w800))])
                        : FilledButton(onPressed: _busy != null ? null : () => _choose(idOf(c)!), child: Text(_busy == idOf(c) ? 'Choosing…' : 'Choose this concept')),
                  ]),
                ),
              ]),
            ),
        ],
        const SectionTitle('Design chat'),
        for (final msg in _l(d['messages']))
          Align(
            alignment: msg['authorId'] == me ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: msg['authorId'] == me ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : p.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${msg['author']} · ${timeAgo(parseDate(msg['createdAt']))}', style: TextStyle(fontSize: 11, color: p.muted)),
                const SizedBox(height: 2),
                Text('${msg['text']}'),
              ]),
            ),
          ),
        Row(children: [
          Expanded(child: TextField(controller: _msg, maxLength: 1000, decoration: const InputDecoration(hintText: 'Message about the design', counterText: ''), onSubmitted: (_) => _send())),
          IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded)),
        ]),
      ]),
    );
  }
}

// ================================================================ Design Lab

/// The Design Lab on a phone: culture-aware inspiration pictures, pinning,
/// and a canvas of pictures, text and shapes, saved to the same board as the
/// website's editor and exported as the board's picture.
class DesignLabScreen extends StatefulWidget {
  const DesignLabScreen({super.key, required this.kind, required this.id, this.eventType, this.theme});
  final String kind; // user | design | booking
  final String id;
  final String? eventType;
  final String? theme;
  @override
  State<DesignLabScreen> createState() => _DesignLabScreenState();
}

const _artboards = {'stage': (1920, 1080, 'Stage (16:9)'), 'square': (1080, 1080, 'Square'), 'story': (1080, 1920, 'Story (9:16)'), 'a4': (1240, 1754, 'A4 page')};

class _DesignLabScreenState extends State<DesignLabScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  final _canvasKey = GlobalKey();
  String _title = 'Design lab';
  List<Map<String, dynamic>> _pins = [];
  Map<String, dynamic> _doc = {'artboard': 'stage', 'width': 1920, 'height': 1080, 'background': '#f5efe6', 'layers': <Map<String, dynamic>>[]};
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;
  String? _selected;
  final List<String> _undo = [];

  // inspiration
  late final _eventType = TextEditingController(text: widget.eventType ?? '');
  late final _themeQ = TextEditingController(text: widget.theme ?? '');
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _results;
  List<String> _queries = [];
  int _page = 1;
  bool _searching = false;

  String get _base => '/designs/boards/${widget.kind}/${widget.id}';
  List<Map<String, dynamic>> get _layers => (_doc['layers'] as List).cast<Map<String, dynamic>>();
  double get _w => ((_doc['width'] as num?) ?? 1920).toDouble();
  double get _h => ((_doc['height'] as num?) ?? 1080).toDouble();

  @override
  void initState() {
    super.initState();
    _load();
    _search();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get(_base);
      final b = _m(r['data']);
      final c = _m(b['canvas']);
      setState(() {
        _title = '${b['title'] ?? 'Design lab'}';
        _pins = _l(b['pins']);
        if (c['layers'] is List) _doc = {..._doc, ...c, 'layers': _l(c['layers'])};
        _loaded = true;
      });
    } catch (e) {
      if (mounted) {
        showMessage(context, Api.messageOf(e), error: true);
        setState(() => _loaded = true);
      }
    }
  }

  Future<void> _search({bool more = false}) async {
    setState(() => _searching = true);
    final page = more ? _page + 1 : 1;
    try {
      final r = await Api.instance.get('/designs/inspiration', query: {
        if (_eventType.text.trim().isNotEmpty) 'eventType': _eventType.text.trim(),
        if (_themeQ.text.trim().isNotEmpty) 'theme': _themeQ.text.trim(),
        if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
        'page': page,
      });
      final d = _m(r['data']);
      final res = _l(d['results']);
      setState(() {
        _queries = (d['queries'] as List? ?? []).map((e) => '$e').toList();
        _page = page;
        _results = more ? [...?_results, ...res.where((x) => !(_results ?? []).any((y) => y['id'] == x['id']))] : res;
      });
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  bool _pinned(Map<String, dynamic> r) => _pins.any((p) => p['id'] == r['id']);

  Future<void> _togglePin(Map<String, dynamic> r) async {
    final next = _pinned(r) ? _pins.where((p) => p['id'] != r['id']).toList() : [r, ..._pins];
    if (next.length > 80) return showMessage(context, 'Up to 80 pinned pictures.', error: true);
    setState(() => _pins = next);
    try {
      await Api.instance.put(_base, {'pins': next});
    } catch (_) {
      if (mounted) showMessage(context, 'Could not save the pinned pictures.', error: true);
    }
  }

  // ---- canvas editing
  void _commit(void Function() change) {
    _undo.add(jsonEncode(_doc));
    if (_undo.length > 50) _undo.removeAt(0);
    setState(() {
      change();
      _dirty = true;
    });
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _doc = Map<String, dynamic>.from(jsonDecode(_undo.removeLast()) as Map);
      _doc['layers'] = _l(_doc['layers']);
      _dirty = true;
    });
  }

  String _uid() => (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFF).toRadixString(36) + math.Random().nextInt(999).toString();

  void _add(Map<String, dynamic> layer) {
    final w = ((layer['width'] as num?) ?? 300).toDouble();
    final h = ((layer['height'] as num?) ?? 200).toDouble();
    final l = {'id': _uid(), 'x': _w / 2 - w / 2, 'y': _h / 2 - h / 2, 'rotation': 0, 'opacity': 1, 'visible': true, 'locked': false, ...layer};
    if (_layers.length >= 400) return showMessage(context, 'A canvas holds up to 400 layers.', error: true);
    _commit(() => _layers.add(l));
    setState(() => _selected = '${l['id']}');
    _tabs.animateTo(2);
  }

  void _addPicture(Map<String, dynamic> r) {
    final w = math.min(700.0, _w * 0.45);
    final ratio = (r['width'] is num && r['height'] is num && (r['width'] as num) > 0) ? (r['height'] as num) / (r['width'] as num) : 0.75;
    _add({'type': 'image', 'name': '${r['title'] ?? 'Picture'}'.substring(0, math.min(40, '${r['title'] ?? 'Picture'}'.length)), 'src': r['full'], 'width': w, 'height': (w * ratio).round(), 'credit': '${r['creator'] ?? ''} (${r['license'] ?? ''})'});
  }

  Future<void> _addText() async {
    final c = TextEditingController();
    final t = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(controller: c, autofocus: true, maxLength: 200, decoration: const InputDecoration(hintText: 'Ayesha & Bilal')),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Add'))],
      ),
    );
    if (t == null || t.isEmpty) return;
    _add({'type': 'text', 'name': t.substring(0, math.min(24, t.length)), 'text': t, 'fontSize': 96, 'fontFamily': 'Georgia', 'fill': '#1f2a44', 'align': 'center', 'width': 900, 'height': 125});
  }

  void _addShape(String type) => _add({
        'type': type,
        'name': titleCase(type),
        'width': type == 'line' ? 600 : 420,
        'height': type == 'line' ? 20 : (type == 'rect' ? 280 : 420),
        'fill': type == 'line' ? null : '#c9a227',
        'stroke': type == 'line' ? '#c9a227' : null,
        'strokeWidth': type == 'line' ? 8 : 0,
        'cornerRadius': type == 'rect' ? 24 : 0,
      });

  Map<String, dynamic>? get _sel => _layers.where((l) => '${l['id']}' == _selected).firstOrNull;

  void _update(String key, dynamic value) => _commit(() => _sel?[key] = value);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.instance.put(_base, {'canvas': _doc});
      setState(() => _dirty = false);
      if (mounted) showMessage(context, 'Design saved.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Exports the canvas as a PNG and saves it as the board's picture (for a
  /// vendor design it also becomes the design's picture), like the website.
  Future<void> _export() async {
    setState(() {
      _selected = null;
      _saving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: (1600 / boundary.size.width).clamp(1, 4));
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final data = 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
      if (_dirty) await Api.instance.put(_base, {'canvas': _doc});
      final r = await Api.instance.put('$_base/preview', {'dataUrl': data});
      if (mounted) {
        setState(() => _dirty = false);
        showMessage(context, _m(r['data'])['designPicture'] == true ? 'Saved. This is now the design\'s picture.' : 'Saved with a picture of the design.');
      }
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirmDialog(context, title: 'Leave without saving?', message: 'Your latest changes to the canvas are not saved.', confirm: 'Leave', danger: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (popped, _) async {
        if (!popped && await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(tooltip: 'Undo', onPressed: _undo.isEmpty ? null : _undoLast, icon: const Icon(Icons.undo_rounded)),
            IconButton(tooltip: 'Save', onPressed: _saving ? null : _save, icon: Icon(_dirty ? Icons.save_rounded : Icons.cloud_done_rounded)),
            IconButton(tooltip: 'Save with picture', onPressed: _saving ? null : _export, icon: const Icon(Icons.image_rounded)),
          ],
          bottom: TabBar(controller: _tabs, tabs: [const Tab(text: 'Ideas'), Tab(text: 'Pinned (${_pins.length})'), const Tab(text: 'Canvas')]),
        ),
        body: !_loaded
            ? const LoadingList(count: 3, height: 120)
            : TabBarView(controller: _tabs, physics: const NeverScrollableScrollPhysics(), children: [_ideas(), _pinnedView(), _canvasView()]),
      ),
    );
  }

  Widget _pictureGrid(List<Map<String, dynamic>> items) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final r = items[i];
          final pinned = _pinned(r);
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              NetImage(Api.absolute('${r['thumb']}'), icon: Icons.image_outlined),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  child: Text('${r['creator'] ?? ''} · ${r['license'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Column(children: [
                  IconButton.filledTonal(
                    tooltip: pinned ? 'Unpin' : 'Pin',
                    onPressed: () => _togglePin(r),
                    icon: Icon(pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 18),
                  ),
                  IconButton.filledTonal(tooltip: 'Add to canvas', onPressed: () => _addPicture(r), icon: const Icon(Icons.add_photo_alternate_rounded, size: 18)),
                ]),
              ),
            ]),
          );
        },
      );

  Widget _ideas() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            Expanded(child: TextField(controller: _eventType, decoration: const InputDecoration(labelText: 'Event', isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _themeQ, decoration: const InputDecoration(labelText: 'Theme', isDense: true))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search ideas, e.g. marigold stage',
              isDense: true,
              suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
            ),
          ),
        ),
        if (_queries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text('Looking for: ${_queries.join(' · ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted)),
          ),
        Expanded(
          child: _results == null
              ? const Center(child: CircularProgressIndicator())
              : _results!.isEmpty
                  ? const EmptyState(icon: Icons.image_search_rounded, title: 'No pictures found', message: 'Try other words.')
                  : NotificationListener<ScrollEndNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 300 && !_searching && _page < 10) _search(more: true);
                        return false;
                      },
                      child: _pictureGrid(_results!),
                    ),
        ),
      ]);

  Widget _pinnedView() => _pins.isEmpty
      ? const EmptyState(icon: Icons.push_pin_outlined, title: 'Nothing pinned yet', message: 'Pin pictures you like under Ideas to keep them with this board.')
      : _pictureGrid(_pins);

  Widget _canvasView() {
    final p = AppPalette.of(context);
    final sel = _sel;
    return Column(children: [
      // Toolbar
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), children: [
          ActionChip(avatar: const Icon(Icons.title_rounded, size: 18), label: const Text('Text'), onPressed: _addText),
          const SizedBox(width: 6),
          for (final (t, icon) in const [('rect', Icons.crop_square_rounded), ('ellipse', Icons.circle_outlined), ('line', Icons.horizontal_rule_rounded)]) ...[
            ActionChip(avatar: Icon(icon, size: 18), label: Text(titleCase(t == 'rect' ? 'panel' : t == 'ellipse' ? 'circle' : t)), onPressed: () => _addShape(t)),
            const SizedBox(width: 6),
          ],
          ActionChip(avatar: const Icon(Icons.format_color_fill_rounded, size: 18), label: const Text('Background'), onPressed: () => _pickColor('#background')),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Canvas size',
            onSelected: (k) => _commit(() {
              final a = _artboards[k]!;
              _doc['artboard'] = k;
              _doc['width'] = a.$1;
              _doc['height'] = a.$2;
            }),
            itemBuilder: (_) => [for (final e in _artboards.entries) PopupMenuItem(value: e.key, child: Text(e.value.$3))],
            child: Chip(avatar: const Icon(Icons.aspect_ratio_rounded, size: 18), label: Text(_artboards[_doc['artboard']]?.$3 ?? 'Size')),
          ),
        ]),
      ),
      // Artboard
      Expanded(
        child: Container(
          color: p.surface2,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (context, box) {
            final k = math.min(box.maxWidth / _w, box.maxHeight / _h);
            return GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  width: _w * k,
                  height: _h * k,
                  decoration: BoxDecoration(color: hexColor('${_doc['background']}') ?? Colors.white, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)]),
                  child: Stack(clipBehavior: Clip.hardEdge, children: [
                    for (final l in _layers.where((l) => l['visible'] != false)) _layerWidget(l, k),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
      // Selected layer controls
      if (sel != null)
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text('${sel['name'] ?? titleCase('${sel['type']}')}', style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              if (sel['type'] != 'image') IconButton(tooltip: 'Colour', onPressed: () => _pickColor(sel['type'] == 'line' ? 'stroke' : 'fill'), icon: const Icon(Icons.palette_rounded)),
              if (sel['type'] == 'text') IconButton(tooltip: 'Edit text', onPressed: _editText, icon: const Icon(Icons.edit_rounded)),
              IconButton(tooltip: 'Bring forward', onPressed: () => _commit(() {
                final i = _layers.indexOf(sel);
                if (i < _layers.length - 1) _layers.insert(i + 1, _layers.removeAt(i));
              }), icon: const Icon(Icons.flip_to_front_rounded)),
              IconButton(tooltip: 'Delete', onPressed: () {
                _commit(() => _layers.remove(sel));
                setState(() => _selected = null);
              }, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger)),
            ]),
            Row(children: [
              const SizedBox(width: 56, child: Text('Size', style: TextStyle(fontSize: 12))),
              Expanded(
                child: Slider(
                  value: (((sel['width'] as num?) ?? 300) / _w).clamp(0.03, 1.5).toDouble(),
                  min: 0.03,
                  max: 1.5,
                  onChanged: (v) => setState(() {
                    final oldW = ((sel['width'] as num?) ?? 300).toDouble();
                    final ratio = ((sel['height'] as num?) ?? 200) / oldW;
                    sel['width'] = v * _w;
                    sel['height'] = v * _w * ratio;
                    if (sel['type'] == 'text') sel['fontSize'] = (sel['height'] as num) / 1.3;
                    _dirty = true;
                  }),
                ),
              ),
            ]),
            Row(children: [
              const SizedBox(width: 56, child: Text('Turn', style: TextStyle(fontSize: 12))),
              Expanded(
                child: Slider(
                  value: (((sel['rotation'] as num?) ?? 0).toDouble()).clamp(-180, 180),
                  min: -180,
                  max: 180,
                  onChanged: (v) => setState(() {
                    sel['rotation'] = v.roundToDouble();
                    _dirty = true;
                  }),
                ),
              ),
            ]),
            Row(children: [
              const SizedBox(width: 56, child: Text('Opacity', style: TextStyle(fontSize: 12))),
              Expanded(
                child: Slider(
                  value: (((sel['opacity'] as num?) ?? 1).toDouble()).clamp(0.1, 1),
                  min: 0.1,
                  max: 1,
                  onChanged: (v) => setState(() {
                    sel['opacity'] = v;
                    _dirty = true;
                  }),
                ),
              ),
            ]),
          ]),
        ),
    ]);
  }

  Widget _layerWidget(Map<String, dynamic> l, double k) {
    final x = ((l['x'] as num?) ?? 0) * k;
    final y = ((l['y'] as num?) ?? 0) * k;
    final w = ((l['width'] as num?) ?? 100) * k;
    final h = ((l['height'] as num?) ?? 100) * k;
    final selected = '${l['id']}' == _selected;
    final fill = hexColor(l['fill'] as String?);
    final stroke = hexColor(l['stroke'] as String?);
    Widget child;
    switch (l['type']) {
      case 'image':
        child = NetImage(Api.absolute('${l['src']}'), fit: BoxFit.fill, icon: Icons.image_outlined);
      case 'text':
        child = FittedBox(
          fit: BoxFit.contain,
          child: Text('${l['text'] ?? ''}',
              textAlign: l['align'] == 'left' ? TextAlign.left : (l['align'] == 'right' ? TextAlign.right : TextAlign.center),
              style: TextStyle(
                color: fill ?? Colors.black,
                fontSize: ((l['fontSize'] as num?) ?? 72).toDouble(),
                fontFamily: '${l['fontFamily'] ?? ''}'.contains('Georgia') ? 'serif' : null,
                fontWeight: '${l['fontStyle'] ?? ''}'.contains('bold') ? FontWeight.w800 : FontWeight.w500,
                fontStyle: '${l['fontStyle'] ?? ''}'.contains('italic') ? FontStyle.italic : FontStyle.normal,
              )),
        );
      case 'ellipse':
        child = DecoratedBox(decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: stroke == null ? null : Border.all(color: stroke, width: ((l['strokeWidth'] as num?) ?? 0) * k)));
      case 'line':
        child = Center(child: Container(height: math.max(1, ((l['strokeWidth'] as num?) ?? 6) * k), decoration: BoxDecoration(color: stroke ?? fill ?? Colors.black, borderRadius: BorderRadius.circular(99))));
      case 'arch':
        child = DecoratedBox(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.vertical(top: Radius.circular(w / 2))));
      case 'star':
        child = Icon(Icons.star_rounded, color: fill, size: math.min(w, h));
      default:
        child = DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(((l['cornerRadius'] as num?) ?? 0) * k),
            border: stroke == null || ((l['strokeWidth'] as num?) ?? 0) == 0 ? null : Border.all(color: stroke, width: ((l['strokeWidth'] as num?) ?? 0) * k),
          ),
        );
    }
    return Positioned(
      left: x,
      top: y,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: ((l['rotation'] as num?) ?? 0) * math.pi / 180,
        child: Opacity(
          opacity: (((l['opacity'] as num?) ?? 1).toDouble()).clamp(0, 1),
          child: GestureDetector(
            onTap: () => setState(() => _selected = '${l['id']}'),
            onPanStart: l['locked'] == true
                ? null
                : (_) {
                    _undo.add(jsonEncode(_doc));
                    setState(() => _selected = '${l['id']}');
                  },
            onPanUpdate: l['locked'] == true
                ? null
                : (dt) => setState(() {
                      l['x'] = ((l['x'] as num?) ?? 0) + dt.delta.dx / k;
                      l['y'] = ((l['y'] as num?) ?? 0) + dt.delta.dy / k;
                      _dirty = true;
                    }),
            child: Container(
              foregroundDecoration: selected ? BoxDecoration(border: Border.all(color: const Color(0xFF6366F1), width: 2)) : null,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editText() async {
    final sel = _sel;
    if (sel == null) return;
    final c = TextEditingController(text: '${sel['text'] ?? ''}');
    final t = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit text'),
        content: TextField(controller: c, autofocus: true, maxLength: 200),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Save'))],
      ),
    );
    if (t != null && t.isNotEmpty) _update('text', t);
  }

  Future<void> _pickColor(String key) async {
    const swatches = ['#f5efe6', '#ffffff', '#1f2a44', '#000000', '#c9a227', '#b8860b', '#e11d48', '#be185d', '#7c3aed', '#4f46e5', '#0ea5e9', '#046c4e', '#16a34a', '#f59e0b', '#ea580c', '#78350f'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final s in swatches)
              InkWell(
                onTap: () => Navigator.pop(c, s),
                child: Container(width: 44, height: 44, decoration: BoxDecoration(color: hexColor(s), shape: BoxShape.circle, border: Border.all(color: AppPalette.of(context).border))),
              ),
          ]),
        ),
      ),
    );
    if (picked == null) return;
    if (key == '#background') {
      _commit(() => _doc['background'] = picked);
    } else {
      _update(key, picked);
    }
  }
}
