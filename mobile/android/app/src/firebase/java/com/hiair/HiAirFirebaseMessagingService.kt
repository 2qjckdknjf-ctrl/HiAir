package com.hiair

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Handles FCM token rotation. Registered in `AndroidManifest.xml` when using Firebase
 * (see `docs/mobile/ANDROID-FCM-LOCAL-INTEGRATION-STEPS.md`).
 */
class HiAirFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        if (token.isBlank()) return
        applicationContext.getSharedPreferences("hiair_push", MODE_PRIVATE)
            .edit()
            .putString("fcm_token", token)
            .apply()
        Log.i(TAG, "Push: FCM onNewToken — token cached locally")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Log.d(TAG, "Push: FCM message received from=${message.from} id=${message.messageId}")
    }

    companion object {
        private const val TAG = "HiAirPush"
    }
}
