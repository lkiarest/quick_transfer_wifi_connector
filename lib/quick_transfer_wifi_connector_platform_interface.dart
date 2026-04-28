import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'quick_transfer_wifi_connector.dart';
import 'quick_transfer_wifi_connector_method_channel.dart';

abstract class QuickTransferWifiConnectorPlatform extends PlatformInterface {
  QuickTransferWifiConnectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static QuickTransferWifiConnectorPlatform _instance =
      MethodChannelQuickTransferWifiConnector();

  static QuickTransferWifiConnectorPlatform get instance => _instance;

  static set instance(QuickTransferWifiConnectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> prepareForDeviceWifiTransition({
    required String deviceSsid,
  }) {
    throw UnimplementedError(
      'prepareForDeviceWifiTransition() has not been implemented.',
    );
  }

  Future<QuickTransferWifiJoinResult> joinWifiNetwork({
    required String ssid,
    required String password,
    required bool joinOnce,
  }) {
    throw UnimplementedError('joinWifiNetwork() has not been implemented.');
  }

  Future<QuickTransferWifiRestoreResult> restorePreviousNetwork({
    required String deviceSsid,
  }) {
    throw UnimplementedError(
        'restorePreviousNetwork() has not been implemented.');
  }

  Future<bool> openWifiSettings() {
    throw UnimplementedError('openWifiSettings() has not been implemented.');
  }
}
