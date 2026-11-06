// Writes real bcrypt hashes made by the app's own library (package:bcrypt, the same call the app uses when it
// creates a user: BCrypt.hashpw(password, BCrypt.gensalt())) so the old-iPad Lite till's JavaScript bcrypt can be
// proven to verify exactly what the app writes. Run: dart run test/tool/make_bcrypt_fixtures.dart <output.json>
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';

void main(List<String> args) {
  final passwords = ['Passw0rd!', 'admin', '1234', 'a much longer pass phrase with spaces 2026', 'Wanjiru@2026#', 'café-über-€100', ''];
  final out = [
    for (final p in passwords) {'password': p, 'hash': BCrypt.hashpw(p, BCrypt.gensalt())},
  ];
  File(args.isEmpty ? 'bcrypt_fixtures.json' : args.first).writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'made_by': 'package:bcrypt BCrypt.hashpw(password, BCrypt.gensalt())', 'cases': out}));
  stdout.writeln('wrote ${out.length} hashes, e.g. ${out[0]['hash']}');
}
