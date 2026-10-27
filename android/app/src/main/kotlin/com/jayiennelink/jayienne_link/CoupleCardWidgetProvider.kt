package com.jayiennelink.jayienne_link

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.*
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min

class CoupleCardWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "jayienne_home_widget_prefs"
        const val ACTION_TOGGLE_EXPAND = "com.jayiennelink.jayienne_link.ACTION_TOGGLE_EXPAND"
        const val ACTION_REFRESH_WIDGET = "com.jayiennelink.jayienne_link.ACTION_REFRESH_WIDGET"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, CoupleCardWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isNotEmpty()) {
                val provider = CoupleCardWidgetProvider()
                provider.onUpdate(context, manager, ids)
                scheduleNextOfflineTick(context)
            } else {
                cancelOfflineTick(context)
            }
        }

        private fun scheduleNextOfflineTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, CoupleCardWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH_WIDGET
                }
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                val pendingIntent = PendingIntent.getBroadcast(context, 9021, intent, flags)
                val triggerAt = System.currentTimeMillis() + 60_000L
                alarmManager.setWindow(
                    AlarmManager.RTC,
                    triggerAt,
                    15_000L,
                    pendingIntent
                )
            } catch (_: Exception) {
            }
        }

        private fun cancelOfflineTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, CoupleCardWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH_WIDGET
                }
                val flags = PendingIntent.FLAG_NO_CREATE or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                val pendingIntent = PendingIntent.getBroadcast(context, 9021, intent, flags)
                if (pendingIntent != null) {
                    alarmManager.cancel(pendingIntent)
                }
            } catch (_: Exception) {
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_TOGGLE_EXPAND -> {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val current = prefs.getBoolean("is_expanded", false)
                prefs.edit().putBoolean("is_expanded", !current).apply()
                updateAllWidgets(context)
            }
            ACTION_REFRESH_WIDGET,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                updateAllWidgets(context)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, widgetId)
        }
        if (appWidgetIds.isNotEmpty()) {
            scheduleNextOfflineTick(context)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateSingleWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelOfflineTick(context)
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isExpanded = prefs.getBoolean("is_expanded", false)
        val hasDate = prefs.getBoolean("has_date", true)
        val anniversaryEpochMs = prefs.getLong("anniversary_epoch_ms", 0L)
        val userZodiac = prefs.getString("user_zodiac", "") ?: ""
        val partnerZodiac = prefs.getString("partner_zodiac", "") ?: ""
        val isLinked = prefs.getBoolean("is_linked", true)
        val isPartnerOnline = prefs.getBoolean("is_partner_online", false)
        val partnerLastSeenMs = prefs.getLong("partner_last_seen_ms", 0L)
        val distanceString = prefs.getString("distance_string", "Location active") ?: "Location active"
        val partnerBatLevel = prefs.getInt("partner_battery_level", -1)
        val partnerIsCharging = prefs.getBoolean("partner_is_charging", false)
        val userAvatarPath = prefs.getString("user_avatar_path", "") ?: ""
        val partnerAvatarPath = prefs.getString("partner_avatar_path", "") ?: ""

        val (liveMyBattery, liveMyCharging) = readDeviceBattery(
            context,
            prefs.getInt("my_battery_level", 100),
            prefs.getBoolean("my_is_charging", false)
        )

        val nowMs = System.currentTimeMillis()
        val metrics = computeOfflineAnniversaryMetrics(anniversaryEpochMs, hasDate, nowMs)
        val partnerStatusText = computePartnerStatusText(
            isPartnerOnline = isPartnerOnline,
            partnerLastSeenMs = partnerLastSeenMs,
            fallback = prefs.getString("partner_status_text", "Offline") ?: "Offline"
        )

        val views = RemoteViews(context.packageName, R.layout.couple_card_widget)

        // 1. Tap anywhere on the card to toggle Hide / Unhide (identical to Main Screen)
        val toggleIntent = Intent(context, CoupleCardWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE_EXPAND
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val togglePendingIntent = PendingIntent.getBroadcast(context, 1001, toggleIntent, piFlags)
        views.setOnClickPendingIntent(R.id.widget_card_container, togglePendingIntent)

        // 2. Top Header Row: Live 1-Second Ticking Flipper + Expand/Collapse Arrow
        if (metrics.hasValidDate) {
            views.setViewVisibility(R.id.widget_header_row, View.VISIBLE)
            views.setImageViewResource(
                R.id.widget_chevron_icon,
                if (isExpanded) R.drawable.ic_widget_chevron_up else R.drawable.ic_widget_chevron_down
            )

            views.removeAllViews(R.id.seconds_flipper)
            val startSec = metrics.secondsRemainder.toInt()
            for (i in 0 until 60) {
                val sec = (startSec + i) % 60
                val secItem = RemoteViews(context.packageName, R.layout.widget_second_item)
                secItem.setTextViewText(R.id.second_text, String.format(Locale.US, "%02ds", sec))
                views.addView(R.id.seconds_flipper, secItem)
            }
        } else {
            views.setViewVisibility(R.id.widget_header_row, View.GONE)
        }

        // 3. Dual Circular Avatars with White Ring + Status Indicator
        val userAvatarBmp = renderAvatarRingBitmap(
            avatarPath = userAvatarPath,
            showStatus = false,
            isOnline = true
        )
        views.setImageViewBitmap(R.id.widget_user_avatar, userAvatarBmp)

        val partnerAvatarBmp = renderAvatarRingBitmap(
            avatarPath = partnerAvatarPath,
            showStatus = true,
            isOnline = isPartnerOnline
        )
        views.setImageViewBitmap(R.id.widget_partner_avatar, partnerAvatarBmp)

        // 4. User & Partner Status & Zodiac Pills
        if (userZodiac.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_user_zodiac_pill, View.VISIBLE)
            views.setTextViewText(R.id.widget_user_zodiac_text, userZodiac)
            views.setImageViewBitmap(R.id.widget_user_zodiac_icon, renderZodiacIconBitmap(userZodiac))
        } else {
            views.setViewVisibility(R.id.widget_user_zodiac_pill, View.GONE)
        }

        if (isLinked) {
            views.setViewVisibility(R.id.widget_partner_status_pill, View.VISIBLE)
            views.setTextViewText(R.id.widget_partner_status_text, partnerStatusText)
            views.setImageViewResource(
                R.id.widget_partner_status_dot,
                if (isPartnerOnline) R.drawable.dot_online else R.drawable.dot_offline
            )
        } else {
            views.setViewVisibility(R.id.widget_partner_status_pill, View.GONE)
        }

        if (partnerZodiac.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_partner_zodiac_pill, View.VISIBLE)
            views.setTextViewText(R.id.widget_partner_zodiac_text, partnerZodiac)
            views.setImageViewBitmap(R.id.widget_partner_zodiac_icon, renderZodiacIconBitmap(partnerZodiac))
        } else {
            views.setViewVisibility(R.id.widget_partner_zodiac_pill, View.GONE)
        }

        // 5. Main Love Counter ("469 Days Together" + "1 Year • 3 Months • 12 Days")
        if (metrics.hasValidDate) {
            views.setViewVisibility(R.id.widget_love_counter_body, View.VISIBLE)
            views.setTextViewText(R.id.widget_days_together_title, "${metrics.totalDays} Days Together")

            val yrLabel = if (metrics.years == 1) "Year" else "Years"
            val moLabel = if (metrics.months == 1) "Month" else "Months"
            val dyLabel = if (metrics.days == 1) "Day" else "Days"
            views.setTextViewText(
                R.id.widget_days_breakdown_pill,
                "${metrics.years} $yrLabel • ${metrics.months} $moLabel • ${metrics.days} $dyLabel"
            )
        } else {
            views.setViewVisibility(R.id.widget_love_counter_body, View.GONE)
        }

        // 6. Expandable Section (Unhidden Mode with Live 1-Second Duration Ticker)
        if (isExpanded && metrics.hasValidDate) {
            views.setViewVisibility(R.id.widget_expanded_section, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_anniversary_date_text,
                "Anniversary: ${metrics.formattedAnniversaryDate}"
            )

            views.removeAllViews(R.id.duration_flipper)
            for (i in 0 until 60) {
                val futureMetrics = computeOfflineAnniversaryMetrics(
                    anniversaryEpochMs,
                    hasDate,
                    nowMs + i * 1000L
                )
                val durItem = RemoteViews(context.packageName, R.layout.widget_duration_item)
                val durStr = "${futureMetrics.years}y ${futureMetrics.months}m ${futureMetrics.days}d ${futureMetrics.hoursRemainder}h ${futureMetrics.minutesRemainder}m ${futureMetrics.secondsRemainder}s"
                durItem.setTextViewText(R.id.duration_text, durStr)
                views.addView(R.id.duration_flipper, durItem)
            }

            val nextOrd = ordinalSuffix(metrics.nextYearNum)
            views.setTextViewText(
                R.id.widget_next_anniv_text,
                "${metrics.daysUntilNext} days until ${metrics.nextYearNum}$nextOrd Anniversary"
            )
            val pctInt = (metrics.progress * 100f).toInt().coerceIn(0, 100)
            views.setTextViewText(R.id.widget_next_anniv_pct, "$pctInt%")
            views.setProgressBar(R.id.widget_anniv_progress, 100, pctInt, false)
        } else {
            views.setViewVisibility(R.id.widget_expanded_section, View.GONE)
        }

        // 7. Bottom Vitals Bar (My Battery • Distance • Partner Battery or Offline)
        val myBatColor = if (liveMyCharging) Color.parseColor("#FF69F0AE") else Color.WHITE
        views.setImageViewResource(
            R.id.widget_my_bat_icon,
            if (liveMyCharging) R.drawable.ic_widget_battery_charging else R.drawable.ic_widget_battery_full
        )
        views.setTextViewText(R.id.widget_my_bat_text, "$liveMyBattery%")
        views.setTextColor(R.id.widget_my_bat_text, myBatColor)

        views.setTextViewText(
            R.id.widget_distance_text,
            if (distanceString.isNotBlank()) distanceString else "Location active"
        )

        if (isPartnerOnline && partnerBatLevel >= 0) {
            val pColor = if (partnerIsCharging) Color.parseColor("#FF69F0AE") else Color.WHITE
            views.setImageViewResource(
                R.id.widget_partner_vitals_icon,
                if (partnerIsCharging) R.drawable.ic_widget_battery_charging else R.drawable.ic_widget_battery_full
            )
            views.setTextViewText(R.id.widget_partner_vitals_text, "$partnerBatLevel%")
            views.setTextColor(R.id.widget_partner_vitals_text, pColor)
        } else {
            views.setImageViewResource(R.id.widget_partner_vitals_icon, R.drawable.ic_widget_wifi_off)
            views.setTextViewText(R.id.widget_partner_vitals_text, "Offline")
            views.setTextColor(R.id.widget_partner_vitals_text, Color.parseColor("#B3FFFFFF"))
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun renderAvatarRingBitmap(
        avatarPath: String,
        showStatus: Boolean,
        isOnline: Boolean
    ): Bitmap {
        val size = 220
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = size / 2f
        val cy = size / 2f
        val radius = 92f

        // Soft shadow under avatar
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(45, 0, 0, 0)
            maskFilter = BlurMaskFilter(12f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawCircle(cx, cy + 5f, radius, shadowPaint)

        // Avatar image or fallback silhouette
        val sourceBmp = loadAvatarBitmap(avatarPath, 200)
        if (sourceBmp != null) {
            val shader = BitmapShader(sourceBmp, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            val matrix = Matrix()
            val scale = (radius * 2f) / min(sourceBmp.width, sourceBmp.height).toFloat()
            matrix.setScale(scale, scale)
            matrix.postTranslate(
                cx - (sourceBmp.width * scale) / 2f,
                cy - (sourceBmp.height * scale) / 2f
            )
            shader.setLocalMatrix(matrix)
            val imgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.shader = shader
                isFilterBitmap = true
            }
            canvas.drawCircle(cx, cy, radius, imgPaint)
        } else {
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(65, 255, 255, 255)
            }
            canvas.drawCircle(cx, cy, radius, bgPaint)

            val personPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
            }
            canvas.drawCircle(cx, cy - radius * 0.18f, radius * 0.28f, personPaint)
            canvas.save()
            val clipPath = Path().apply {
                addCircle(cx, cy, radius, Path.Direction.CW)
            }
            canvas.clipPath(clipPath)
            canvas.drawRoundRect(
                RectF(cx - radius * 0.48f, cy + radius * 0.18f, cx + radius * 0.48f, cy + radius * 0.85f),
                radius * 0.35f,
                radius * 0.35f,
                personPaint
            )
            canvas.restore()
        }

        // Crisp White Ring Border
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 8.5f
            color = Color.WHITE
        }
        canvas.drawCircle(cx, cy, radius, ringPaint)

        // Online / Offline Status Indicator Badge (Bottom-Right)
        if (showStatus) {
            val badgeCx = cx + radius * 0.68f
            val badgeCy = cy + radius * 0.68f
            val badgeR = 23f

            val statusFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (isOnline) Color.rgb(76, 175, 80) else Color.rgb(142, 142, 147)
            }
            val statusBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 6.5f
                color = Color.WHITE
            }
            canvas.drawCircle(badgeCx, badgeCy, badgeR, statusFill)
            canvas.drawCircle(badgeCx, badgeCy, badgeR, statusBorder)

            if (!isOnline) {
                val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                }
                canvas.drawCircle(badgeCx, badgeCy, 5.5f, dotPaint)
            }
        }

        return bmp
    }

    private fun renderZodiacIconBitmap(zodiac: String): Bitmap {
        val size = 36
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = size / 2f
        val cy = size / 2f
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 4.2f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            color = Color.WHITE
        }
        val lower = zodiac.lowercase(Locale.US)
        val path = Path()
        when {
            lower.contains("aquarius") -> {
                path.moveTo(4f, cy - 4f)
                path.lineTo(10f, cy - 9f)
                path.lineTo(16f, cy - 4f)
                path.lineTo(22f, cy - 9f)
                path.lineTo(28f, cy - 4f)
                path.lineTo(32f, cy - 7f)

                path.moveTo(4f, cy + 7f)
                path.lineTo(10f, cy + 2f)
                path.lineTo(16f, cy + 7f)
                path.lineTo(22f, cy + 2f)
                path.lineTo(28f, cy + 7f)
                path.lineTo(32f, cy + 4f)
                canvas.drawPath(path, p)
            }
            lower.contains("sagittarius") -> {
                canvas.drawLine(7f, 29f, 29f, 7f, p)
                canvas.drawLine(17f, 7f, 29f, 7f, p)
                canvas.drawLine(29f, 19f, 29f, 7f, p)
                canvas.drawLine(10f, 16f, 20f, 26f, p)
            }
            else -> {
                canvas.drawLine(cx - 10f, cy, cx + 10f, cy, p)
                canvas.drawLine(cx, cy - 10f, cx, cy + 10f, p)
                canvas.drawLine(cx - 7f, cy - 7f, cx + 7f, cy + 7f, p)
                canvas.drawLine(cx + 7f, cy - 7f, cx - 7f, cy + 7f, p)
            }
        }
        return bmp
    }

    private fun loadAvatarBitmap(path: String, targetSize: Int): Bitmap? {
        if (path.isBlank()) return null
        val file = File(path)
        if (!file.exists()) return null
        return try {
            val opts = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(file.absolutePath, opts)
            var sampleSize = 1
            while (opts.outWidth / sampleSize > targetSize * 2 && opts.outHeight / sampleSize > targetSize * 2) {
                sampleSize *= 2
            }
            val decodeOpts = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
            }
            BitmapFactory.decodeFile(file.absolutePath, decodeOpts)
        } catch (_: Exception) {
            null
        }
    }

    private fun readDeviceBattery(
        context: Context,
        fallbackLevel: Int,
        fallbackCharging: Boolean
    ): Pair<Int, Boolean> {
        return try {
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            val level = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: fallbackLevel
            val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            Pair(if (level in 0..100) level else fallbackLevel, charging)
        } catch (_: Exception) {
            Pair(fallbackLevel, fallbackCharging)
        }
    }

    private fun computePartnerStatusText(
        isPartnerOnline: Boolean,
        partnerLastSeenMs: Long,
        fallback: String
    ): String {
        if (isPartnerOnline) return "Active Now"
        if (partnerLastSeenMs <= 0L) return fallback

        val nowMs = System.currentTimeMillis()
        val diffMs = max(0L, nowMs - partnerLastSeenMs)
        val totalSeconds = diffMs / 1000L
        val totalMinutes = totalSeconds / 60L
        val totalHours = totalMinutes / 60L
        val totalDays = totalHours / 24L

        val nowCal = Calendar.getInstance()
        val lastCal = Calendar.getInstance().apply { timeInMillis = partnerLastSeenMs }

        val timeSnippet = when {
            totalSeconds < 60L -> "just now"
            totalMinutes < 60L -> "${totalMinutes}m ago"
            totalHours < 24L && nowCal.get(Calendar.DAY_OF_YEAR) == lastCal.get(Calendar.DAY_OF_YEAR) ->
                "${totalHours}h ago"
            totalDays < 2L -> "yesterday"
            totalDays < 7L -> SimpleDateFormat("E", Locale.US).format(Date(partnerLastSeenMs))
            nowCal.get(Calendar.YEAR) == lastCal.get(Calendar.YEAR) ->
                SimpleDateFormat("MMM d", Locale.US).format(Date(partnerLastSeenMs))
            else -> SimpleDateFormat("MMM d, yyyy", Locale.US).format(Date(partnerLastSeenMs))
        }
        return "Last online $timeSnippet"
    }

    private data class AnniversaryMetrics(
        val hasValidDate: Boolean,
        val totalDays: Long,
        val years: Int,
        val months: Int,
        val days: Int,
        val hoursRemainder: Long,
        val minutesRemainder: Long,
        val secondsRemainder: Long,
        val daysUntilNext: Long,
        val nextYearNum: Int,
        val progress: Float,
        val formattedAnniversaryDate: String
    )

    private fun computeOfflineAnniversaryMetrics(
        anniversaryEpochMs: Long,
        hasDate: Boolean,
        nowMs: Long
    ): AnniversaryMetrics {
        if (!hasDate || anniversaryEpochMs <= 0L) {
            return AnniversaryMetrics(
                hasValidDate = false,
                totalDays = 0,
                years = 0,
                months = 0,
                days = 0,
                hoursRemainder = 0,
                minutesRemainder = 0,
                secondsRemainder = 0,
                daysUntilNext = 0,
                nextYearNum = 1,
                progress = 0f,
                formattedAnniversaryDate = ""
            )
        }

        val diffMs = max(0L, nowMs - anniversaryEpochMs)
        val totalSeconds = diffMs / 1000L
        val totalMinutes = totalSeconds / 60L
        val totalHours = totalMinutes / 60L
        val totalDays = totalHours / 24L

        val nowCal = Calendar.getInstance().apply { timeInMillis = nowMs }
        val annivCal = Calendar.getInstance().apply { timeInMillis = anniversaryEpochMs }

        val nYear = nowCal.get(Calendar.YEAR)
        val nMonth = nowCal.get(Calendar.MONTH)
        val nDay = nowCal.get(Calendar.DAY_OF_MONTH)

        val aYear = annivCal.get(Calendar.YEAR)
        val aMonth = annivCal.get(Calendar.MONTH)
        val aDay = annivCal.get(Calendar.DAY_OF_MONTH)

        var years = nYear - aYear
        if (nMonth < aMonth || (nMonth == aMonth && nDay < aDay)) {
            years--
        }
        years = max(0, years)

        var totalMonths = (nYear - aYear) * 12 + (nMonth - aMonth)
        if (nDay < aDay) {
            totalMonths--
        }
        val months = max(0, totalMonths % 12)

        val lastMonthAnniv = Calendar.getInstance().apply {
            set(nYear, nMonth, aDay, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val daysRemainder = if (nowCal.after(lastMonthAnniv)) {
            ((nowMs - lastMonthAnniv.timeInMillis) / 86_400_000L).toInt()
        } else {
            val prevMonthAnniv = Calendar.getInstance().apply {
                set(nYear, nMonth, aDay, 0, 0, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.MONTH, -1)
            }
            ((nowMs - prevMonthAnniv.timeInMillis) / 86_400_000L).toInt()
        }.coerceAtLeast(0)

        val thisYearAnniv = Calendar.getInstance().apply {
            set(nYear, aMonth, aDay, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val nextAnniv = if (nowCal.before(thisYearAnniv)) {
            thisYearAnniv
        } else {
            Calendar.getInstance().apply {
                set(nYear + 1, aMonth, aDay, 0, 0, 0)
                set(Calendar.MILLISECOND, 0)
            }
        }
        val prevAnniv = (nextAnniv.clone() as Calendar).apply {
            add(Calendar.YEAR, -1)
        }

        val daysUntilNext = max(0L, (nextAnniv.timeInMillis - nowMs) / 86_400_000L)
        val nextYearNum = max(1, nextAnniv.get(Calendar.YEAR) - aYear)
        val totalYearMs = max(1L, nextAnniv.timeInMillis - prevAnniv.timeInMillis)
        val elapsedYearMs = (nowMs - prevAnniv.timeInMillis).coerceIn(0L, totalYearMs)
        val progress = (elapsedYearMs.toFloat() / totalYearMs.toFloat()).coerceIn(0f, 1f)

        val formattedDate = SimpleDateFormat("MMMM d, yyyy", Locale.US).format(Date(anniversaryEpochMs))

        return AnniversaryMetrics(
            hasValidDate = true,
            totalDays = totalDays,
            years = years,
            months = months,
            days = daysRemainder,
            hoursRemainder = totalHours % 24L,
            minutesRemainder = totalMinutes % 60L,
            secondsRemainder = totalSeconds % 60L,
            daysUntilNext = daysUntilNext,
            nextYearNum = nextYearNum,
            progress = progress,
            formattedAnniversaryDate = formattedDate
        )
    }

    private fun ordinalSuffix(n: Int): String {
        if (n in 11..13) return "th"
        return when (n % 10) {
            1 -> "st"
            2 -> "nd"
            3 -> "rd"
            else -> "th"
        }
    }
}
