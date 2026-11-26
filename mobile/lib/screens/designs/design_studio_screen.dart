import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

const _designEvents = ['Wedding', 'Nikah', 'Mehndi', 'Walima', 'Birthday', 'Corporate', 'Conference'];
const _maxParts = 4;

/// Vendor design studio: Smartie drafts three options for a theme (or the
/// vendor's own idea), each with pictures of the full setup and its pieces.
class DesignStudioScreen extends StatefulWidget {
  const DesignStudioScreen({super.key});
  @override
  State<DesignStudioScreen> createState() => _DesignStudioScreenState();
}

class _DesignStudioScreenState extends State<DesignStudioScreen> {
  List<DesignItem>? _designs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/designs/mine');
      if (!mounted) return;
      setState(() => _designs = (res['data'] as List? ?? []).whereType<Map>().map((m) => DesignItem(Map<String, dynamic>.from(m))).toList());
    } catch (e) {
      if (mounted) setState(() => _error = Api.messageOf(e));
    }
  }

  Future<void> _create() async {
    final made = await showModalBottomSheet<List<DesignItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateSheet(),
    );
    if (made != null && made.isNotEmpty && mounted) setState(() => _designs = [...made, ...?_designs]);
  }

  Future<void> _delete(DesignItem d) async {
    if (!await confirmDialog(context, title: 'Delete "${d.title}"?', message: 'It is removed from your designs and your profile.', confirm: 'Delete', danger: true)) return;
    try {
      await Api.instance.delete('/designs/${d.id}');
      if (mounted) setState(() => _designs = _designs!.where((x) => x.id != d.id).toList());
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  Future<void> _togglePublish(DesignItem d) async {
    try {
      final res = await Api.instance.put('/designs/${d.id}', {'published': !d.published});
      if (!mounted) return;
      final updated = DesignItem(Map<String, dynamic>.from(res['data'] as Map));
      setState(() => _designs = _designs!.map((x) => x.id == d.id ? updated : x).toList());
      showMessage(context, updated.published ? 'Published on your profile.' : 'Hidden from your profile.');
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design studio')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Create 3 options')),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _designs == null
              ? const LoadingList(height: 260)
              : _designs!.isEmpty
                  ? EmptyState(
                      icon: Icons.palette_outlined,
                      title: 'No designs yet',
                      message: 'Describe a theme, or your own idea, and Smartie drafts three options with pictures.',
                      action: FilledButton.icon(onPressed: _create, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Create 3 options')),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _designs!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => _DesignCard(_designs![i], onPublish: () => _togglePublish(_designs![i]), onChanged: _load, onDelete: () => _delete(_designs![i])).animate().fadeIn(delay: (50 * i).ms),
                      ),
                    ),
    );
  }
}

Color? _hex(String v) {
  final h = v.replaceAll('#', '');
  final full = h.length == 3 ? h.split('').map((c) => '$c$c').join() : h;
  final n = int.tryParse(full, radix: 16);
  return n == null || full.length != 6 ? null : Color(0xFF000000 | n);
}

class _DesignCard extends StatefulWidget {
  const _DesignCard(this.d, {required this.onPublish, required this.onChanged, required this.onDelete});
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final DesignItem d;
  final VoidCallback onPublish;
  @override
  State<_DesignCard> createState() => _DesignCardState();
}

class _DesignCardState extends State<_DesignCard> {
  Future<void> _more(String action) async {
    final d = widget.d;
    switch (action) {
      case 'render':
        showMessage(context, 'Creating a new picture of this design…');
        try {
          final r = await Api.instance.post('/designs/${d.id}/render');
          if (!mounted) return;
          if ((r['data'] as Map?)?['rendered'] == true) {
            showMessage(context, 'New picture created.');
            widget.onChanged();
          } else {
            showMessage(context, 'The image service is busy. Try again in a minute.', error: true);
          }
        } catch (e) {
          if (mounted) showMessage(context, Api.messageOf(e), error: true);
        }
      case 'gallery':
        try {
          await Api.instance.post('/designs/${d.id}/gallery', {'part': 0});
          if (mounted) showMessage(context, 'Added to the gallery on your profile.');
        } catch (e) {
          if (mounted) showMessage(context, Api.messageOf(e), error: true);
        }
      case 'lab':
        await context.push('/design-lab/design/${d.id}?eventType=${Uri.encodeComponent(d.eventType)}&theme=${Uri.encodeComponent(d.theme)}');
        widget.onChanged();
      case 'delete':
        widget.onDelete();
    }
  }

