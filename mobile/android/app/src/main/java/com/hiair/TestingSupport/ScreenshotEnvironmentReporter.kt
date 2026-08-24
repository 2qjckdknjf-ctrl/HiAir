package com.hiair

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.util.Locale
import java.util.TimeZone

/** Writes runtime-observed capture environment (Android). */
object ScreenshotEnvironmentReporter {
    fun reportIfNeeded(context: Context?, captureOut: String?, runId: String?) {
        if (!BuildConfig.DEBUG || context == null) return
        if (!StoreScreenshotMode.active) return
        val out = captureOut?.takeIf { it.isNotBlank() } ?: return
        val id = runId?.takeIf { it.isNotBlank() } ?: return

        val dir = File(out)
        dir.mkdirs()
        val target = File(dir, "app-observed-environment.json")
        if (target.exists()) {
            runCatching {
                val prior = JSONObject(target.readText())
                if (prior.optString("captureRunId") == id) return
            }
        }

        val metrics = context.resources.displayMetrics
        val config = context.resources.configuration
        val payload = JSONObject()
            .put("captureRunId", id)
            .put("locale", Locale.getDefault().toLanguageTag())
            .put("fontScale", config.fontScale.toDouble())
            .put("densityDpi", metrics.densityDpi)
            .put("widthPx", metrics.widthPixels)
            .put("heightPx", metrics.heightPixels)
            .put("timezone", TimeZone.getDefault().id)
            .put("packageName", context.packageName)
            .put("versionName", BuildConfig.VERSION_NAME)
            .put("versionCode", BuildConfig.VERSION_CODE)
            .put("targetScreen", StoreScreenshotMode.targetScreen ?: JSONObject.NULL)
            .put(
                "reduceMotion",
                android.provider.Settings.Global.getFloat(
                    context.contentResolver,
                    android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,
                    1f,
                ) == 0f,
            )
        target.writeText(payload.toString(2) + "\n")
    }
}
