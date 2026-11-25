import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Money in the user's own currency, the same way the website shows it.
///
/// Amounts are stored in US dollars. Each user sees and types them in the
/// currency of the country in their profile, using the server's daily rates
/// (GET /locale). Until those rates arrive (or on a server without them) the
/// app shows dollars, so it never shows a converted price it cannot back up.
class Money {
  Money._();

  static const _fallbackRates = <String, num>{'USD': 1, 'PKR': 280, 'AED': 3.6725, 'SAR': 3.75, 'QAR': 3.64, 'GBP': 0.78, 'CAD': 1.38, 'AUD': 1.52};
  static const _fallbackCurrencies = <String, String>{'PK': 'PKR', 'AE': 'AED', 'SA': 'SAR', 'QA': 'QAR', 'GB': 'GBP', 'US': 'USD', 'CA': 'CAD', 'AU': 'AUD'};
  static const _symbols = <String, String>{'PKR': 'Rs', 'AED': 'AED', 'SAR': 'SAR', 'QAR': 'QAR', 'GBP': '£', 'USD': '\$', 'CAD': 'CA\$', 'AUD': 'A\$'};

  static final Map<String, num> _rates = Map.of(_fallbackRates);
  static final Map<String, String> _currencies = Map.of(_fallbackCurrencies);
  static bool _serverRates = false;
  static String? _country;

  static String currency = 'USD';
  static num rate = 1;

  static String get symbol => _symbols[currency] ?? currency;

  /// The server's countries and today's rates (the `data` of GET /locale).
  static void loadRates(Map? data) {
    if (data == null) return;
    final rates = data['rates'];
    if (rates is Map) {
      rates.forEach((k, v) {
        if (v is num && v > 0) _rates['$k'] = v;
      });
    }
    final countries = data['countries'];
    if (countries is Map) {
      countries.forEach((code, c) {
        if (c is Map && c['currency'] is String) _currencies['$code'] = c['currency'] as String;
      });
    }
    _serverRates = true;
    _apply();
  }

  /// The signed-in user's country (user.locale.country), or null when signed out (Pakistan).
  static void setCountry(String? country) {
    _country = country;
    _apply();
  }

  static void _apply() {
    // Like the website, people without a country (signed out) see Pakistan's currency.
    final cur = _serverRates ? _currencies[_country ?? 'PK'] : null;
    currency = cur ?? 'USD';
    rate = _rates[currency] ?? 1;
  }

  /// Dollars (stored) -> the user's currency, as a whole number.
  static int fromBase(num? usd) => ((usd ?? 0) * rate).round();

  /// The user's currency (typed) -> dollars, for sending to the server.
  static num toBase(num local) => (local / rate * 100).round() / 100;

  /// A round step of about 50 dollars in the user's currency (for +/- buttons).
  static int get step {
    final x = 50 * rate;
    final mag = math.pow(10, (math.log(x) / math.ln10).floor());
    return math.max(1, ((x / mag).round() * mag).round());
  }

  /// Formats an amount that is already in the user's currency.
  static String formatLocal(num value) => '$symbol ${NumberFormat.decimalPattern().format(value.round())}';
}

/// Formats a stored dollar amount in the user's currency, e.g. "Rs 1,260,000".
String money(num? n) => Money.formatLocal(Money.fromBase(n));

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
