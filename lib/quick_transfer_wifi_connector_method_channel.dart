import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quick_transfer_wifi_connector.dart';
import 'quick_transfer_wifi_connector_platform_interface.dart';

/// An implementation of [QuickTransferWifiConnectorPlatform] that uses method channels.
class MethodChannelQuickTransferWifiConnector
    extends QuickTransferWifiConnectorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('quick_transfer_wifi_connector');

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
  Future<bool> openWifiSettings() async {
    return await methodChannel.invokeMethod<bool>('openWifiSettings') ?? false;
  }
}
