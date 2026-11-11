package org.caritasnigeria.voteguard

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val audioChannel = "org.caritasnigeria.voteguard/foreground_audio"
    private var audioRecorder: MediaRecorder? = null
    private var currentAudioPath: String? = null
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                        try {
                            startForegroundMediaRecorder(path)
                            result.success(true)
                        } catch (e: Exception) {
                            stopForegroundMediaRecorder()
                            result.error("RECORDER_ERROR", e.message, null)
                        }
                    }
                    "stopAudioRecording" -> {
                        val savedPath = stopForegroundMediaRecorder()
                        result.success(savedPath)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startForegroundMediaRecorder(outputPath: String) {
        stopForegroundMediaRecorder()
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
    }

    private fun stopForegroundMediaRecorder(): String? {
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
            currentAudioPath = null
        }
        return savedPath
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
                    try {
                        startForegroundMediaRecorder(path)
                        res.success(true)
                    } catch (e: Exception) {
                        stopForegroundMediaRecorder()
                        res.error("RECORDER_ERROR", e.message, null)
                    }
                } else {
                    res.error("PERMISSION_DENIED", "Microphone permission denied", null)
                }
            }
        }
    }

    override fun onDestroy() {
        stopForegroundMediaRecorder()
        super.onDestroy()
    }
}
