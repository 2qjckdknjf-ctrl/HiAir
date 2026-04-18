package com.hiair

import android.content.Context

data class StoredSession(
    val email: String,
    val userId: String,
    val accessToken: String
)

class SessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("hiair_session", Context.MODE_PRIVATE)

    fun load(): StoredSession {
        return StoredSession(
            email = prefs.getString("email", "") ?: "",
            userId = prefs.getString("user_id", "") ?: "",
            accessToken = prefs.getString("access_token", "") ?: "",
        )
    }

    fun save(session: StoredSession) {
        prefs.edit()
            .putString("email", session.email)
            .putString("user_id", session.userId)
            .putString("access_token", session.accessToken)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
