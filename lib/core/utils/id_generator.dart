import 'package:uuid/uuid.dart';

/// Generates the client-side UUIDs used as primary keys everywhere.
///
/// Injected instead of calling `Uuid().v4()` ad hoc so tests can supply a
/// deterministic sequence. The actual per-install device identifier lives
/// in the `device_meta` table (generated once, persisted) - this class
/// only mints fresh entity IDs.
abstract class IdGenerator {
  String newId();
}

class UuidIdGenerator implements IdGenerator {
  final _uuid = const Uuid();

  @override
  String newId() => _uuid.v4();
}

/// Deterministic generator for tests: returns ids in the exact sequence
/// provided, so assertions can reference a known id instead of a random
/// one.
class SequentialIdGenerator implements IdGenerator {
  final List<String> _ids;
  int _index = 0;

  SequentialIdGenerator(this._ids);

  @override
  String newId() {
    if (_index >= _ids.length) {
      throw StateError('SequentialIdGenerator ran out of ids (${_ids.length} provided).');
    }
    return _ids[_index++];
  }
}
