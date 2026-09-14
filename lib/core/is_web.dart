/// A tiny, dependency-free platform check for the few call sites (like
/// database.dart's migration hook) that need to branch on native-vs-web
/// but must stay pure Dart on both branches - unlike Flutter's own
/// `kIsWeb` (package:flutter/foundation.dart), importing this pulls in
/// no Flutter framework code, so files that need to keep compiling
/// under plain `dart test` (see test/web_spike) can still use it.
library;

export 'is_web_native.dart' if (dart.library.js_interop) 'is_web_web.dart';
