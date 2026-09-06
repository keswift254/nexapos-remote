# NexaPOS 1.0.16

## Windows update handoff

- Fixes `Download & Install` on Windows when the installer requires administrator permission.
- The updater now delegates to the standard Windows UAC `runas` flow instead of attempting an unelevated process launch.
- The existing ZIP update fallback and Android installer flow are unchanged.

## Verification

- `dart analyze lib/domain/services/update_service.dart test/features/update_access_test.dart`
- `flutter test --no-pub test/features/update_access_test.dart`
