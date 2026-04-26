package com.hiair

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class StoredSession(
    val email: String,
    val userId: String,
    val accessToken: String,
    val profileId: String = "",
    val preferredLanguage: String = "ru"
)

class SessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("hiair_session", Context.MODE_PRIVATE)
    private val securePrefs = context.getSharedPreferences("hiair_secure_session", Context.MODE_PRIVATE)

    fun load(): StoredSession {
        val legacyToken = prefs.getString("access_token", "") ?: ""
        if (legacyToken.isNotBlank() && securePrefs.getString("access_token", "").isNullOrBlank()) {
            saveAccessToken(legacyToken)
            prefs.edit().remove("access_token").apply()
        }
        return StoredSession(
            email = prefs.getString("email", "") ?: "",
            userId = prefs.getString("user_id", "") ?: "",
            accessToken = readAccessToken(),
            profileId = prefs.getString("profile_id", "") ?: "",
            preferredLanguage = prefs.getString("preferred_language", "ru") ?: "ru",
        )
    }

    fun save(session: StoredSession) {
        prefs.edit()
            .putString("email", session.email)
            .putString("user_id", session.userId)
            .putString("profile_id", session.profileId)
            .putString("preferred_language", session.preferredLanguage)
            .remove("access_token")
            .apply()
        saveAccessToken(session.accessToken)
    }

    fun clear() {
        prefs.edit().clear().apply()
        securePrefs.edit().clear().apply()
    }

    private fun readAccessToken(): String {
        val encrypted = securePrefs.getString("access_token", "") ?: ""
        if (encrypted.isBlank()) return ""
        return runCatching { decrypt(encrypted) }.getOrDefault("")
    }

    private fun saveAccessToken(token: String) {
        if (token.isBlank()) {
            securePrefs.edit().remove("access_token").apply()
            return
        }
        val encrypted = runCatching { encrypt(token) }.getOrNull() ?: return
        securePrefs.edit().putString("access_token", encrypted).apply()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = ByteBuffer.allocate(cipher.iv.size + encrypted.size)
            .put(cipher.iv)
            .put(encrypted)
            .array()
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val payload = Base64.decode(value, Base64.NO_WRAP)
        val buffer = ByteBuffer.wrap(payload)
        val iv = ByteArray(GCM_IV_BYTES)
        buffer.get(iv)
        val encrypted = ByteArray(buffer.remaining())
        buffer.get(encrypted)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun getSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.secretKey?.let {
            return it
        }
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val keySpec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(keySpec)
        return keyGenerator.generateKey()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "hiair_session_token_key"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_IV_BYTES = 12
        const val GCM_TAG_BITS = 128
    }
}
