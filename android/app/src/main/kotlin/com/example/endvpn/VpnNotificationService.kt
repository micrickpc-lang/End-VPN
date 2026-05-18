package com.example.endvpn

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class VpnNotificationService : Service() {

    private val disconnectReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            sendBroadcast(Intent(ACTION_DISCONNECT_NOTIF).setPackage(packageName))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(disconnectReceiver, IntentFilter(ACTION_DISCONNECT_INTERNAL), RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(disconnectReceiver, IntentFilter(ACTION_DISCONNECT_INTERNAL))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val connected = intent?.getBooleanExtra(EXTRA_CONNECTED, false) ?: false
        val server    = intent?.getStringExtra(EXTRA_SERVER) ?: ""

        if (connected) {
            startForeground(NOTIF_ID, buildNotification(server))
            cancelSingboxNotification()
        } else {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun cancelSingboxNotification() {
        val nm = getSystemService(NotificationManager::class.java)
        val handler = Handler(Looper.getMainLooper())
        listOf(300L, 800L, 1500L, 3000L, 5000L).forEach { delay ->
            handler.postDelayed({
                try {
                    nm.cancel(1)
                    nm.cancel(2)
                    nm.cancel(3)
                } catch (_: Exception) {}
            }, delay)
        }
    }

    override fun onDestroy() {
        try { unregisterReceiver(disconnectReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(server: String): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val disconnectIntent = PendingIntent.getBroadcast(
            this, 1,
            Intent(ACTION_DISCONNECT_INTERNAL).setPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("EndVPN подключён")
            .setContentText(if (server.isNotEmpty()) "Сервер: $server" else "Соединение активно")
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_delete, "Отключить", disconnectIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            // Наш канал
            val ch = NotificationChannel(CHANNEL_ID, "VPN Статус", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Статус VPN соединения"
                setShowBadge(false)
            }
            nm.createNotificationChannel(ch)

            // Глушим системный канал "VPN Connected" от Android
            try {
                val sysChannel = NotificationChannel(
                    "vpn_connected", "VPN", NotificationManager.IMPORTANCE_NONE
                ).apply {
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                }
                nm.createNotificationChannel(sysChannel)
            } catch (_: Exception) {}

            // Глушим канал singbox плагина
            try {
                val sbChannel = NotificationChannel(
                    "service", "Service", NotificationManager.IMPORTANCE_NONE
                ).apply {
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                }
                nm.createNotificationChannel(sbChannel)
            } catch (_: Exception) {}
        }
    }

    companion object {
        const val CHANNEL_ID                 = "endvpn_status"
        const val NOTIF_ID                   = 1337
        const val EXTRA_CONNECTED            = "connected"
        const val EXTRA_SERVER               = "server"
        const val ACTION_DISCONNECT_NOTIF    = "com.example.endvpn.NOTIF_DISCONNECT"
        const val ACTION_DISCONNECT_INTERNAL = "com.example.endvpn.NOTIF_DISCONNECT_INTERNAL"

        fun start(context: Context, connected: Boolean, server: String) {
            val intent = Intent(context, VpnNotificationService::class.java).apply {
                putExtra(EXTRA_CONNECTED, connected)
                putExtra(EXTRA_SERVER, server)
            }
            if (connected) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    context.startForegroundService(intent)
                else
                    context.startService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
