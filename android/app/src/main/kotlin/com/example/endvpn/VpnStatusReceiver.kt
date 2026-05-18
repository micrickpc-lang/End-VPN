package com.example.endvpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.os.Handler
import android.os.Looper

// Слушаем broadcast от flutter_singbox плагина напрямую
class VpnStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getStringExtra("status") ?: return
        val connected = status == "Started" || status == "Connected"

        // Обновляем состояние моста
        VpnBridge.isConnected = connected

        // НЕ запускаем VpnNotificationService отсюда — это делает MainActivity через MethodChannel.
        // Здесь только убиваем лишние уведомления от singbox плагина.
        if (connected) {
            cancelSingboxNotifications(context)
        }
    }

    private fun cancelSingboxNotifications(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        val handler = Handler(Looper.getMainLooper())
        // singbox показывает уведомление с задержкой — отменяем в несколько заходов
        listOf(200L, 600L, 1200L, 2500L, 4000L).forEach { delay ->
            handler.postDelayed({
                try {
                    nm.cancel(1)
                    nm.cancel(2)
                    nm.cancel(3)
                } catch (_: Exception) {}
            }, delay)
        }
    }
}