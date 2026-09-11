package com.example.digital_islamic_hub_new

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "dnd_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE)
                        as NotificationManager

            when (call.method) {

                "checkDndPermission" -> {
                    result.success(notificationManager.isNotificationPolicyAccessGranted)
                }

                "openDndSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }

                "enableDND" -> {
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        notificationManager.setInterruptionFilter(
                            NotificationManager.INTERRUPTION_FILTER_NONE
                        )
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "disableDND" -> {
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        notificationManager.setInterruptionFilter(
                            NotificationManager.INTERRUPTION_FILTER_ALL
                        )
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }

        }
    }
}