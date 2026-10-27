package com.jayiennelink.jayienne_link

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val WIDGET_CHANNEL = "com.jayiennelink.jayienne_link/home_widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                val prefs = applicationContext.getSharedPreferences(
                    CoupleCardWidgetProvider.PREFS_NAME,
                    Context.MODE_PRIVATE
                )

                when (call.method) {
                    "syncWidgetData" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args != null) {
                            val editor = prefs.edit()
                            (args["has_date"] as? Boolean)?.let { editor.putBoolean("has_date", it) }
                            (args["anniversary_epoch_ms"] as? Number)?.let {
                                editor.putLong("anniversary_epoch_ms", it.toLong())
                            }
                            (args["user_name"] as? String)?.let { editor.putString("user_name", it) }
                            (args["partner_name"] as? String)?.let { editor.putString("partner_name", it) }
                            (args["user_zodiac"] as? String)?.let { editor.putString("user_zodiac", it) }
                            (args["partner_zodiac"] as? String)?.let { editor.putString("partner_zodiac", it) }
                            (args["is_linked"] as? Boolean)?.let { editor.putBoolean("is_linked", it) }
                            (args["is_partner_online"] as? Boolean)?.let {
                                editor.putBoolean("is_partner_online", it)
                            }
                            (args["partner_last_seen_ms"] as? Number)?.let {
                                editor.putLong("partner_last_seen_ms", it.toLong())
                            }
                            (args["partner_status_text"] as? String)?.let {
                                editor.putString("partner_status_text", it)
                            }
                            (args["distance_string"] as? String)?.let {
                                editor.putString("distance_string", it)
                            }
                            (args["my_battery_level"] as? Number)?.let {
                                editor.putInt("my_battery_level", it.toInt())
                            }
                            (args["my_is_charging"] as? Boolean)?.let {
                                editor.putBoolean("my_is_charging", it)
                            }
                            (args["partner_battery_level"] as? Number)?.let {
                                editor.putInt("partner_battery_level", it.toInt())
                            }
                            (args["partner_is_charging"] as? Boolean)?.let {
                                editor.putBoolean("partner_is_charging", it)
                            }
                            (args["pending_anniversary_text"] as? String)?.let {
                                editor.putString("pending_anniversary_text", it)
                            }
                            (args["user_avatar_path"] as? String)?.let {
                                if (it.isNotEmpty()) editor.putString("user_avatar_path", it)
                            }
                            (args["partner_avatar_path"] as? String)?.let {
                                if (it.isNotEmpty()) editor.putString("partner_avatar_path", it)
                            }
                            (args["compact_image_path"] as? String)?.let {
                                if (it.isNotEmpty()) editor.putString("compact_image_path", it)
                            }
                            (args["expanded_image_path"] as? String)?.let {
                                if (it.isNotEmpty()) editor.putString("expanded_image_path", it)
                            }
                            (args["is_expanded"] as? Boolean)?.let {
                                editor.putBoolean("is_expanded", it)
                            }
                            editor.apply()
                            CoupleCardWidgetProvider.updateAllWidgets(applicationContext)
                        }
                        result.success(true)
                    }

                    "setWidgetExpanded" -> {
                        val isExpanded = call.argument<Boolean>("is_expanded") ?: false
                        prefs.edit().putBoolean("is_expanded", isExpanded).apply()
                        CoupleCardWidgetProvider.updateAllWidgets(applicationContext)
                        result.success(true)
                    }

                    "getWidgetExpanded" -> {
                        result.success(prefs.getBoolean("is_expanded", false))
                    }

                    "getPinnedCount" -> {
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val provider = ComponentName(
                            applicationContext,
                            CoupleCardWidgetProvider::class.java
                        )
                        val ids = appWidgetManager.getAppWidgetIds(provider)
                        result.success(ids.size)
                    }

                    "requestPinWidget" -> {
                        val isExpanded = call.argument<Boolean>("is_expanded") ?: false
                        prefs.edit().putBoolean("is_expanded", isExpanded).apply()
                        CoupleCardWidgetProvider.updateAllWidgets(applicationContext)

                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val provider = ComponentName(
                            applicationContext,
                            CoupleCardWidgetProvider::class.java
                        )

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            appWidgetManager.isRequestPinAppWidgetSupported
                        ) {
                            val pinned = appWidgetManager.requestPinAppWidget(provider, null, null)
                            result.success(pinned)
                        } else {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
