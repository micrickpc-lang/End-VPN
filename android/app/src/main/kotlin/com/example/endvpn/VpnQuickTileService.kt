package com.example.endvpn

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class VpnQuickTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (VpnBridge.isConnected) {
            savePendingAction("disconnect")
            sendBroadcast(Intent(VpnNotificationService.ACTION_DISCONNECT_NOTIF).setPackage(packageName))
        } else {
            savePendingAction("connect")
            sendBroadcast(Intent(VpnBroadcastReceiver.ACTION_TILE_CONNECT).setPackage(packageName))
            openAppForConnect()
        }
        updateTile()
    }

    private fun updateTile() {
        qsTile?.let { tile ->
            tile.label = "EndVPN"
            tile.subtitle = if (VpnBridge.isConnected) {
                if (VpnBridge.serverName.isNotEmpty()) VpnBridge.serverName else "Connected"
            } else {
                "Connect"
            }
            tile.state = if (VpnBridge.isConnected) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.icon = Icon.createWithResource(this, resources.getIdentifier("ic_launcher", "mipmap", packageName))
            }
            tile.updateTile()
        }
    }

    private fun openAppForConnect() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            action = VpnBroadcastReceiver.ACTION_TILE_CONNECT
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        } ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                21,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun savePendingAction(action: String) {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_ACTION, action)
            .apply()
    }

    companion object {
        private const val PREFS = "endvpn_tile"
        private const val KEY_PENDING_ACTION = "pending_action"

        fun requestTileRefresh(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                requestListeningState(
                    context,
                    ComponentName(context, VpnQuickTileService::class.java)
                )
            }
        }
    }
}
