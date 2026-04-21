package com.example.quick_transfer_wifi_connector

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class QuickTransferWifiConnectorPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var applicationContext: Context
  private var activity: Activity? = null
  private var activeNetworkCallback: ConnectivityManager.NetworkCallback? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "quick_transfer_wifi_connector")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "joinWifiNetwork" -> joinWifiNetwork(call, result)
      "openWifiSettings" -> openWifiSettings(result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    unregisterActiveNetworkCallback()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  private fun joinWifiNetwork(call: MethodCall, result: Result) {
    val ssid = call.argument<String>("ssid")?.trim().orEmpty()
    val password = call.argument<String>("password").orEmpty()
    if (ssid.isEmpty()) {
      result.error("INVALID_ARGUMENT", "SSID must not be empty.", null)
      return
    }
    if (password.length < 8 || password.length > 63) {
      result.error("INVALID_ARGUMENT", "WPA/WPA2 password must be 8 to 63 characters.", null)
      return
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      joinWithNetworkSpecifier(ssid, password, result)
    } else {
      joinWithLegacyWifiManager(ssid, password, result)
    }
  }

  private fun joinWithNetworkSpecifier(ssid: String, password: String, result: Result) {
    val connectivityManager =
      applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    unregisterActiveNetworkCallback()

    val specifier = WifiNetworkSpecifier.Builder()
      .setSsid(ssid)
      .setWpa2Passphrase(password)
      .build()
    val request = NetworkRequest.Builder()
      .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
      .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
      .setNetworkSpecifier(specifier)
      .build()

    var completed = false
    fun completeOnce(payload: Map<String, Any>) {
      if (completed) {
        return
      }
      completed = true
      mainHandler.removeCallbacksAndMessages(result)
      result.success(payload)
    }

    val callback = object : ConnectivityManager.NetworkCallback() {
      override fun onAvailable(network: Network) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          connectivityManager.bindProcessToNetwork(network)
        } else {
          @Suppress("DEPRECATION")
          ConnectivityManager.setProcessDefaultNetwork(network)
        }
        completeOnce(
          mapOf(
            "status" to "connected",
            "message" to "Connected to $ssid.",
            "platform" to "android"
          )
        )
      }

      override fun onUnavailable() {
        unregisterActiveNetworkCallback()
        completeOnce(
          mapOf(
            "status" to "userDenied",
            "message" to "Wi-Fi connection was not approved or timed out.",
            "platform" to "android"
          )
        )
      }

      override fun onLost(network: Network) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          connectivityManager.bindProcessToNetwork(null)
        } else {
          @Suppress("DEPRECATION")
          ConnectivityManager.setProcessDefaultNetwork(null)
        }
      }
    }

    activeNetworkCallback = callback
    try {
      connectivityManager.requestNetwork(request, callback)
      mainHandler.postAtTime({
        if (!completed) {
          unregisterActiveNetworkCallback()
          completeOnce(
            mapOf(
              "status" to "unavailable",
              "message" to "Timed out waiting for Android Wi-Fi confirmation.",
              "platform" to "android"
            )
          )
        }
      }, result, System.currentTimeMillis() + 30000L)
    } catch (error: Exception) {
      unregisterActiveNetworkCallback()
      result.success(
        mapOf(
          "status" to "failed",
          "message" to (error.message ?: error.javaClass.simpleName),
          "platform" to "android"
        )
      )
    }
  }

  @Suppress("DEPRECATION")
  private fun joinWithLegacyWifiManager(ssid: String, password: String, result: Result) {
    val wifiManager =
      applicationContext.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    if (!wifiManager.isWifiEnabled) {
      wifiManager.isWifiEnabled = true
    }
    val config = WifiConfiguration().apply {
      SSID = quote(ssid)
      preSharedKey = quote(password)
      allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
    }
    val networkId = wifiManager.addNetwork(config)
    if (networkId == -1) {
      result.success(
        mapOf(
          "status" to "failed",
          "message" to "Unable to add Wi-Fi network.",
          "platform" to "android"
        )
      )
      return
    }
    val disconnected = wifiManager.disconnect()
    val enabled = wifiManager.enableNetwork(networkId, true)
    val reconnected = wifiManager.reconnect()
    result.success(
      mapOf(
        "status" to if (enabled) "connected" else "failed",
        "message" to "Legacy Wi-Fi request: disconnect=$disconnected enable=$enabled reconnect=$reconnected.",
        "platform" to "android"
      )
    )
  }

  private fun openWifiSettings(result: Result) {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      Intent(Settings.Panel.ACTION_WIFI)
    } else {
      Intent(Settings.ACTION_WIFI_SETTINGS)
    }
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
      (activity ?: applicationContext).startActivity(intent)
      result.success(true)
    } catch (error: Exception) {
      try {
        applicationContext.startActivity(
          Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        result.success(true)
      } catch (fallbackError: Exception) {
        result.success(false)
      }
    }
  }

  private fun unregisterActiveNetworkCallback() {
    val callback = activeNetworkCallback ?: return
    val connectivityManager =
      applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    try {
      connectivityManager.unregisterNetworkCallback(callback)
    } catch (_: Exception) {
    }
    activeNetworkCallback = null
  }

  private fun quote(value: String): String = "\"$value\""
}
