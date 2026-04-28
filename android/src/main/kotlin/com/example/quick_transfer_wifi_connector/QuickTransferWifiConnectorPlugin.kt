package com.example.quick_transfer_wifi_connector

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class QuickTransferWifiConnectorPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  companion object {
    private const val TAG = "QuickTransferWifi"
    private const val JOIN_POLL_INTERVAL_MS = 400L
  }

  private lateinit var channel: MethodChannel
  private lateinit var applicationContext: Context
  private var activity: Activity? = null
  private var activeNetworkCallback: ConnectivityManager.NetworkCallback? = null
  private val mainHandler = Handler(Looper.getMainLooper())
  private var pendingJoinToken: Any? = null
  private var previousWifiNetworkId: Int? = null
  private var previousWifiSsid: String? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "quick_transfer_wifi_connector")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "prepareForDeviceWifiTransition" -> prepareForDeviceWifiTransition(call, result)
      "joinWifiNetwork" -> joinWifiNetwork(call, result)
      "restorePreviousNetwork" -> restorePreviousNetwork(call, result)
      "openWifiSettings" -> openWifiSettings(result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    unregisterActiveNetworkCallback()
    mainHandler.removeCallbacksAndMessages(null)
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

  private fun prepareForDeviceWifiTransition(call: MethodCall, result: Result) {
    val deviceSsid = call.argument<String>("deviceSsid")?.trim().orEmpty()
    capturePreviousWifiState(deviceSsid)
    result.success(null)
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

    capturePreviousWifiState(ssid)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      joinWithNetworkSpecifier(ssid, password, result)
    } else {
      joinWithLegacyWifiManager(ssid, password, result)
    }
  }

  private fun restorePreviousNetwork(call: MethodCall, result: Result) {
    val deviceSsid = call.argument<String>("deviceSsid")?.trim().orEmpty()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      restoreBoundNetwork(deviceSsid, result)
      return
    }
    restoreLegacyWifiNetwork(result)
  }

  private fun joinWithNetworkSpecifier(ssid: String, password: String, result: Result) {
    val connectivityManager =
      applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    unregisterActiveNetworkCallback()

    val currentSsid = normalizeSsid(currentWifiInfo()?.ssid)
    if (currentSsid == ssid) {
      bindProcessToMatchingWifiNetwork(connectivityManager, ssid)
      result.success(
        mapOf(
          "status" to "connected",
          "message" to "Already connected to $ssid.",
          "platform" to "android"
        )
      )
      return
    }

    val token = Any()
    pendingJoinToken = token
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
      if (pendingJoinToken === token) {
        pendingJoinToken = null
      }
      mainHandler.removeCallbacksAndMessages(token)
      result.success(payload)
    }

    fun pollForRequestedWifi() {
      mainHandler.postAtTime({
        if (completed || pendingJoinToken !== token) {
          return@postAtTime
        }
        val polledSsid = normalizeSsid(currentWifiInfo()?.ssid)
        if (polledSsid == ssid) {
          Log.d(TAG, "detected target SSID via poll before callback: $ssid")
          bindProcessToMatchingWifiNetwork(connectivityManager, ssid)
          completeOnce(
            mapOf(
              "status" to "connected",
              "message" to "Connected to $ssid.",
              "platform" to "android"
            )
          )
          return@postAtTime
        }
        pollForRequestedWifi()
      }, token, System.currentTimeMillis() + JOIN_POLL_INTERVAL_MS)
    }

    val callback = object : ConnectivityManager.NetworkCallback() {
      override fun onAvailable(network: Network) {
        bindProcessToNetwork(connectivityManager, network)
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
      pollForRequestedWifi()
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
      }, token, System.currentTimeMillis() + 30000L)
    } catch (error: Exception) {
      unregisterActiveNetworkCallback()
      completeOnce(
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

  private fun restoreBoundNetwork(deviceSsid: String, result: Result) {
    val connectivityManager =
      applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    unregisterActiveNetworkCallback()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      connectivityManager.bindProcessToNetwork(null)
    } else {
      @Suppress("DEPRECATION")
      ConnectivityManager.setProcessDefaultNetwork(null)
    }

    val wifiInfo = currentWifiInfo()
    val currentSsid = normalizeSsid(wifiInfo?.ssid)
    val stillOnDeviceAp = currentSsid != null && currentSsid == deviceSsid
    val restoredToPrevious =
      previousWifiSsid != null && currentSsid != null && currentSsid == previousWifiSsid

    val status = when {
      restoredToPrevious -> "restored"
      stillOnDeviceAp -> "failed"
      else -> "best_effort"
    }
    val message = when (status) {
      "restored" -> "已恢复到之前的 Wi-Fi：$currentSsid"
      "failed" -> "已释放设备热点网络绑定，但系统仍停留在设备热点。"
      else -> "已释放设备热点网络绑定，等待系统恢复默认外网。"
    }
    result.success(
      mapOf(
        "status" to status,
        "message" to message,
        "platform" to "android"
      )
    )
  }

  @Suppress("DEPRECATION")
  private fun restoreLegacyWifiNetwork(result: Result) {
    val wifiManager =
      applicationContext.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    val targetNetworkId = previousWifiNetworkId
    if (targetNetworkId == null || targetNetworkId == -1) {
      result.success(
        mapOf(
          "status" to "best_effort",
          "message" to "未记录到之前的 Wi-Fi，等待系统自行恢复。",
          "platform" to "android"
        )
      )
      return
    }
    val disconnected = wifiManager.disconnect()
    val enabled = wifiManager.enableNetwork(targetNetworkId, true)
    val reconnected = wifiManager.reconnect()
    val currentSsid = normalizeSsid(currentWifiInfo()?.ssid)
    val restored = currentSsid != null && currentSsid == previousWifiSsid
    result.success(
      mapOf(
        "status" to if (enabled && reconnected) {
          if (restored) "restored" else "best_effort"
        } else {
          "failed"
        },
        "message" to "Legacy Wi-Fi restore: disconnect=$disconnected enable=$enabled reconnect=$reconnected current=${currentSsid ?: "-"}",
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
      } catch (_: Exception) {
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

  private fun bindProcessToMatchingWifiNetwork(
    connectivityManager: ConnectivityManager,
    ssid: String,
  ) {
    val matchingNetwork = connectivityManager.allNetworks.firstOrNull { network ->
      networkMatchesSsid(connectivityManager, network, ssid)
    }
    if (matchingNetwork != null) {
      bindProcessToNetwork(connectivityManager, matchingNetwork)
    }
  }

  private fun bindProcessToNetwork(
    connectivityManager: ConnectivityManager,
    network: Network,
  ) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      connectivityManager.bindProcessToNetwork(network)
    } else {
      @Suppress("DEPRECATION")
      ConnectivityManager.setProcessDefaultNetwork(network)
    }
  }

  private fun networkMatchesSsid(
    connectivityManager: ConnectivityManager,
    network: Network,
    targetSsid: String,
  ): Boolean {
    val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
    if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
      return false
    }
    val transportInfo = capabilities.transportInfo
    if (transportInfo is WifiInfo) {
      return normalizeSsid(transportInfo.ssid) == targetSsid
    }
    return normalizeSsid(currentWifiInfo()?.ssid) == targetSsid
  }

  @Suppress("DEPRECATION")
  private fun capturePreviousWifiState(deviceSsid: String) {
    val wifiInfo = currentWifiInfo() ?: return
    val currentSsid = normalizeSsid(wifiInfo.ssid) ?: return
    if (currentSsid.isBlank() || currentSsid == deviceSsid) {
      return
    }
    previousWifiSsid = currentSsid
    previousWifiNetworkId = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      wifiInfo.networkId
    } else {
      wifiInfo.networkId.takeIf { it != -1 }
    }
  }

  @Suppress("DEPRECATION")
  private fun currentWifiInfo(): WifiInfo? {
    val wifiManager =
      applicationContext.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    return wifiManager.connectionInfo
  }

  private fun normalizeSsid(raw: String?): String? {
    if (raw == null) {
      return null
    }
    return raw.removePrefix("\"").removeSuffix("\"")
      .takeIf { it.isNotBlank() && it != "<unknown ssid>" }
  }

  private fun quote(value: String): String = "\"$value\""
}
