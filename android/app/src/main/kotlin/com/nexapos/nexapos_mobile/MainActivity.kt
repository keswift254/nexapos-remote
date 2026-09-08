package com.nexapos.nexapos_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var checkoutChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        checkoutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nexapos/checkout_return")
        checkoutChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initialCheckoutReturn") result.success(checkoutReturn(intent))
            else result.notImplemented()
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
