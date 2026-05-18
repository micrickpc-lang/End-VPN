package com.example.endvpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

// Этот класс зарегистрирован в манифесте — должен иметь пустой конструктор
class VpnBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            VpnNotificationService.ACTION_DISCONNECT_NOTIF -> {
                // Пробрасываем через глобальный callback
                disconnectCallback?.invoke()
            }
        }
    }

    companion object {
        var disconnectCallback: (() -> Unit)? = null
    }
}