  int _part = 0;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final p = AppPalette.of(context);
    final items = d.elements.where((e) => (e['item'] ?? '').toString().isNotEmpty).take(_maxParts - 1).toList();
    final labels = ['Full setup', ...items.map((e) => '${e['item']}')];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FullPicture(design: d, labels: labels, start: _part))),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              _RetryingImage(key: ValueKey('${d.id}-$_part'), url: d.partUrl(_part)),
              Positioned(
                left: 10,
                top: 10,
                child: _Pill(d.published ? 'PUBLISHED' : 'DRAFT', color: d.published ? p.success : Colors.black54),
              ),
              const Positioned(right: 10, top: 10, child: _Pill('TAP TO ENLARGE', color: Colors.black54, icon: Icons.open_in_full_rounded)),
            ]),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(labels[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              selected: _part == i,
              onSelected: (_) => setState(() => _part = i),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              Text(money(d.totalCost), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: p.success)),
            ]),
            if ([d.eventType, d.theme].any((s) => s.isNotEmpty))
              Text([d.eventType, d.theme].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            if (d.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(d.summary, style: TextStyle(color: p.muted, height: 1.35)),
            ],
            if (d.palette.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: d.palette.map(_hex).whereType<Color>().map((c) => Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: p.border)),
                  )).toList()),
            ],
            const SizedBox(height: 10),
            ...d.elements.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: p.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${e['item']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(num.tryParse('${e['cost']}')), style: TextStyle(color: p.muted)),
                  ]),
                )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: d.published
                    ? OutlinedButton.icon(onPressed: widget.onPublish, icon: const Icon(Icons.visibility_off_outlined), label: const Text('Unpublish'))
                    : FilledButton.icon(onPressed: widget.onPublish, icon: const Icon(Icons.publish_rounded), label: const Text('Publish on my profile')),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (a) => _more(a),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'render', child: Text('Create a new picture')),
                  PopupMenuItem(value: 'gallery', child: Text('Add picture to my gallery')),
                  PopupMenuItem(value: 'lab', child: Text('Open in Design Lab')),
                  PopupMenuItem(value: 'delete', child: Text('Delete design')),
                ],
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: Colors.white), const SizedBox(width: 4)],
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
        ]),
      );
}

/// The server makes a picture the first time it is asked for, which can take
/// a while; this keeps asking (with a shimmer) until it is ready.
class _RetryingImage extends StatefulWidget {
  const _RetryingImage({super.key, required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;
  @override
  State<_RetryingImage> createState() => _RetryingImageState();
}

class _RetryingImageState extends State<_RetryingImage> {
  int _attempt = 0;
  bool _gaveUp = false;

  String get _src => _attempt == 0 ? widget.url : '${widget.url}${widget.url.contains('?') ? '&' : '?'}try=$_attempt';

  void _retry() {
    if (_attempt >= 30) {
      if (mounted) setState(() => _gaveUp = true);
      return;
    }
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gaveUp) return const NetImage(null, icon: Icons.palette_rounded, label: 'Picture not ready yet');
    return Stack(fit: StackFit.expand, children: [
      const ShimmerBox(),
      Image.network(
        _src,
        key: ValueKey(_src),
        fit: widget.fit,
        frameBuilder: (_, child, frame, sync) => AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 400), child: child),
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _retry());
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Creating picture…', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        },
      ),
    ]);
  }
}

