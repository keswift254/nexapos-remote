import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'platform_http_client.dart';

part 'platform_onboarding_gateway.g.dart';

@Riverpod(keepAlive: true)
PlatformOnboardingGateway platformOnboardingGateway(Ref ref) => PlatformOnboardingGateway();

class DeviceRegistration {
  final String apiKey;
  const DeviceRegistration(this.apiKey);
}

class InviteResult {
  final String code;
  final String expiresAt;
  const InviteResult({required this.code, required this.expiresAt});
}

class SettlementResult {
  final String subaccountCode;
  final bool isVerified;
  final String accountName;

  const SettlementResult({required this.subaccountCode, required this.isVerified, required this.accountName});
}

class ClientStatus {
  final String status;
  final String businessName;
  final String settlementType;
  final String bankCode;
  final String accountNumber;
  final String accountName;
  final String subaccountCode;
  final bool isVerified;
  // False for any device that joined this shop via an invite code -
  // only the device that originally registered/founded the shop can
  // change settlement details (see nexapos_platform's
  // save_settlement_details, which enforces this server-side
  // regardless of what the UI does with this flag - this is purely so
  // the app can show/disable the form up front instead of a non-owner
  // device filling it in and only then hitting a 403).
  final bool isOwner;

  const ClientStatus({
    required this.status,
    required this.businessName,
    required this.settlementType,
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    required this.subaccountCode,
    required this.isVerified,
    required this.isOwner,
  });

  bool get isSettled => subaccountCode.isNotEmpty;
}

class DeviceInfo {
  final int id;
  final String deviceLabel;
  final bool isOwner;
  final String status;

  const DeviceInfo({required this.id, required this.deviceLabel, required this.isOwner, required this.status});

  bool get isDisabled => status == 'disabled';
}

class BankOption {
  final String name;
  final String code;
  final String type;

  const BankOption({required this.name, required this.code, required this.type});

  // Paystack Kenya uses both 'mobile_money' (M-PESA, Airtel Money,
  // Telkom T-Kash) and 'mobile_money_business' (M-PESA Paybill/Till) -
  // confirmed against the live bank list, not assumed - a shop settling
  // to a Till number needs to appear under the M-Pesa toggle too.
  bool get isMobileMoney => type.startsWith('mobile_money');
}

/// Setup-time calls to the payments-platform backend - registering this
/// device and saving its settlement details - kept separate from
/// PaystackGateway (checkout-time calls) since they're a different
/// concern with a different lifecycle, even though both share the same
/// low-level HTTP plumbing (see platform_http_client.dart).
class PlatformOnboardingGateway {
  final http.Client _client;

  PlatformOnboardingGateway([http.Client? client]) : _client = client ?? http.Client();

