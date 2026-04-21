# quick_transfer_wifi_connector

Flutter plugin for joining a temporary Wi-Fi access point through the platform
confirmation UI. It is intended for device file-transfer flows where the device
opens a short-lived AP and the app already knows the SSID and WPA/WPA2 password.

The plugin does not silently switch Wi-Fi. Android and iOS both require user
confirmation for normal third-party apps.

## Platform behavior

- Android 10+ uses `WifiNetworkSpecifier` and binds the app process to the
  confirmed Wi-Fi network so socket traffic can reach the device AP.
- Android 9 and below use the legacy `WifiManager` network APIs.
- iOS 11+ uses `NEHotspotConfigurationManager` with `joinOnce` enabled by
  default.

## Install

Use it as a path dependency while developing locally:

```yaml
dependencies:
  quick_transfer_wifi_connector:
    path: ../quick_transfer_wifi_connector
```

## Usage

```dart
final result = await QuickTransferWifiConnector.joinWifiNetwork(
  ssid: 'Soundcore-1234',
  password: '12345678',
);

if (result.isConnected) {
  // Continue with your WebSocket/device AP probe.
} else {
  await QuickTransferWifiConnector.openWifiSettings();
}
```

## Android setup

The plugin manifest declares:

- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_STATE`
- `ACCESS_FINE_LOCATION`

If the host app targets modern Android versions, request runtime location
permission before using Wi-Fi APIs that require it.

## iOS setup

Enable the Hotspot Configuration capability for the host app. The entitlement is:

```xml
<key>com.apple.developer.networking.HotspotConfiguration</key>
<true/>
```

Without this entitlement, iOS rejects `NEHotspotConfigurationManager.apply`.

The plugin podspec explicitly sets the iOS pod deployment target to `12.0`,
Swift `5.0`, `CLANG_ENABLE_MODULES=YES`, `ENABLE_BITCODE=NO`, and links
`NetworkExtension`/`UIKit`. If your production Podfile rewrites pod build
settings in `post_install`, keep this pod at iOS `12.0` or higher.

## API

- `QuickTransferWifiConnector.joinWifiNetwork(...)`
- `QuickTransferWifiConnector.openWifiSettings()`
- `QuickTransferWifiJoinResult.status`
- `QuickTransferWifiJoinResult.isConnected`
