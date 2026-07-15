package com.example.endvpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class VpnBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            VpnNotificationService.ACTION_DISCONNECT_NOTIF -> {
                disconnectCallback?.invoke()
            }
            ACTION_TILE_CONNECT -> {
                connectCallback?.invoke()
            }
            XrayVpnService.ACTION_STATUS -> {
                statusCallback?.invoke(intent.getStringExtra("status").orEmpty())
            }
        }
    }

    companion object {
        const val ACTION_TILE_CONNECT = "com.example.endvpn.TILE_CONNECT"
        var disconnectCallback: (() -> Unit)? = null
        var connectCallback: (() -> Unit)? = null
        var statusCallback: ((String) -> Unit)? = null
    }
}

