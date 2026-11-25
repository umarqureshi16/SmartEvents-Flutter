import 'password_policy.dart';

/// Form checks that match the server's rules (server/utils/validation.js),
/// so people see the problem next to the field instead of after sending.
class V {
  V._();

  static final _email = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$");

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your email address';
    return _email.hasMatch(s) ? null : 'Enter a valid email address';
  }

  /// Names: 2 to 50 characters (sign-up and profile).
  static String? name(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 2) return 'Name must be at least 2 characters';
    if (s.length > 50) return 'Name can be at most 50 characters';
    return null;
  }

  static String? required(String? v, String message) => (v ?? '').trim().isEmpty ? message : null;

  /// Text with a minimum and maximum length.
  static String? length(String? v, {required int min, int? max, required String label}) {
    final s = (v ?? '').trim();
    if (s.length < min) return min <= 1 ? '$label is required' : '$label must be at least $min characters';
    if (max != null && s.length > max) return '$label can be at most $max characters';
    return null;
  }

  /// A whole amount greater than zero (prices and offers).
  static String? positive(String? v, {String label = 'Price'}) {
    final n = num.tryParse((v ?? '').trim());
    if (n == null) return 'Enter the ${label.toLowerCase()}';
    return n > 0 ? null : '$label must be greater than zero';
  }

  /// A number that may be zero but not negative.
  static String? nonNegative(String? v, {String label = 'Price', bool optional = false}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return optional ? null : 'Enter the ${label.toLowerCase()}';
    final n = num.tryParse(s);
    if (n == null) return 'Enter a number';
    return n < 0 ? '$label cannot be negative' : null;
  }

  /// A new password (sign-up, reset, change): every policy rule must pass.
  static String? newPassword(String? v, {String name = '', String email = ''}) {
    final p = v ?? '';
    if (p.isEmpty) return 'Choose a password';
    final broken = passwordRules(p, name: name, email: email).where((r) => !r.ok).toList();
    if (broken.isEmpty) return null;
    final l = broken.first.label;
    return 'Password needs: ${l[0].toLowerCase()}${l.substring(1)}';
  }
}
