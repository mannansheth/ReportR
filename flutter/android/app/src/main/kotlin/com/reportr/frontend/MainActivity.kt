package com.reportr.frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reportr/maps_config")
            .setMethodCallHandler { call, result ->
                if (call.method != "isConfigured") {
                    result.notImplemented()
                } else {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val key = info.metaData?.getString("com.google.android.geo.API_KEY")?.trim().orEmpty()
                    result.success(key.isNotEmpty() && !key.startsWith("YOUR_"))
                }
            }
    }
}
