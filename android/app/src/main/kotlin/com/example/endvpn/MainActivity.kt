package com.example.endvpn

import android.Manifest
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.endvpn/vpn_tile"
    private val NOTIF_PERMISSION_CODE = 100
    private val XRAY_VPN_PERMISSION_CODE = 101
    private val PREFS = "endvpn_tile"
    private val KEY_PENDING_ACTION = "pending_action"
    private lateinit var methodChannel: MethodChannel
    private val tileReceiver = VpnBroadcastReceiver()
    private var pendingXrayConfig: String? = null
    private var pendingXrayServer: String = ""
    private var pendingXrayResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIF_PERMISSION_CODE
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        VpnBroadcastReceiver.disconnectCallback = {
            runOnUiThread { methodChannel.invokeMethod("onTileDisconnect", null) }
        }
        VpnBroadcastReceiver.connectCallback = {
            runOnUiThread { methodChannel.invokeMethod("onTileConnect", null) }
        }
        VpnBroadcastReceiver.statusCallback = { status ->
            runOnUiThread { methodChannel.invokeMethod("onXrayStatus", status) }
        }

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateState" -> {
                    val connected = call.argument<Boolean>("connected") ?: false
                    val server    = call.argument<String>("server") ?: ""
                    VpnBridge.isConnected = connected
                    VpnBridge.serverName  = server
                    VpnQuickTileService.requestTileRefresh(this)
                    if (!connected) {
                        VpnNotificationService.start(this, false, server)
                    }
                    result.success(null)
                }
                "updateServerName" -> {
                    val server = call.argument<String>("server") ?: ""
                    VpnBridge.serverName = server
                    VpnQuickTileService.requestTileRefresh(this)
                    result.success(null)
                }
                "startXray" -> {
                    val config = call.argument<String>("config").orEmpty()
                    val server = call.argument<String>("server").orEmpty()
                    val permissionIntent = android.net.VpnService.prepare(this)
                    if (permissionIntent == null) {
                        startXrayService(config, server)
                        result.success(true)
                    } else {
                        pendingXrayConfig = config
                        pendingXrayServer = server
                        pendingXrayResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(permissionIntent, XRAY_VPN_PERMISSION_CODE)
                    }
                }
                "stopXray" -> {
                    startService(Intent(this, XrayVpnService::class.java)
                        .setAction(XrayVpnService.ACTION_STOP))
                    result.success(true)
                }
                "consumePendingTileAction" -> {
                    val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
                    val action = prefs.getString(KEY_PENDING_ACTION, null)
                    prefs.edit().remove(KEY_PENDING_ACTION).apply()
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }

        val tileFilter = IntentFilter().apply {
            addAction(VpnNotificationService.ACTION_DISCONNECT_NOTIF)
            addAction(VpnBroadcastReceiver.ACTION_TILE_CONNECT)
            addAction(XrayVpnService.ACTION_STATUS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(tileReceiver, tileFilter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(tileReceiver, tileFilter)
        }
        handleTileIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleTileIntent(intent)
    }

    private fun handleTileIntent(intent: Intent?) {
        when (intent?.action) {
            VpnBroadcastReceiver.ACTION_TILE_CONNECT -> {
                getSharedPreferences(PREFS, MODE_PRIVATE)
                    .edit()
                    .putString(KEY_PENDING_ACTION, "connect")
                    .apply()
                runOnUiThread { methodChannel.invokeMethod("onTileConnect", null) }
            }
            VpnNotificationService.ACTION_DISCONNECT_NOTIF -> {
                getSharedPreferences(PREFS, MODE_PRIVATE)
                    .edit()
                    .putString(KEY_PENDING_ACTION, "disconnect")
                    .apply()
                runOnUiThread { methodChannel.invokeMethod("onTileDisconnect", null) }
            }
        }
    }

    private fun startXrayService(config: String, server: String) {
        val intent = Intent(this, XrayVpnService::class.java).apply {
            putExtra(XrayVpnService.EXTRA_CONFIG, config)
            putExtra(XrayVpnService.EXTRA_SERVER, server)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != XRAY_VPN_PERMISSION_CODE) return
        if (resultCode == RESULT_OK) {
            startXrayService(pendingXrayConfig.orEmpty(), pendingXrayServer)
            pendingXrayResult?.success(true)
        } else {
            pendingXrayResult?.error("VPN_PERMISSION_DENIED", "VPN permission denied", null)
        }
        pendingXrayConfig = null
        pendingXrayResult = null
    }

    override fun onDestroy() {
        VpnBroadcastReceiver.disconnectCallback = null
        VpnBroadcastReceiver.connectCallback = null
        VpnBroadcastReceiver.statusCallback = null
        try { unregisterReceiver(tileReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }
}

