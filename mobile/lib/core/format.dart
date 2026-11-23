import 'package:intl/intl.dart';

String money(num? n) => '\$${NumberFormat.decimalPattern().format((n ?? 0).round())}';

DateTime? parseDate(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

String dayLabel(DateTime? d) => d == null ? '' : DateFormat('EEE, d MMM yyyy').format(d);
String shortDate(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy').format(d);
String timeLabel(DateTime? d) => d == null ? '' : DateFormat('h:mm a').format(d);

String timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return shortDate(d);
}

String titleCase(String? s) {
  if (s == null || s.isEmpty) return '';
  return s.split(RegExp(r'[\s_]+')).map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

String initials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}
