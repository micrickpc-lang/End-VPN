package com.example.endvpn

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import go.Seq
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray

class XrayVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var controller: CoreController? = null

    override fun onCreate() {
        super.onCreate()
        Seq.setContext(applicationContext)
        Libv2ray.initCoreEnv(filesDir.absolutePath, XRAY_BASE_KEY)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTunnel()
            return START_NOT_STICKY
        }
        val config = intent?.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
        val server = intent.getStringExtra(EXTRA_SERVER).orEmpty()
        startForeground(NOTIFICATION_ID, buildNotification(server))
        try {
            stopCore()
            vpnInterface = Builder()
                .setSession(if (server.isEmpty()) "End VPN" else server)
                .setMtu(1400)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addDisallowedApplication(packageName)
                .establish() ?: error("Не удалось создать VPN-интерфейс")
            controller = Libv2ray.newCoreController(object : CoreCallbackHandler {
                override fun startup(): Long = 0
                override fun shutdown(): Long = 0
                override fun onEmitStatus(code: Long, message: String?): Long = 0
            }).also { it.startLoop(config, vpnInterface!!.fd) }
            sendStatus("Started")
        } catch (error: Exception) {
            sendStatus("Error", error.message)
            stopTunnel()
        }
        return START_STICKY
    }

    override fun onRevoke() = stopTunnel()

    override fun onDestroy() {
        stopCore()
        super.onDestroy()
    }

    private fun stopCore() {
        try { controller?.stopLoop() } catch (_: Exception) {}
        controller = null
        try { vpnInterface?.close() } catch (_: Exception) {}
        vpnInterface = null
    }

    private fun stopTunnel() {
        stopCore()
        sendStatus("Stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun sendStatus(status: String, error: String? = null) {
        sendBroadcast(Intent(ACTION_STATUS).setPackage(packageName)
            .putExtra("status", status).putExtra("error", error))
    }

    private fun buildNotification(server: String): android.app.Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_lock_lock)
        .setContentTitle("END VPN подключён")
        .setContentText("Сервер: ${serverLabel(server)}")
        .setOngoing(true)
        .setShowWhen(false)
        .setContentIntent(openAppIntent)
        .addAction(
            android.R.drawable.ic_delete,
            "Отключить",
            PendingIntent.getService(
                this,
                1,
                Intent(this, XrayVpnService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        .build()
    }

    private fun serverLabel(server: String): String {
        if (server.isBlank()) return "🌐 Выбранный сервер"
        if (server.any { Character.getType(it) == Character.SURROGATE.toInt() }) return server
        val normalized = server.lowercase()
        val flag = when {
            "нидерланд" in normalized || "netherland" in normalized || normalized.startsWith("nl") -> "🇳🇱"
            "герман" in normalized || "german" in normalized || normalized.startsWith("de") -> "🇩🇪"
            "литва" in normalized || "lithuan" in normalized || normalized.startsWith("lt") -> "🇱🇹"
            "латви" in normalized || "latvia" in normalized || normalized.startsWith("lv") -> "🇱🇻"
            "финлянд" in normalized || "finland" in normalized || normalized.startsWith("fi") -> "🇫🇮"
            "сша" in normalized || "united states" in normalized || normalized.startsWith("us") -> "🇺🇸"
            else -> "🌐"
        }
        return "$flag $server"
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    companion object {
        const val ACTION_STOP = "com.example.endvpn.XRAY_STOP"
        const val ACTION_STATUS = "com.example.endvpn.XRAY_STATUS"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_SERVER = "server"
        const val CHANNEL_ID = "endvpn_xray"
        const val NOTIFICATION_ID = 1338
        private const val XRAY_BASE_KEY = "AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA"
    }
}
