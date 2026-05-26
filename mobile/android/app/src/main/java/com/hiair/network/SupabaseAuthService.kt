package com.hiair.network

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import com.hiair.SessionStore
import com.hiair.StoredSession
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

data class SupabaseSession(
    val userId: String,
    val email: String,
    val accessToken: String,
    val refreshToken: String
)

class SupabaseAuthService(
    private val context: Context,
    private val sessionStore: SessionStore
) {
    fun restoreSession(): SupabaseSession? {
        val stored = sessionStore.load()
        if (stored.userId.isBlank() || stored.accessToken.isBlank() || stored.refreshToken.isBlank()) {
            return null
        }
        return SupabaseSession(
            userId = stored.userId,
            email = stored.email,
            accessToken = stored.accessToken,
            refreshToken = stored.refreshToken
        )
    }

    fun signUp(email: String, password: String): SupabaseSession {
        val endpoint = "${AppConfig.supabaseUrl}/auth/v1/signup"
        val body = JSONObject()
            .put("email", email)
            .put("password", password)
            .toString()
        val payload = request("POST", endpoint, body)
        return extractSession(payload, fallbackEmail = email).also(::persist)
    }

    fun signIn(email: String, password: String): SupabaseSession {
        val endpoint = "${AppConfig.supabaseUrl}/auth/v1/token?grant_type=password"
        val body = JSONObject()
            .put("email", email)
            .put("password", password)
            .toString()
        val payload = request("POST", endpoint, body)
        return extractSession(payload, fallbackEmail = email).also(::persist)
    }

    fun refresh(refreshToken: String): SupabaseSession {
        val endpoint = "${AppConfig.supabaseUrl}/auth/v1/token?grant_type=refresh_token"
        val body = JSONObject()
            .put("refresh_token", refreshToken)
            .toString()
        val payload = request("POST", endpoint, body)
        val session = extractSession(payload, fallbackEmail = "")
        persist(session)
        return session
    }

    fun signOut() {
        val endpoint = "${AppConfig.supabaseUrl}/auth/v1/logout"
        val stored = sessionStore.load()
        if (stored.accessToken.isNotBlank()) {
            request(
                "POST",
                endpoint,
                "{}",
                extraHeaders = mapOf("Authorization" to "Bearer ${stored.accessToken}")
            )
        }
        sessionStore.clear()
    }

    fun launchGoogleSignIn() {
        launchOAuth("google")
    }

    fun launchAppleSignIn() {
        launchOAuth("apple")
    }

    fun consumeOAuthCallback(intent: Intent?): SupabaseSession? {
        val data = intent?.data ?: return null
        if (data.scheme != "hiair" || data.host != "auth") {
            return null
        }
        val raw = data.toString()
        val fragment = raw.substringAfter("#", "")
        if (fragment.isBlank()) {
            return null
        }
        val params = fragment
            .split("&")
            .mapNotNull { pair ->
                val idx = pair.indexOf("=")
                if (idx <= 0) return@mapNotNull null
                val key = pair.substring(0, idx)
                val value = Uri.decode(pair.substring(idx + 1))
                key to value
            }
            .toMap()
        val accessToken = params["access_token"] ?: return null
        val refreshToken = params["refresh_token"] ?: return null
        val userId = params["user_id"] ?: params["sub"] ?: return null
        val email = params["email"] ?: ""
        val session = SupabaseSession(
            userId = userId,
            email = email,
            accessToken = accessToken,
            refreshToken = refreshToken
        )
        persist(session)
        return session
    }

    private fun launchOAuth(provider: String) {
        val redirect = Uri.encode(AppConfig.supabaseRedirectUri)
        val target = Uri.parse("${AppConfig.supabaseUrl}/auth/v1/authorize?provider=$provider&redirect_to=$redirect")
        val customTabsIntent = CustomTabsIntent.Builder().build()
        customTabsIntent.launchUrl(context, target)
    }

    private fun persist(session: SupabaseSession) {
        sessionStore.save(
            StoredSession(
                email = session.email,
                userId = session.userId,
                accessToken = session.accessToken,
                refreshToken = session.refreshToken
            )
        )
    }

    private fun request(
        method: String,
        endpoint: String,
        body: String?,
        extraHeaders: Map<String, String> = emptyMap()
    ): JSONObject {
        val connection = URL(endpoint).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        connection.setRequestProperty("apikey", AppConfig.supabaseAnonKey)
        connection.setRequestProperty("Content-Type", "application/json")
        extraHeaders.forEach { (name, value) -> connection.setRequestProperty(name, value) }
        if (body != null) {
            connection.doOutput = true
            connection.outputStream.use { output -> output.write(body.toByteArray()) }
        }
        val status = connection.responseCode
        val payload = try {
            (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.readText()
                .orEmpty()
        } finally {
            connection.disconnect()
        }
        if (status !in 200..299) {
            throw ApiHttpException(status, "Supabase auth request failed: $status")
        }
        return JSONObject(payload)
    }

    private fun extractSession(payload: JSONObject, fallbackEmail: String): SupabaseSession {
        val user = payload.optJSONObject("user")
        val userId = payload.optString("user_id", user?.optString("id")).orEmpty()
        val email = user?.optString("email", fallbackEmail).orEmpty().ifBlank { fallbackEmail }
        val accessToken = payload.optString("access_token", "")
        val refreshToken = payload.optString("refresh_token", "")
        if (userId.isBlank() || accessToken.isBlank() || refreshToken.isBlank()) {
            throw ApiHttpException(500, "Supabase auth response missing required session fields")
        }
        return SupabaseSession(
            userId = userId,
            email = email,
            accessToken = accessToken,
            refreshToken = refreshToken
        )
    }
}
