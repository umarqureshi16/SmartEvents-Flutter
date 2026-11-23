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

/// Calendar days an event covers (1 for a one-day event).
int dayCount(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 1;
  final a = DateTime(start.year, start.month, start.day);
  final b = DateTime(end.year, end.month, end.day);
  final n = b.difference(a).inDays + 1;
  return n < 1 ? 1 : n;
}

/// "23 Jan 2027", or for events over several days "23–25 Jan 2027 · 3 days".
String dateRange(DateTime? start, DateTime? end, {bool withDays = true}) {
  if (start == null) return '';
  final days = dayCount(start, end);
  if (days <= 1 || end == null) return shortDate(start);
  final sameMonth = start.month == end.month && start.year == end.year;
  final sameYear = start.year == end.year;
  final first = sameMonth ? '${start.day}' : DateFormat(sameYear ? 'd MMM' : 'd MMM yyyy').format(start);
  final range = '$first${sameMonth ? '–' : ' – '}${shortDate(end)}';
  return withDays ? '$range · $days days' : range;
}
