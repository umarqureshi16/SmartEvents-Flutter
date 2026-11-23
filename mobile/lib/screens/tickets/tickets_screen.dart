import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

Uint8List? _qrBytes(String? dataUri) {
  if (dataUri == null || !dataUri.contains(',')) return null;
  try {
    return base64Decode(dataUri.split(',').last);
  } catch (_) {
    return null;
  }
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<TicketItem>? _tickets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Api.instance.get('/tickets/my');
      setState(() => _tickets = (res['data'] as List? ?? []).whereType<Map>().map((m) => TicketItem(Map<String, dynamic>.from(m))).toList());
    } catch (e) {
      setState(() => _error = Api.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My passes')),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _tickets == null
              ? const LoadingList(height: 150)
              : _tickets!.isEmpty
                  ? const EmptyState(icon: Icons.qr_code_2_rounded, title: 'No passes yet', message: 'Open an event and tap "Get pass" to add one.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _TicketCard(_tickets![i]),
                      ),
                    ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard(this.t);
  final TicketItem t;

  void _open(BuildContext context) {
    final bytes = _qrBytes(t.qr);
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.event?.title ?? 'Entry pass', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Show this at the gate', style: TextStyle(color: AppPalette.of(context).muted)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: bytes != null ? Image.memory(bytes, width: 240, height: 240, gaplessPlayback: true) : const SizedBox(width: 240, height: 240, child: Icon(Icons.qr_code_2_rounded, size: 120)),
            ),
            const SizedBox(height: 14),
            SelectableText(t.number, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final e = t.event;
    final bytes = _qrBytes(t.qr);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Row(children: [
          Container(
            width: 112,
            height: 132,
            decoration: const BoxDecoration(gradient: AppColors.brandGradient),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: bytes != null ? Image.memory(bytes, width: 76, height: 76) : const Icon(Icons.qr_code_2_rounded, size: 70),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  StatusChip(t.status),
                  const SizedBox(width: 6),
                  Text(t.type.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: p.muted, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 8),
                Text(e?.title ?? 'Event', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text('${dayLabel(e?.date)}${(e?.location ?? '').isNotEmpty ? ' · ${e!.location}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(t.number, style: TextStyle(fontSize: 11, color: p.muted)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
