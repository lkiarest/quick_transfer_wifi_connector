import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'quick_transfer_wifi_connector.dart';
import 'quick_transfer_wifi_connector_method_channel.dart';

abstract class QuickTransferWifiConnectorPlatform extends PlatformInterface {
  /// Constructs a QuickTransferWifiConnectorPlatform.
  QuickTransferWifiConnectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static QuickTransferWifiConnectorPlatform _instance =
      MethodChannelQuickTransferWifiConnector();

  /// The default instance of [QuickTransferWifiConnectorPlatform] to use.
  ///
  /// Defaults to [MethodChannelQuickTransferWifiConnector].
  static QuickTransferWifiConnectorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QuickTransferWifiConnectorPlatform] when
  /// they register themselves.
  static set instance(QuickTransferWifiConnectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<QuickTransferWifiJoinResult> joinWifiNetwork({
    required String ssid,
    required String password,
    required bool joinOnce,
  }) {
    throw UnimplementedError('joinWifiNetwork() has not been implemented.');
  }

  Future<bool> openWifiSettings() {
    throw UnimplementedError('openWifiSettings() has not been implemented.');
  }
}
