package com.nexapos.nexapos_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps this app's process at Android's foreground-priority tier for as
 * long as the in-app update download is running, via the persistent
 * notification Android requires in exchange for that priority. This
 * service does no downloading of its own - UpdateService's existing Dart
 * download keeps running exactly as before; without this, that download
 * ran with no protection from Android's background app management (or a
 * phone maker's more aggressive battery-saving mode), and could be cut
 * off just from the user switching away from NexaPOS mid-download.
 */
class DownloadForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "nexapos_update_download"
        const val NOTIFICATION_ID = 4201
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: "Downloading update..."
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1
        val notification = buildNotification(text, progress)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    // Re-posting via startForeground (called again from onStartCommand for
    // every progress update the Dart side sends) is the standard, simplest
    // way to update an already-showing foreground notification - no bind
    // step or extra IPC needed beyond the MethodChannel calls already
    // driving this service's Intents.
    private fun buildNotification(text: String, progress: Int): Notification {
        createChannelIfNeeded()
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("NexaPOS update")
            .setContentText(text)
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        if (progress in 0..100) {
            builder.setProgress(100, progress, false)
        } else {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "App updates",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Shows progress while a NexaPOS update downloads"
        manager.createNotificationChannel(channel)
    }
}
