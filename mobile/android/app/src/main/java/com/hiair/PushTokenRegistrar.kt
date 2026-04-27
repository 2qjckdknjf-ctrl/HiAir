package com.hiair

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig

class PushTokenRegistrar(
    private val activity: Activity,
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    fun requestPermissionAndRegister(session: StoredSession, profileId: String? = null) {
        Log.i(TAG, "Push: requestPermissionAndRegister")
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.i(TAG, "Push: requesting POST_NOTIFICATIONS permission")
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_POST_NOTIFICATIONS
                )
                return
            }
        }
        registerIfTokenAvailable(session, profileId)
    }

    fun registerIfTokenAvailable(session: StoredSession, profileId: String? = null) {
        if (session.userId.isBlank() || session.accessToken.isBlank()) {
            Log.w(TAG, "Push: token upload skipped — missing session (user not signed in)")
            return
        }
        FcmTokenRefresher.refreshCachedToken(activity) {
            val token = FirebaseTokenProvider.tryGetCachedToken(activity)
            if (token == null) {
                if (BuildConfig.FIREBASE_CONFIGURED) {
                    Log.i(
                        TAG,
                        "Push: NO-OP — Firebase configured but no FCM token in prefs yet (Play services / project setup)"
                    )
                } else {
                    Log.i(
                        TAG,
                        "Push: NO-OP — no cached FCM token; add gitignored app/google-services.json to enable FCM fetch"
                    )
                }
                return@refreshCachedToken
            }
            Log.i(TAG, "Push: token upload attempted (platform=android, token prefix=${token.take(8)}…)")
            Thread {
                runCatching {
                    apiClient.registerDeviceToken(
                        userId = session.userId,
                        platform = "android",
                        deviceToken = token,
                        profileId = profileId?.ifBlank { null },
                        accessToken = session.accessToken
                    )
                    Log.i(TAG, "Push: token registered with backend (/api/notifications/device-token)")
                }.onFailure { e ->
                    Log.e(TAG, "Push: token upload failed — ${e.message}", e)
                }
            }.start()
        }
    }

    private object FirebaseTokenProvider {
        fun tryGetCachedToken(activity: Activity): String? {
            val prefs = activity.getSharedPreferences("hiair_push", Context.MODE_PRIVATE)
            val cached = prefs.getString("fcm_token", "") ?: ""
            return cached.ifBlank { null }
        }
    }

    companion object {
        const val REQUEST_POST_NOTIFICATIONS = 4107
        private const val TAG = "HiAirPush"
    }
}
