package com.hiair

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

data class StoredSession(
    val email: String,
    val userId: String,
    val accessToken: String,
    val refreshToken: String
)

class SessionStore(context: Context) {
    private val prefs: SharedPreferences = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "hiair_session_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    } catch (_: Exception) {
        context.getSharedPreferences("hiair_session", Context.MODE_PRIVATE)
    }

    fun load(): StoredSession {
        return StoredSession(
            email = prefs.getString("email", "") ?: "",
            userId = prefs.getString("user_id", "") ?: "",
            accessToken = prefs.getString("access_token", "") ?: "",
            refreshToken = prefs.getString("refresh_token", "") ?: "",
        )
    }

    fun save(session: StoredSession) {
        prefs.edit()
            .putString("email", session.email)
            .putString("user_id", session.userId)
            .putString("access_token", session.accessToken)
            .putString("refresh_token", session.refreshToken)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
