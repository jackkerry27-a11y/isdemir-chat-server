package com.example.my_starter_app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.isdemir.app/radio_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val channelName = call.argument<String>("channelName") ?: "İSDEMİR SAHA"
                    val freq = call.argument<String>("freq") ?: "148.550 MHz"
                    val intent = Intent(this, RadioForegroundService::class.java).apply {
                        action = RadioForegroundService.ACTION_START
                        putExtra("channelName", channelName)
                        putExtra("freq", freq)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, RadioForegroundService::class.java).apply {
                        action = RadioForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "📻 İSDEMİR Telsiz Açık"
                    val text = call.argument<String>("text") ?: ""
                    val intent = Intent(this, RadioForegroundService::class.java).apply {
                        action = RadioForegroundService.ACTION_UPDATE
                        putExtra("title", title)
                        putExtra("text", text)
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
