// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Current logged-in user as reactive state, persisted via
/// flutter_secure_storage so app resume behaves like PHP's session
/// cookie. Role checks are enforced here at the use-case boundary, not
/// just by hiding buttons - on a phone there's no separate server tier
/// to fall back on the way Auth::requireRole() protects a PHP route
/// even if the UI is bypassed. go_router's redirect guard calls [can]
/// too, so there is exactly one source of truth for "who can do what".

@ProviderFor(SessionNotifier)
final sessionProvider = SessionNotifierProvider._();

/// Current logged-in user as reactive state, persisted via
/// flutter_secure_storage so app resume behaves like PHP's session
/// cookie. Role checks are enforced here at the use-case boundary, not
/// just by hiding buttons - on a phone there's no separate server tier
/// to fall back on the way Auth::requireRole() protects a PHP route
/// even if the UI is bypassed. go_router's redirect guard calls [can]
/// too, so there is exactly one source of truth for "who can do what".
final class SessionNotifierProvider
    extends $NotifierProvider<SessionNotifier, User?> {
  /// Current logged-in user as reactive state, persisted via
  /// flutter_secure_storage so app resume behaves like PHP's session
  /// cookie. Role checks are enforced here at the use-case boundary, not
  /// just by hiding buttons - on a phone there's no separate server tier
  /// to fall back on the way Auth::requireRole() protects a PHP route
  /// even if the UI is bypassed. go_router's redirect guard calls [can]
  /// too, so there is exactly one source of truth for "who can do what".
  SessionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionNotifierHash();

  @$internal
  @override
  SessionNotifier create() => SessionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(User? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<User?>(value),
    );
  }
}

String _$sessionNotifierHash() => r'8dd92696b4aa8f3052a1aa31cbf614eb9fb7e766';

/// Current logged-in user as reactive state, persisted via
/// flutter_secure_storage so app resume behaves like PHP's session
/// cookie. Role checks are enforced here at the use-case boundary, not
/// just by hiding buttons - on a phone there's no separate server tier
/// to fall back on the way Auth::requireRole() protects a PHP route
/// even if the UI is bypassed. go_router's redirect guard calls [can]
/// too, so there is exactly one source of truth for "who can do what".

abstract class _$SessionNotifier extends $Notifier<User?> {
  User? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<User?, User?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<User?, User?>,
              User?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
