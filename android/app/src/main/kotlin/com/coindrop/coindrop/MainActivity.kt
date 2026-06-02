package com.coindrop.coindrop

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.coindrop.coindrop/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // SECURITY: FLAG_SECURE prevents screenshots, screen recording,
        // and app switcher preview thumbnails that could leak financial data.
        // This applies app-wide to all activities.
        // Must use FlutterFragmentActivity (not FlutterActivity) for
        // compatibility with local_auth BiometricPrompt.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureMode" -> {
                    val secure = call.argument<Boolean>("secure") ?: true
                    runOnUiThread {
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
