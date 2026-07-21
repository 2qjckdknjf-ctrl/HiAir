package com.hiair

import android.content.Context

class OnboardingStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isCompleted(): Boolean = prefs.getBoolean(KEY_COMPLETED, false)

    fun setCompleted(completed: Boolean) {
        prefs.edit().putBoolean(KEY_COMPLETED, completed).apply()
    }

    companion object {
        private const val PREFS_NAME = "hiair"
        const val KEY_COMPLETED = "onboarding_completed"
    }
}
