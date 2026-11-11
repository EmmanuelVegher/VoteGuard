package org.caritasnigeria.voteguard

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val recordingChannel = "org.caritasnigeria.voteguard/background_recording"
    private var pendingAudioResult: MethodChannel.Result? = null
    private var pendingAudioPath: String? = null
    private val audioPermRequestCode = 9102

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce modern edge-to-edge window insets without deprecated window flags
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, recordingChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val mode = call.argument<String>("mode") ?: "video"
                        val intent = Intent(this, RecordingForegroundService::class.java).apply {
                            action = RecordingForegroundService.ACTION_START_KEEPALIVE
                            putExtra(RecordingForegroundService.EXTRA_MODE, mode)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(this, RecordingForegroundService::class.java).apply {
                            action = RecordingForegroundService.ACTION_STOP_ALL
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "startAudioRecording" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Output path is required", null)
                            return@setMethodCallHandler
                        }
                        val hasAudioPerm = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!hasAudioPerm) {
                            pendingAudioResult = result
                            pendingAudioPath = path
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                audioPermRequestCode
                            )
                            return@setMethodCallHandler
                        }
                        startAudioService(path)
                        result.success(true)
                    }
                    "stopAudioRecording" -> {
                        val savedPath = RecordingForegroundService.stopActiveAudioRecorder()
                        val intent = Intent(this, RecordingForegroundService::class.java).apply {
                            action = RecordingForegroundService.ACTION_STOP_AUDIO
                        }
                        startService(intent)
                        result.success(savedPath)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startAudioService(path: String) {
        val intent = Intent(this, RecordingForegroundService::class.java).apply {
            action = RecordingForegroundService.ACTION_START_AUDIO
            putExtra(RecordingForegroundService.EXTRA_PATH, path)
            putExtra(RecordingForegroundService.EXTRA_MODE, "audio")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == audioPermRequestCode) {
            val res = pendingAudioResult
            val path = pendingAudioPath
            pendingAudioResult = null
            pendingAudioPath = null
            if (res != null) {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                if (granted && !path.isNullOrBlank()) {
                    startAudioService(path)
                    res.success(true)
                } else {
                    res.error("PERMISSION_DENIED", "Microphone permission denied", null)
                }
            }
        }
    }
}
