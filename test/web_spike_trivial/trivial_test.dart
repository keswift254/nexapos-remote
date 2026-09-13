@TestOn('browser')
library;

import 'package:test/test.dart';

/// Zero-dependency canary: if this doesn't pass, don't bother debugging
/// test/web_spike - the browser test infrastructure itself is broken,
/// not anything about drift or this app's code. Run with:
///
///   dart test -p chrome test/web_spike_trivial
///
/// (`flutter test --platform chrome` uses a different, separately
/// maintained Chrome launcher that was found to be unreliable against
/// current Chrome - see project-drive-backup-and-ios-browser-design in
/// memory for the full story. `dart test`'s own launcher worked
/// immediately, in under 6 seconds, the one time this was tried.)
void main() {
  test('trivial web test infra check', () {
    expect(1 + 1, 2);
  });
}
