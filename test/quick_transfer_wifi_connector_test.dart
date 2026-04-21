import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_transfer_wifi_connector/quick_transfer_wifi_connector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('quick_transfer_wifi_connector');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      calls.add(methodCall);
      if (methodCall.method == 'joinWifiNetwork') {
        return <String, dynamic>{
          'status': 'connected',
          'message': 'connected to device AP',
          'platform': 'android',
        };
      }
      if (methodCall.method == 'openWifiSettings') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('joinWifiNetwork sends ssid, password, and joinOnce to platform',
      () async {
    final QuickTransferWifiJoinResult result =
        await QuickTransferWifiConnector.joinWifiNetwork(
      ssid: 'Soundcore-1234',
      password: '12345678',
      joinOnce: true,
    );

    expect(result.status, QuickTransferWifiJoinStatus.connected);
    expect(result.message, 'connected to device AP');
    expect(result.platform, 'android');
    expect(calls.single.method, 'joinWifiNetwork');
    expect(calls.single.arguments, <String, dynamic>{
      'ssid': 'Soundcore-1234',
      'password': '12345678',
      'joinOnce': true,
    });
  });

  test('joinWifiNetwork rejects empty ssid before platform call', () async {
    expect(
      () => QuickTransferWifiConnector.joinWifiNetwork(
        ssid: ' ',
        password: '12345678',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(calls, isEmpty);
  });

  test('joinWifiNetwork rejects short WPA password before platform call',
      () async {
    expect(
      () => QuickTransferWifiConnector.joinWifiNetwork(
        ssid: 'Soundcore-1234',
        password: '1234567',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(calls, isEmpty);
  });

  test('openWifiSettings delegates to platform', () async {
    final bool opened = await QuickTransferWifiConnector.openWifiSettings();

    expect(opened, isTrue);
    expect(calls.single.method, 'openWifiSettings');
  });
}
