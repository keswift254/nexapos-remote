// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_settings_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(currentPaymentCredentials)
final currentPaymentCredentialsProvider = CurrentPaymentCredentialsProvider._();

final class CurrentPaymentCredentialsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaystackCredentials>,
          PaystackCredentials,
          FutureOr<PaystackCredentials>
        >
    with
        $FutureModifier<PaystackCredentials>,
        $FutureProvider<PaystackCredentials> {
  CurrentPaymentCredentialsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPaymentCredentialsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPaymentCredentialsHash();

  @$internal
  @override
  $FutureProviderElement<PaystackCredentials> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaystackCredentials> create(Ref ref) {
    return currentPaymentCredentials(ref);
  }
}

String _$currentPaymentCredentialsHash() =>
    r'50d0a9532253774983f65a2248d199eeb80cd9a3';

/// The live source of truth for settlement status - never cached on the
/// phone (see PaystackCredentialsService's class doc) so an operator or
/// dashboard-side change is always reflected next time this screen opens.

@ProviderFor(currentClientStatus)
final currentClientStatusProvider = CurrentClientStatusProvider._();

/// The live source of truth for settlement status - never cached on the
/// phone (see PaystackCredentialsService's class doc) so an operator or
/// dashboard-side change is always reflected next time this screen opens.

final class CurrentClientStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<ClientStatus?>,
          ClientStatus?,
          FutureOr<ClientStatus?>
        >
    with $FutureModifier<ClientStatus?>, $FutureProvider<ClientStatus?> {
  /// The live source of truth for settlement status - never cached on the
  /// phone (see PaystackCredentialsService's class doc) so an operator or
  /// dashboard-side change is always reflected next time this screen opens.
  CurrentClientStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentClientStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentClientStatusHash();

  @$internal
  @override
  $FutureProviderElement<ClientStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ClientStatus?> create(Ref ref) {
    return currentClientStatus(ref);
  }
}

String _$currentClientStatusHash() =>
    r'ab2e3b4af4ae0ba944beefd5f670bf1975946fec';
