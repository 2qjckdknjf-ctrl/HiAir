package com.hiair

import android.content.Context
import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging

/**
 * Compiled only when `app/google-services.json` exists (see `app/build.gradle.kts`).
 * Do not commit real Firebase JSON; path is gitignored.
 */
object FcmFirebaseBootstrap {
    private const val TAG = "HiAirPush"

    @JvmStatic
    fun refresh(context: Context, onComplete: Runnable) {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.w(TAG, "Push: FCM token task failed — ${task.exception?.message}")
                onComplete.run()
                return@addOnCompleteListener
            }
            val token = task.result
            if (token.isNullOrBlank()) {
                Log.w(TAG, "Push: FCM token was empty")
                onComplete.run()
                return@addOnCompleteListener
            }
            context.applicationContext.getSharedPreferences("hiair_push", Context.MODE_PRIVATE)
                .edit()
                .putString("fcm_token", token)
                .apply()
            Log.i(TAG, "Push: FCM token cached locally for backend upload")
            onComplete.run()
        }
    }
}
