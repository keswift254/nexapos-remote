import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_storage.dart';
import 'session_storage_native.dart'
    if (dart.library.js_interop) 'session_storage_web.dart' as session_storage;

final sessionStorageProvider = Provider<SessionStorage>(
  (_) => session_storage.createSessionStorage(),
);
