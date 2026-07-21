package com.hiair

import android.content.Context

class SymptomFavoritesStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun load(): List<String> {
        return prefs.getStringSet(KEY_FAVORITES, null)?.toList().orEmpty()
    }

    fun save(favorites: List<String>) {
        prefs.edit().putStringSet(KEY_FAVORITES, favorites.toSet()).apply()
    }

    companion object {
        private const val PREFS_NAME = "hiair"
        private const val KEY_FAVORITES = "symptoms.favorites.v1"
    }
}
