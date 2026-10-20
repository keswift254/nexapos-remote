import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/web_update_stub.dart'
    if (dart.library.js_interop) '../../core/web_update_web.dart';

/// Whether this is the browser build - a provider (not just [kIsWeb]) so tests can
/// show the web version of the Software Update screen.
final isWebPlatformProvider = Provider<bool>((ref) => kIsWeb);

/// How the page is told to update itself; replaced in tests.
typedef WebRefresh = Future<String?> Function({
  void Function(double? fraction, String phrase)? onProgress,
});

final webRefreshProvider = Provider<WebRefresh>((ref) => refreshWebApplication);

class WebUpdateState {
  const WebUpdateState({
    this.running = false,
    this.progress,
    this.phrase = '',
    this.error,
  });

  /// True from the tap on "Download & Install" until the page restarts. It stays true
  /// after the download ends, so the button cannot be tapped into a second update.
  final bool running;

  /// 0..1, or null while it is not known yet.
  final double? progress;
  final String phrase;
  final String? error;
}

/// Owns the browser update, not a widget: the Software Update screen can rebuild (a
/// re-check swaps its content for a spinner, the user can leave and come back) and
/// the progress goes on showing, and a tap can never start a second download.
/// Never auto-disposed, for the same reason.
class WebUpdateNotifier extends Notifier<WebUpdateState> {
  @override
  WebUpdateState build() => const WebUpdateState();

  Future<void> start() async {
    if (state.running) return;
    state = const WebUpdateState(running: true, phrase: 'Starting…');
    String? problem;
    try {
      problem = await ref.read(webRefreshProvider)(
        onProgress: (fraction, phrase) {
          if (!ref.mounted || !state.running) return;
          final before = state.progress ?? 0;
          state = WebUpdateState(
            running: true,
            // Only ever forward: a retried file must not make the bar jump back.
            progress: fraction == null
                ? state.progress
                : (fraction > before ? fraction : before),
            phrase: phrase,
          );
        },
      );
    } catch (_) {
      problem = 'The update did not work. Check your internet connection and try again.';
    }
    if (!ref.mounted) return;
    state = problem == null
        // The page is restarting on the new version.
        ? const WebUpdateState(
            running: true,
            progress: 1,
            phrase: 'Restarting…',
          )
        : WebUpdateState(error: '$problem Your shop data is safe.');
  }
}

final webUpdateProvider = NotifierProvider<WebUpdateNotifier, WebUpdateState>(
  WebUpdateNotifier.new,
);
