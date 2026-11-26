import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'platform_http_client.dart';

/// An Android phone passing the till's M-Pesa / bank payment messages on to the shop, like the iPhone Shortcut does.
/// The passing on itself is native (android/.../SmsForwarding.kt): Android hands every text message to it even when
/// NexaPOS is closed, and only payment messages from NAMED senders (MPESA, a bank - never a phone number) leave the
/// phone. This side switches it on and off and reads how it is going.

/// Whether this device can pass messages on (an Android phone or tablet; not the web, not a PC, not an iPhone).
bool get smsForwardingSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The till-phone key in [input] - the key itself, or the set-up link the PC shows (…phone.html#k=KEY) - or null.
String? tillPhoneKeyFrom(String input) => RegExp(r'npk_[0-9a-fA-F]{16,128}').firstMatch(input.trim())?.group(0);

/// Where a phone sends each message (the same address the iPhone Shortcut uses).
String paymentIngestAddress([String baseUrl = nexaposPlatformBaseUrl]) => '$baseUrl?action=payment_inbox_ingest';

/// How passing on is going on this phone.
class SmsForwardingStatus {
  const SmsForwardingStatus({
    required this.enabled,
    required this.permission,
    this.keyEnd,
    this.lastAt,
    this.lastSender,
    this.lastResult,
    this.passedOn = 0,
    this.waiting = 0,
    this.sdk = 0,
  });

  /// Switched on (whatever the permission says).
  final bool enabled;

  /// Android lets NexaPOS receive text messages.
  final bool permission;

  /// The last four characters of the key in use, to tell keys apart.
  final String? keyEnd;
  final DateTime? lastAt;
  final String? lastSender;

  /// The shop's answer for the last message (recorded, already_have_it, not_a_payment, from_a_person, …) or the
  /// phone's own word (waiting, key_refused, gave_up).
  final String? lastResult;

  /// Messages the shop took as payments (or already had).
  final int passedOn;

  /// Messages waiting for internet.
  final int waiting;

  /// Android's API level (33 and up: a phone that did not get NexaPOS from a store asks once to allow "restricted
  /// settings" before the SMS permission can be given).
  final int sdk;

  /// Working: switched on and allowed to receive messages.
  bool get working => enabled && permission;

  factory SmsForwardingStatus.fromMap(Map<Object?, Object?> map) {
    int number(Object? value) => value is int ? value : (value is num ? value.toInt() : 0);
    final lastAt = map['lastAt'];
    return SmsForwardingStatus(
      enabled: map['enabled'] == true,
      permission: map['permission'] == true,
      keyEnd: map['keyEnd'] as String?,
      lastAt: lastAt is num ? DateTime.fromMillisecondsSinceEpoch(lastAt.toInt()) : null,
      lastSender: map['lastSender'] as String?,
      lastResult: map['lastResult'] as String?,
      passedOn: number(map['passedOn']),
      waiting: number(map['waiting']),
      sdk: number(map['sdk']),
    );
  }
}

/// What the last message's result means, in a sentence.
String smsForwardingResultWords(String? result) => switch (result) {
      'recorded' => 'Recorded as a payment received.',
      'already_have_it' => 'The shop already had it (another phone, or the same message twice).',
      'not_a_payment' => 'Not a payment received, so the shop ignored it.',
      'from_a_person' => 'It came from a person\'s number, so the shop refused it.',
      'no_sender' => 'It came without a sender, so the shop refused it.',
      'waiting' => 'Waiting for internet - it is sent as soon as the phone is online.',
      'key_refused' => 'The shop refused this phone\'s key. Set the phone up again (Settings > M-Pesa Till Phone on the PC).',
      'gave_up' => 'The shop could not be reached for over a day, so it was not sent.',
      null || '' => 'Nothing passed on yet.',
      _ => 'The shop answered: $result.',
    };

/// The native side, through its channel.
class SmsForwarding {
  const SmsForwarding([this._channel = const MethodChannel('com.nexapos/sms_forwarding')]);
  final MethodChannel _channel;

  Future<SmsForwardingStatus> status() async {
    final map = await _channel.invokeMethod<Map<Object?, Object?>>('status');
    return SmsForwardingStatus.fromMap(map ?? const {});
  }

  /// Switches passing on on with [key], sending to [address]. False when the key is not a till-phone key.
  Future<bool> enable({required String key, required String address}) async =>
      await _channel.invokeMethod<bool>('enable', {'key': key, 'address': address}) ?? false;

  Future<void> disable() => _channel.invokeMethod<void>('disable');

  /// Asks Android for permission to receive text messages. True when it is (now) allowed.
  Future<bool> requestPermission() async => await _channel.invokeMethod<bool>('requestPermission') ?? false;

  /// Opens NexaPOS's App info page (for "Allow restricted settings" and the SMS permission).
  Future<bool> openAppSettings() async => await _channel.invokeMethod<bool>('openAppSettings') ?? false;
}

final smsForwardingProvider = Provider<SmsForwarding>((ref) => const SmsForwarding());

/// What the shop said about a till-phone key.
enum TillKeyCheck { works, refused, unknown }

/// Asks the shop whether [key] is a phone it knows, by passing on a message that is not a payment (the shop answers
/// "not a payment" for a known key and refuses an unknown one). [unknown] when the shop cannot be reached.
Future<TillKeyCheck> checkTillPhoneKey(http.Client client, {required String address, required String key}) async {
  try {
    final response = await client
        .post(
          Uri.parse(address),
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'key': key, 'text': 'NexaPOS: checking this phone', 'sender': 'NexaPOS'}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 200 && response.statusCode < 300) return TillKeyCheck.works;
    if (response.statusCode == 401 || response.statusCode == 403) return TillKeyCheck.refused;
    return TillKeyCheck.unknown;
  } on Object {
    return TillKeyCheck.unknown;
  }
}
