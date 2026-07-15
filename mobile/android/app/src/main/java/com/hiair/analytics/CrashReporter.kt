package com.hiair.analytics

import android.content.Context
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig

object CrashReporter {
    private var installed = false

    fun install(context: Context, userIdProvider: () -> String?, accessTokenProvider: () -> String?) {
        if (installed) return
        installed = true
        val appContext = context.applicationContext
        val apiClient = ApiClient(AppConfig.apiBaseUrl)
        val tracker = AnalyticsTracker(appContext)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                apiClient.reportCrash(
                    userId = userIdProvider(),
                    accessToken = accessTokenProvider(),
                    sessionId = tracker.currentSessionId(),
                    message = throwable.message ?: throwable.javaClass.simpleName,
                    stackTrace = throwable.stackTraceToString(),
                    platform = "android",
                    appVersion = "0.1.0"
                )
            } catch (_: Exception) {
                // Best effort only — Firebase Crashlytics can replace this when configured.
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
