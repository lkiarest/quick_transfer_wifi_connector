import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_transfer_wifi_connector/quick_transfer_wifi_connector.dart';
import 'package:quick_transfer_wifi_connector/quick_transfer_wifi_connector_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelQuickTransferWifiConnector platform =
      MethodChannelQuickTransferWifiConnector();
  const MethodChannel channel = MethodChannel('quick_transfer_wifi_connector');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'joinWifiNetwork') {
        return <String, dynamic>{
          'status': 'userDenied',
          'message': 'user denied',
          'platform': 'ios',
        };
      }
      if (methodCall.method == 'openWifiSettings') {
        return false;
      }
      return null;
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('joinWifiNetwork parses platform result', () async {
    final QuickTransferWifiJoinResult result = await platform.joinWifiNetwork(
      ssid: 'Soundcore-1234',
      password: '12345678',
      joinOnce: true,
    );

    expect(result.status, QuickTransferWifiJoinStatus.userDenied);
    expect(result.message, 'user denied');
    expect(result.platform, 'ios');
  });

  test('openWifiSettings parses platform bool result', () async {
    expect(await platform.openWifiSettings(), isFalse);
  });
}
