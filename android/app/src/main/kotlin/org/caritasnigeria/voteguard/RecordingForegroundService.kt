package org.caritasnigeria.voteguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.File

class RecordingForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "voteguard_recording"
        const val NOTIFICATION_ID = 4401

        const val ACTION_START_KEEPALIVE = "org.caritasnigeria.voteguard.START_KEEPALIVE"
        const val ACTION_START_AUDIO = "org.caritasnigeria.voteguard.START_AUDIO"
        const val ACTION_STOP_AUDIO = "org.caritasnigeria.voteguard.STOP_AUDIO"
        const val ACTION_STOP_ALL = "org.caritasnigeria.voteguard.STOP_ALL"

        const val EXTRA_MODE = "mode"
        const val EXTRA_PATH = "path"

        @Volatile
        var currentAudioPath: String? = null
            private set

        @Volatile
        var isRecordingAudio: Boolean = false
            private set

        private var audioRecorder: MediaRecorder? = null

        fun stopActiveAudioRecorder(): String? {
            val savedPath = currentAudioPath
            try {
                audioRecorder?.apply {
                    stop()
                    reset()
                    release()
                }
            } catch (_: Exception) {
                try {
                    audioRecorder?.reset()
                    audioRecorder?.release()
                } catch (_: Exception) {}
            } finally {
                audioRecorder = null
                isRecordingAudio = false
                currentAudioPath = null
            }
            return savedPath
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_AUDIO -> {
                val path = intent.getStringExtra(EXTRA_PATH)
                val mode = "audio"
                promoteForeground(mode)
                acquireWakeLock()
                if (!path.isNullOrBlank()) {
                    startAudioCapture(path)
                }
            }
            ACTION_START_KEEPALIVE -> {
                val mode = intent.getStringExtra(EXTRA_MODE) ?: "video"
                promoteForeground(mode)
                acquireWakeLock()
            }
            ACTION_STOP_AUDIO -> {
                stopActiveAudioRecorder()
                releaseWakeLock()
                stopForegroundCompat()
                stopSelf()
            }
            ACTION_STOP_ALL -> {
                stopActiveAudioRecorder()
                releaseWakeLock()
                stopForegroundCompat()
                stopSelf()
            }
            else -> {
                promoteForeground("video")
                acquireWakeLock()
            }
        }
        return START_STICKY
    }

    private fun promoteForeground(mode: String) {
        ensureNotificationChannel()
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        val label = if (mode == "audio") {
            "Recording voice evidence in the background"
        } else {
            "Recording video evidence (background protected)"
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("VoteGuard Incident Recording")
            .setContentText(label)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val fgsType = if (mode == "audio") {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            startForeground(NOTIFICATION_ID, notification, fgsType)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val fgsType = if (mode == "audio") {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            startForeground(NOTIFICATION_ID, notification, fgsType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startAudioCapture(outputPath: String) {
        stopActiveAudioRecorder()
        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()

        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        recorder.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(128000)
            setAudioSamplingRate(44100)
            setOutputFile(outputPath)
            prepare()
            start()
        }
        audioRecorder = recorder
        currentAudioPath = outputPath
        isRecordingAudio = true
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "VoteGuard:RecordingWakeLock").apply {
            setReferenceCounted(false)
            acquire(30 * 60 * 1000L) // up to 30 min continuous recording guard
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "VoteGuard Recording",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps incident audio/video recording active in the background"
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        stopActiveAudioRecorder()
        releaseWakeLock()
        super.onDestroy()
    }
}

