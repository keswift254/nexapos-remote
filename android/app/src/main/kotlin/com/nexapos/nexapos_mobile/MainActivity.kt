package com.nexapos.nexapos_mobile

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var checkoutChannel: MethodChannel? = null
    private var downloadChannel: MethodChannel? = null
    private var appInfoChannel: MethodChannel? = null
    private var updatePermissionChannel: MethodChannel? = null
    private var soundChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        checkoutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nexapos/checkout_return")
        checkoutChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initialCheckoutReturn") result.success(checkoutReturn(intent))
            else result.notImplemented()
        }
        // Lets UpdateService read this device's own currently-installed APK
        // bytes (packageCodePath - the real file on disk, no special
        // permission needed to read an app's own APK) to patch against for
        // a delta update, instead of always downloading the whole new APK.
        appInfoChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nexapos/app_info")
        appInfoChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getApkPath" -> result.success(applicationInfo.sourceDir)
                // An app cannot change the clock, but it can open the system's
                // Date & time screen for the person to do it (Settings > Region
                // and Time in NexaPOS). False when this device has no such screen.
                "openDateSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_DATE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        updatePermissionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nexapos/update_permissions"
        )
        updatePermissionChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> {
                    val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        packageManager.canRequestPackageInstalls()
                    result.success(allowed)
                }
                "openInstallPackageSettings" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(true)
                    } else {
                        try {
                            val settings = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(settings)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // The short "message sent" sound of the Support conversation: Dart sends a 16-bit PCM WAV
        // it made itself and this plays it once. A failure here must never break sending.
        soundChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nexapos/sound")
        soundChannel?.setMethodCallHandler { call, result ->
            if (call.method == "play") {
                val wav = call.arguments as? ByteArray
                if (wav != null) playWav(wav)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        downloadChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nexapos/download_service")
        downloadChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start", "update" -> {
                    val serviceIntent = Intent(this, DownloadForegroundService::class.java)
                    serviceIntent.putExtra(DownloadForegroundService.EXTRA_TEXT, call.argument<String>("text") ?: "Downloading update...")
                    serviceIntent.putExtra(DownloadForegroundService.EXTRA_PROGRESS, call.argument<Int>("progress") ?: -1)
                    ContextCompat.startForegroundService(this, serviceIntent)
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, DownloadForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun le16(b: ByteArray, at: Int): Int = (b[at].toInt() and 0xFF) or ((b[at + 1].toInt() and 0xFF) shl 8)

    private fun le32(b: ByteArray, at: Int): Int = le16(b, at) or (le16(b, at + 2) shl 16)

    private fun playWav(wav: ByteArray) {
        try {
            // Walk the RIFF chunks: "fmt " gives the channels and sample rate, "data" holds the
            // 16-bit PCM. (Not a fixed 44-byte header: converters may add chunks of their own.)
            var sampleRate = 0
            var channels = 1
            var dataStart = -1
            var dataLength = 0
            var at = 12
            while (at + 8 <= wav.size) {
                val id = String(wav, at, 4, Charsets.US_ASCII)
                val size = le32(wav, at + 4)
                if (size < 0) return
                if (id == "fmt " && at + 16 <= wav.size) {
                    channels = le16(wav, at + 10)
                    sampleRate = le32(wav, at + 12)
                } else if (id == "data") {
                    dataStart = at + 8
                    dataLength = minOf(size, wav.size - dataStart)
                    break
                }
                at += 8 + size + (size and 1)
            }
            if (dataStart < 0 || dataLength <= 0 || sampleRate <= 0 || (channels != 1 && channels != 2)) return
            val pcm = wav.copyOfRange(dataStart, dataStart + dataLength)
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(if (channels == 2) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(pcm.size)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            track.write(pcm, 0, pcm.size)
            track.play()
            val milliseconds = pcm.size / (2 * channels) * 1000L / sampleRate
            Handler(Looper.getMainLooper()).postDelayed({ track.release() }, milliseconds + 300)
        } catch (e: Exception) {
            // No sound is better than a failed message.
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkoutReturn(intent)?.let { checkoutChannel?.invokeMethod("checkoutReturn", it) }
    }

    private fun checkoutReturn(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        return if (uri.scheme == "nexapos" && uri.host == "checkout-return") uri.toString() else null
    }
}
