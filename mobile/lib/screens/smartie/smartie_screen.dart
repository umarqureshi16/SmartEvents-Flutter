import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';

class _Msg {
  _Msg(this.role, this.text, {this.action, this.error = false});
  final String role; // 'user' | 'bot'
  final String text;
  Map<String, dynamic>? action;
  final bool error;
  bool done = false;
}

/// Smartie, the AI assistant. It answers from the user's own bookings and the
/// live marketplace, and proposes actions that only run after a tap.
class SmartieScreen extends StatefulWidget {
  const SmartieScreen({super.key});
  @override
  State<SmartieScreen> createState() => _SmartieScreenState();
}

class _SmartieScreenState extends State<SmartieScreen> {
  final List<_Msg> _msgs = [];
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;

  List<String> get _starters => context.read<AppState>().user?.isVendor == true
      ? ['Show my open offers', 'How is my trust score calculated?', 'Create a maroon and gold nikah stage design for 800']
      : ['I have 1500 for my nikah in Lahore', 'What are my bookings?', 'Find photographers under 1000'];

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _text.text).trim();
    if (text.isEmpty || _thinking) return;
    setState(() {
      _msgs.add(_Msg('user', text));
      _thinking = true;
    });
    _text.clear();
    _toBottom();
    FirebaseService.instance.logEvent('smartie_question');
    try {
      final history = _msgs.where((m) => !m.error).map((m) => {'role': m.role == 'user' ? 'user' : 'assistant', 'content': m.text}).toList();
      final res = await Api.instance.post('/ai/agent', {'messages': history.length > 30 ? history.sublist(history.length - 30) : history});
      final data = res['data'] as Map? ?? {};
      setState(() => _msgs.add(_Msg('bot', (data['reply'] as String?) ?? 'Done.', action: data['pendingAction'] is Map ? Map<String, dynamic>.from(data['pendingAction'] as Map) : null)));
    } catch (e) {
      setState(() => _msgs.add(_Msg('bot', Api.messageOf(e), error: true)));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  Future<void> _confirm(_Msg m) async {
    final a = m.action!;
    setState(() => _thinking = true);
    try {
      final res = await Api.instance.post('/ai/agent/execute', {'name': a['name'], 'args': a['args']});
      final data = res['data'] as Map? ?? {};
      setState(() {
        m.done = true;
        _msgs.add(_Msg('bot', (data['message'] as String?) ?? 'Done.'));
      });
      FirebaseService.instance.logEvent('smartie_action', {'name': '${a['name']}'});
    } catch (e) {
      setState(() => _msgs.add(_Msg('bot', Api.messageOf(e), error: true)));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final brand = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          const Text('Smartie'),
          const Spacer(),
          IconButton(tooltip: 'Planning tools', onPressed: () => context.push('/planning'), icon: const Icon(Icons.calculate_outlined)),
        ]),
        actions: [
          if (_msgs.isNotEmpty) IconButton(tooltip: 'New conversation', onPressed: () => setState(_msgs.clear), icon: const Icon(Icons.add_comment_outlined)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? ListView(padding: const EdgeInsets.all(24), children: [
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(28)),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.05, duration: 1400.ms),
                  ),
                  const SizedBox(height: 18),
                  Text('Ask Smartie anything', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('Plans a budget, finds vendors, makes offers and answers from your own bookings. Every change waits for your tap.',
                      textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
                  const SizedBox(height: 24),
                  for (final s in _starters)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () => _send(s),
                        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        child: Row(children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 18, color: brand),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                ])
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _msgs.length + (_thinking ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _msgs.length) return const _Typing();
                    final m = _msgs[i];
                    final mine = m.role == 'user';
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: mine ? brand : m.error ? AppColors.danger.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
                          border: mine ? null : Border.all(color: m.error ? AppColors.danger.withValues(alpha: 0.3) : p.border),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SelectableText.rich(_rich(m.text), style: TextStyle(color: mine ? Colors.white : null, height: 1.45)),
                          if (m.action != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: brand.withValues(alpha: 0.3))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('CONFIRM ACTION', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w900, color: brand)),
                                const SizedBox(height: 4),
                                Text('${m.action!['summary'] ?? m.action!['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                if (m.done)
                                  Row(children: [Icon(Icons.check_circle_rounded, color: p.success, size: 18), const SizedBox(width: 6), Text('Done', style: TextStyle(color: p.success, fontWeight: FontWeight.w800))])
                                else
                                  Row(children: [
                                    FilledButton(onPressed: _thinking ? null : () => _confirm(m), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), child: const Text('Confirm')),
                                    const SizedBox(width: 8),
                                    TextButton(onPressed: () => setState(() => m.action = null), child: const Text('Not now')),
                                  ]),
                              ]),
                            ),
                          ],
                        ]),
                      ),
                    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.1);
                  },
                ),
        ),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: p.border))),
          padding: const EdgeInsets.all(8),
          child: SafeArea(
            top: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Ask Smartie…'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(tooltip: 'Send', onPressed: _thinking ? null : _send, icon: const Icon(Icons.arrow_upward_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Renders the **bold** and `code` marks the assistant uses.
TextSpan _rich(String text) {
  final spans = <TextSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(m.group(1) != null
        ? TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800))
        : TextSpan(text: m.group(2), style: const TextStyle(fontFamily: 'monospace')));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(children: spans);
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border.all(color: p.border), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: p.muted, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat()).fadeOut(delay: (i * 150).ms, duration: 600.ms),
        ]),
      ),
    );
  }
}
