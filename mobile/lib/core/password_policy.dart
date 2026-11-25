/// The same password rules the server enforces (server/utils/passwordPolicy.js).
class PasswordRule {
  const PasswordRule(this.label, this.ok);
  final String label;
  final bool ok;
}

const _common = [
  'password', 'passw0rd', 'qwerty', 'letmein', 'welcome', 'admin', 'iloveyou',
  'abc123', '123456', '12345678', '11111111', 'monkey', 'dragon', 'football',
  'smartie', 'smartevents',
];

List<PasswordRule> passwordRules(String p, {String name = '', String email = ''}) {
  final lower = p.toLowerCase();
  final personal = [email.split('@').first, ...name.split(RegExp(r'\s+'))]
      .map((w) => w.toLowerCase())
      .where((w) => w.length >= 3);
  return [
    PasswordRule('8 to 128 characters', p.length >= 8 && p.length <= 128),
    PasswordRule('An uppercase letter (A-Z)', RegExp(r'[A-Z]').hasMatch(p)),
    PasswordRule('A lowercase letter (a-z)', RegExp(r'[a-z]').hasMatch(p)),
    PasswordRule('A number (0-9)', RegExp(r'\d').hasMatch(p)),
    PasswordRule('A symbol such as ! @ # \$ %', RegExp(r'[^A-Za-z0-9\s]').hasMatch(p)),
    PasswordRule('No spaces', p.isNotEmpty && !RegExp(r'\s').hasMatch(p)),
    PasswordRule('Not a common password', p.isNotEmpty && !_common.any(lower.contains)),
    PasswordRule('Not your name or email', p.isNotEmpty && !personal.any(lower.contains)),
  ];
}

bool isStrongPassword(String p, {String name = '', String email = ''}) =>
    passwordRules(p, name: name, email: email).every((r) => r.ok);
