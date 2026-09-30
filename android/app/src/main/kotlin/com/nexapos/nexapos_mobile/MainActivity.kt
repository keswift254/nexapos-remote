package com.nexapos.nexapos_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
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
