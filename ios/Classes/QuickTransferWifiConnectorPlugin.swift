import Flutter
import NetworkExtension
import UIKit

public class QuickTransferWifiConnectorPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "quick_transfer_wifi_connector",
      binaryMessenger: registrar.messenger()
    )
    let instance = QuickTransferWifiConnectorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "joinWifiNetwork":
      joinWifiNetwork(call, result: result)
    case "openWifiSettings":
      openWifiSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func joinWifiNetwork(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments must be a map.", details: nil))
      return
    }
    let ssid = (args["ssid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let password = args["password"] as? String ?? ""
    let joinOnce = args["joinOnce"] as? Bool ?? true

    guard !ssid.isEmpty else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "SSID must not be empty.", details: nil))
      return
    }
    guard password.count >= 8 && password.count <= 63 else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "WPA/WPA2 password must be 8 to 63 characters.",
        details: nil
      ))
      return
    }

    if #available(iOS 11.0, *) {
      let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
      configuration.joinOnce = joinOnce
      NEHotspotConfigurationManager.shared.apply(configuration) { error in
        DispatchQueue.main.async {
          if let error = error as NSError? {
            switch error.code {
            case NEHotspotConfigurationError.alreadyAssociated.rawValue:
              result([
                "status": "connected",
                "message": "Already connected to \(ssid).",
                "platform": "ios"
              ])
            case NEHotspotConfigurationError.userDenied.rawValue:
              result([
                "status": "userDenied",
                "message": "User denied Wi-Fi configuration.",
                "platform": "ios"
              ])
            default:
              result([
                "status": "failed",
                "message": error.localizedDescription,
                "platform": "ios"
              ])
            }
            return
          }
          result([
            "status": "connected",
            "message": "Wi-Fi configuration applied for \(ssid).",
            "platform": "ios"
          ])
        }
      }
    } else {
      result([
        "status": "unavailable",
        "message": "iOS 11.0 or later is required.",
        "platform": "ios"
      ])
    }
  }

  private func openWifiSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened)
    }
  }
}
