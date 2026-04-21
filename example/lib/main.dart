import 'package:flutter/material.dart';
import 'package:quick_transfer_wifi_connector/quick_transfer_wifi_connector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _ssidController =
      TextEditingController(text: 'Soundcore-1234');
  final TextEditingController _passwordController =
      TextEditingController(text: '12345678');
  String _message = 'Idle';

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _message = 'Waiting for system confirmation...';
    });
    try {
      final QuickTransferWifiJoinResult result =
          await QuickTransferWifiConnector.joinWifiNetwork(
        ssid: _ssidController.text,
        password: _passwordController.text,
      );
      setState(() {
        _message = '${result.status.name}: ${result.message}';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    }
  }

  Future<void> _openSettings() async {
    final bool opened = await QuickTransferWifiConnector.openWifiSettings();
    setState(() {
      _message = opened ? 'Opened Wi-Fi settings.' : 'Failed to open settings.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Quick Transfer Wi-Fi')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(labelText: 'SSID'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _join,
                child: const Text('Join Device AP'),
              ),
              OutlinedButton(
                onPressed: _openSettings,
                child: const Text('Open Wi-Fi Settings'),
              ),
              const SizedBox(height: 16),
              Text(_message),
            ],
          ),
        ),
      ),
    );
  }
}
