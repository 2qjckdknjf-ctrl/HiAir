package com.hiair

import android.app.Activity
import android.util.Log

/**
 * Bridges to [FcmFirebaseBootstrap] only when `BuildConfig.FIREBASE_CONFIGURED` is true
 * (Gradle adds Firebase sources + deps when `google-services.json` is present).
 */
object FcmTokenRefresher {
    private const val TAG = "HiAirPush"

    fun refreshCachedToken(activity: Activity, onDone: () -> Unit) {
        if (!BuildConfig.FIREBASE_CONFIGURED) {
            onDone()
            return
        }
        try {
            val clazz = Class.forName("com.hiair.FcmFirebaseBootstrap")
            val method = clazz.getMethod(
                "refresh",
                android.content.Context::class.java,
                Runnable::class.java
            )
            method.invoke(null, activity.applicationContext, Runnable { onDone() })
        } catch (e: Exception) {
            Log.w(TAG, "Push: FCM bootstrap unavailable — ${e.message}")
            onDone()
        }
    }
}
