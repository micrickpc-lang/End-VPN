package com.example.endvpn

import android.Manifest
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
    private lateinit var methodChannel: MethodChannel
    private val tileReceiver = VpnBroadcastReceiver()

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

        // Устанавливаем callback для disconnect из уведомления
        VpnBroadcastReceiver.disconnectCallback = {
            runOnUiThread { methodChannel.invokeMethod("onTileDisconnect", null) }
        }

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateState" -> {
                    val connected = call.argument<Boolean>("connected") ?: false
                    val server    = call.argument<String>("server") ?: ""
                    VpnBridge.isConnected = connected
                    VpnBridge.serverName  = server
                    VpnNotificationService.start(this, connected, server)
                    result.success(null)
                }
                "updateServerName" -> {
                    val server = call.argument<String>("server") ?: ""
                    VpnBridge.serverName = server
                    if (VpnBridge.isConnected) {
                        VpnNotificationService.start(this, true, server)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val tileFilter = IntentFilter().apply {
            addAction(VpnNotificationService.ACTION_DISCONNECT_NOTIF)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(tileReceiver, tileFilter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(tileReceiver, tileFilter)
        }
    }

    override fun onDestroy() {
        VpnBroadcastReceiver.disconnectCallback = null
        try { unregisterReceiver(tileReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }
}