  Future<DeviceRegistration> registerDevice({
    required String baseUrl,
    required String deviceId,
    required String deviceLabel,
    required String registrationSecret,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'register_device',
      baseUrl,
      body: {'device_id': deviceId, 'device_label': deviceLabel, 'registration_secret': registrationSecret},
    );
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not register this device.'));
    }
    final apiKey = (response['api_key'] as String? ?? '').trim();
    if (apiKey.isEmpty) throw const PaystackException('The payments server did not return an API key.');
    return DeviceRegistration(apiKey);
  }

  /// Lets an already-registered device join an existing shop's sync
  /// group via a code generated on another device (see [generateInvite])
  /// - deliberately not a parameter on [registerDevice] itself, since
  /// that endpoint 409s for any device outside its own 10-minute
  /// registration grace window, before an invite code would ever be read.
  Future<void> joinShop({required String baseUrl, required String apiKey, required String inviteCode}) async {
    final response = await platformRequest(
      _client,
      'POST',
      'join_shop',
      baseUrl,
      apiKey: apiKey,
      body: {'invite_code': inviteCode},
    );
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not join that shop.'));
    }
  }

  /// Generates a short-lived code another device can redeem via
  /// [joinShop] to join this device's shop.
  Future<InviteResult> generateInvite({required String baseUrl, required String apiKey}) async {
    final response = await platformRequest(_client, 'POST', 'generate_invite', baseUrl, apiKey: apiKey);
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not generate an invite code.'));
    }
    return InviteResult(
      code: (response['code'] as String? ?? '').trim(),
      expiresAt: (response['expires_at'] as String? ?? '').trim(),
    );
  }

  /// Creates the subaccount the first time, and transparently updates it
  /// on every later call (the backend decides which, based on whether
  /// this device already has a subaccount_code) - so this same method
  /// backs both the initial setup form and letting a client freely edit
  /// their settlement details afterward.
  Future<SettlementResult> saveSettlementDetails({
    required String baseUrl,
    required String apiKey,
    required String businessName,
    required String settlementType,
    required String bankCode,
    required String accountNumber,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'save_settlement_details',
      baseUrl,
      apiKey: apiKey,
      body: {
        'business_name': businessName,
        'settlement_type': settlementType,
        'bank_code': bankCode,
        'account_number': accountNumber,
      },
    );
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not save settlement details.'));
    }
    return SettlementResult(
      subaccountCode: (response['subaccount_code'] as String? ?? '').trim(),
      isVerified: response['is_verified'] == true,
      accountName: (response['account_name'] as String? ?? '').trim(),
    );
  }

  /// The source of truth for "is this device settled yet, and with
  /// what" - the phone never caches this itself (see PaystackCredentials
  /// for why that's deliberate: it would drift from whatever the
  /// operator or a dashboard edit changed server-side).
  Future<ClientStatus> getClientStatus({required String baseUrl, required String apiKey}) async {
    final response = await platformRequest(_client, 'GET', 'client_status', baseUrl, apiKey: apiKey);
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not load your payment settings.'));
    }
    return ClientStatus(
      status: (response['status'] as String? ?? '').trim(),
      businessName: (response['business_name'] as String? ?? '').trim(),
      settlementType: (response['settlement_type'] as String? ?? '').trim(),
      bankCode: (response['bank_code'] as String? ?? '').trim(),
      accountNumber: (response['account_number'] as String? ?? '').trim(),
      accountName: (response['account_name'] as String? ?? '').trim(),
      subaccountCode: (response['subaccount_code'] as String? ?? '').trim(),
      isVerified: response['is_verified'] == true,
      // Defaults true for a server that predates this field, matching
      // the pre-existing behavior (every device could change
      // settlement) rather than silently locking out real shops on an
      // old backend that hasn't deployed the is_owner column yet.
      isOwner: response['is_owner'] == null || response['is_owner'] == true,
    );
  }

  /// Owner-only server-side (see save_settlement_details' sibling check
  /// in index.php's list_devices) - lets the shop's founding device see
  /// every device currently able to sync its data, as the basis for
  /// [revokeDevice].
  Future<List<DeviceInfo>> listDevices({required String baseUrl, required String apiKey}) async {
    final response = await platformRequest(_client, 'GET', 'list_devices', baseUrl, apiKey: apiKey);
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not load devices.'));
    }
    final devices = (response['devices'] as List?) ?? const [];
    return devices
        .whereType<Map>()
        .map((device) => DeviceInfo(
              id: (device['id'] as num? ?? 0).toInt(),
              deviceLabel: (device['device_label'] as String? ?? '').trim(),
              isOwner: device['is_owner'] == true,
              status: (device['status'] as String? ?? '').trim(),
            ))
        .toList();
  }

  /// Cuts the target device off immediately - the server enforces
  /// `status != 'disabled'` on every authenticated call it makes from
  /// here on (Auth::requireClient), not just future sync attempts.
  /// There's no way back from this via the API on purpose (see
  /// revoke_device's own comment) - a device that needs to rejoin does
  /// so as a fresh registration + a new invite code.
  Future<void> revokeDevice({required String baseUrl, required String apiKey, required int clientId}) async {
    final response =
        await platformRequest(_client, 'POST', 'revoke_device', baseUrl, apiKey: apiKey, body: {'client_id': clientId});
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not revoke that device.'));
    }
  }

  Future<List<BankOption>> listBanks({required String baseUrl, required String apiKey}) async {
    final response = await platformRequest(_client, 'GET', 'list_banks', baseUrl, apiKey: apiKey);
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not load the bank list.'));
    }
    final banks = (response['banks'] as List?) ?? const [];
    return banks
        .whereType<Map>()
        .map((bank) => BankOption(
              name: (bank['name'] as String? ?? '').trim(),
              code: (bank['code'] as String? ?? '').trim(),
              type: (bank['type'] as String? ?? '').trim(),
            ))
        .toList();
  }
}
