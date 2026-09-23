package com.nexapos.nexapos_mobile

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var checkoutChannel: MethodChannel? = null
    private var downloadChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        checkoutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nexapos/checkout_return")
        checkoutChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initialCheckoutReturn") result.success(checkoutReturn(intent))
            else result.notImplemented()
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
