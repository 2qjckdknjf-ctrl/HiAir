package com.hiair

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

data class StoredSession(
    val email: String,
    val userId: String,
    val accessToken: String,
    val refreshToken: String,
    val profileId: String
)

class SessionStore(private val prefs: SharedPreferences) {
    constructor(context: Context) : this(
        try {
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
    )

    fun load(): StoredSession {
        return StoredSession(
            email = prefs.getString("email", "") ?: "",
            userId = prefs.getString("user_id", "") ?: "",
            accessToken = prefs.getString("access_token", "") ?: "",
            refreshToken = prefs.getString("refresh_token", "") ?: "",
            profileId = prefs.getString("profile_id", "") ?: "",
        )
    }

    /** Monotonic account generation — increments on login identity change and logout. */
    fun accountGeneration(): Long = prefs.getLong(KEY_ACCOUNT_GENERATION, 0L)

    fun bumpAccountGeneration(): Long {
        val next = accountGeneration() + 1L
        prefs.edit().putLong(KEY_ACCOUNT_GENERATION, next).commit()
        return next
    }

    fun save(session: StoredSession) {
        val previous = load()
        val editor = prefs.edit()
            .putString("email", session.email)
            .putString("user_id", session.userId)
            .putString("access_token", session.accessToken)
            .putString("refresh_token", session.refreshToken)
            .putString("profile_id", session.profileId)
        if (previous.userId.isNotBlank() && previous.userId != session.userId) {
            editor.putLong(KEY_ACCOUNT_GENERATION, accountGeneration() + 1L)
        }
        editor.apply()
    }

    fun clear() {
        val nextGeneration = accountGeneration() + 1L
        prefs.edit()
            .clear()
            .putLong(KEY_ACCOUNT_GENERATION, nextGeneration)
            .commit()
    }

    companion object {
        private const val KEY_ACCOUNT_GENERATION = "account_generation"
    }
}
