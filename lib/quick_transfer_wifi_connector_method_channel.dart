import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quick_transfer_wifi_connector.dart';
import 'quick_transfer_wifi_connector_platform_interface.dart';

class MethodChannelQuickTransferWifiConnector
    extends QuickTransferWifiConnectorPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('quick_transfer_wifi_connector');

  @override
  Future<void> prepareForDeviceWifiTransition({
    required String deviceSsid,
  }) async {
    await methodChannel.invokeMethod<void>(
      'prepareForDeviceWifiTransition',
      <String, dynamic>{
        'deviceSsid': deviceSsid,
      },
    );
  }

  @override
  Future<QuickTransferWifiJoinResult> joinWifiNetwork({
    required String ssid,
    required String password,
    required bool joinOnce,
  }) async {
    final Map<dynamic, dynamic>? result =
        await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'joinWifiNetwork',
      <String, dynamic>{
        'ssid': ssid,
        'password': password,
        'joinOnce': joinOnce,
      },
    );
    return QuickTransferWifiJoinResult.fromMap(
      result ??
          <String, dynamic>{
            'status': 'failed',
            'message': 'Platform returned no result.',
          },
    );
  }

  @override
  Future<QuickTransferWifiRestoreResult> restorePreviousNetwork({
    required String deviceSsid,
  }) async {
    final Map<dynamic, dynamic>? result =
        await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'restorePreviousNetwork',
      <String, dynamic>{
        'deviceSsid': deviceSsid,
      },
    );
    return QuickTransferWifiRestoreResult.fromMap(
      result ??
          <String, dynamic>{
            'status': 'failed',
            'message': 'Platform returned no result.',
          },
    );
  }

  @override
  Future<bool> openWifiSettings() async {
    return await methodChannel.invokeMethod<bool>('openWifiSettings') ?? false;
  }
}