class _FullPicture extends StatefulWidget {
  const _FullPicture({required this.design, required this.labels, required this.start});
  final DesignItem design;
  final List<String> labels;
  final int start;
  @override
  State<_FullPicture> createState() => _FullPictureState();
}

class _FullPictureState extends State<_FullPicture> {
  late final PageController _pages = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.design.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(widget.labels[_i], style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.labels.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(child: AspectRatio(aspectRatio: 16 / 10, child: _RetryingImage(url: widget.design.partUrl(i), fit: BoxFit.contain))),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(widget.labels.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _i ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(color: i == _i ? Colors.white : Colors.white30, borderRadius: BorderRadius.circular(9)),
              ))),
        ),
      ),
    );
  }
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet();
  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _theme = TextEditingController();
  final _style = TextEditingController();
  final _price = TextEditingController();
  final _colors = TextEditingController();
  final _idea = TextEditingController();
  String _event = 'Wedding';
  bool _busy = false;
  bool _themesBusy = false;
  List<Map<String, dynamic>> _themes = [];

  /// Theme ideas for the event (and the idea, if given), like the website's design wizard.
  Future<void> _suggest() async {
    setState(() => _themesBusy = true);
    try {
      final r = await Api.instance.post('/designs/themes', {'eventType': _event, if (_idea.text.trim().isNotEmpty) 'idea': _idea.text.trim()});
      final list = ((r['data'] as Map?)?['themes'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      if (mounted) setState(() => _themes = list);
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _themesBusy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_theme, _style, _price, _colors, _idea]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    final price = num.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      showMessage(context, 'Give the price the design should come to.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.instance.post('/designs/generate', {
        'theme': _theme.text.trim(),
        'style': _style.text.trim(),
        'eventType': _event,
        'budget': Money.toBase(price),
        'colors': _colors.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList(),
        'idea': _idea.text.trim(),
        'count': 3,
      });
      final data = res['data'];
      final list = (data is List ? data : [data]).whereType<Map>().map((m) => DesignItem(Map<String, dynamic>.from(m))).toList();
      if (!mounted) return;
      showMessage(context, '${list.length} options drafted. Pictures appear one by one.');
      Navigator.pop(context, list);
    } catch (e) {
      if (mounted) showMessage(context, Api.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('New design', style: Theme.of(context).textTheme.titleLarge),
          Text('Smartie makes three different options, each with pictures of the full setup and its main pieces.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 16),
          TextField(controller: _theme, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Theme', hintText: 'Mughal garden, Spider-Man…')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _event,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _designEvents.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _event = v ?? _event),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price', prefixText: '${Money.symbol} '))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _style, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Style', hintText: 'Royal'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _colors, decoration: const InputDecoration(labelText: 'Colours', hintText: 'maroon, gold'))),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _idea,
            minLines: 2,
            maxLines: 4,
            maxLength: 600,
            decoration: const InputDecoration(labelText: 'Your own design idea (optional)', hintText: 'City skyline backdrop, spider web ceiling, red and blue balloon arch…'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _themesBusy ? null : _suggest,
              icon: const Icon(Icons.lightbulb_outline_rounded),
              label: Text(_themesBusy ? 'Thinking…' : 'Suggest themes for $_event'),
            ),
          ),
          if (_themes.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _themes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = _themes[i];
                  final palette = (t['palette'] as List? ?? []).map((e) => _hex('$e')).whereType<Color>().toList();
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() {
                      _theme.text = '${t['name'] ?? ''}';
                      _style.text = '${t['style'] ?? ''}';
                      _colors.text = (t['palette'] as List? ?? []).join(', ');
                    }),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border.all(color: AppPalette.of(context).border), borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${t['mood'] ?? t['style'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted)),
                        const Spacer(),
                        Row(children: [for (final c in palette.take(5)) Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: c, shape: BoxShape.circle))]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _go,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
            label: Text(_busy ? 'Designing…' : 'Create 3 options'),
          ),
        ]),
      ),
    );
  }
}
