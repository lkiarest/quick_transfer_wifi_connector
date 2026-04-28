import 'quick_transfer_wifi_connector_platform_interface.dart';

enum QuickTransferWifiJoinStatus {
  connected,
  unavailable,
  userDenied,
  failed,
}

enum QuickTransferWifiRestoreStatus {
  restored,
  bestEffort,
  unavailable,
  failed,
}

class QuickTransferWifiJoinResult {
  const QuickTransferWifiJoinResult({
    required this.status,
    required this.message,
    required this.platform,
  });

  factory QuickTransferWifiJoinResult.fromMap(Map<dynamic, dynamic> map) {
    return QuickTransferWifiJoinResult(
      status: _statusFromString(map['status']?.toString()),
      message: map['message']?.toString() ?? '',
      platform: map['platform']?.toString() ?? '',
    );
  }

  final QuickTransferWifiJoinStatus status;
  final String message;
  final String platform;

  bool get isConnected => status == QuickTransferWifiJoinStatus.connected;

  static QuickTransferWifiJoinStatus _statusFromString(String? value) {
    switch (value) {
      case 'connected':
        return QuickTransferWifiJoinStatus.connected;
      case 'unavailable':
        return QuickTransferWifiJoinStatus.unavailable;
      case 'userDenied':
        return QuickTransferWifiJoinStatus.userDenied;
      case 'failed':
      default:
        return QuickTransferWifiJoinStatus.failed;
    }
  }
}

class QuickTransferWifiRestoreResult {
  const QuickTransferWifiRestoreResult({
    required this.status,
    required this.message,
    required this.platform,
  });

  factory QuickTransferWifiRestoreResult.fromMap(Map<dynamic, dynamic> map) {
    return QuickTransferWifiRestoreResult(
      status: _statusFromString(map['status']?.toString()),
      message: map['message']?.toString() ?? '',
      platform: map['platform']?.toString() ?? '',
    );
  }

  final QuickTransferWifiRestoreStatus status;
  final String message;
  final String platform;

  bool get isRestored => status == QuickTransferWifiRestoreStatus.restored;

  bool get isBestEffort => status == QuickTransferWifiRestoreStatus.bestEffort;

  static QuickTransferWifiRestoreStatus _statusFromString(String? value) {
    switch (value) {
      case 'restored':
        return QuickTransferWifiRestoreStatus.restored;
      case 'best_effort':
        return QuickTransferWifiRestoreStatus.bestEffort;
      case 'unavailable':
        return QuickTransferWifiRestoreStatus.unavailable;
      case 'failed':
      default:
        return QuickTransferWifiRestoreStatus.failed;
    }
  }
}

class QuickTransferWifiConnector {
  const QuickTransferWifiConnector._();

  static Future<void> prepareForDeviceWifiTransition({
    required String deviceSsid,
  }) {
    return QuickTransferWifiConnectorPlatform.instance
        .prepareForDeviceWifiTransition(
      deviceSsid: deviceSsid.trim(),
    );
  }

  static Future<QuickTransferWifiJoinResult> joinWifiNetwork({
    required String ssid,
    required String password,
    bool joinOnce = true,
  }) {
    _validateCredentials(ssid: ssid, password: password);
    return QuickTransferWifiConnectorPlatform.instance.joinWifiNetwork(
      ssid: ssid.trim(),
      password: password,
      joinOnce: joinOnce,
    );
  }

  static Future<QuickTransferWifiRestoreResult> restorePreviousNetwork({
    required String deviceSsid,
  }) {
    return QuickTransferWifiConnectorPlatform.instance.restorePreviousNetwork(
      deviceSsid: deviceSsid.trim(),
    );
  }

  static Future<bool> openWifiSettings() {
    return QuickTransferWifiConnectorPlatform.instance.openWifiSettings();
  }

  static void _validateCredentials({
    required String ssid,
    required String password,
  }) {
    if (ssid.trim().isEmpty) {
      throw ArgumentError.value(ssid, 'ssid', 'SSID must not be empty.');
    }
    if (password.length < 8 || password.length > 63) {
      throw ArgumentError.value(
        password,
        'password',
        'WPA/WPA2 password must be 8 to 63 characters.',
      );
    }
  }
}
