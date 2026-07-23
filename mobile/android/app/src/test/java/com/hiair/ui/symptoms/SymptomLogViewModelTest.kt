package com.hiair.ui.symptoms

import org.junit.Assert.assertEquals
import org.junit.Test

class SymptomLogViewModelTest {
    @Test
    fun keepsIntentionalEmptyFavoritesAfterPersistence() {
        val viewModel = SymptomLogViewModel()
        setPrivateBoolean(viewModel, "persistedFavoritesLoaded", true)
        setPrivateBoolean(viewModel, "hasPersistedFavorites", true)

        val favorites = resolvedFavorites(viewModel, setOf("cough", "fatigue"))

        assertEquals(emptyList<String>(), favorites)
    }

    @Test
    fun fallsBackToDefaultsWhenFavoritesWereNeverSaved() {
        val viewModel = SymptomLogViewModel()
        setPrivateBoolean(viewModel, "persistedFavoritesLoaded", true)
        setPrivateBoolean(viewModel, "hasPersistedFavorites", false)

        val favorites = resolvedFavorites(viewModel, setOf("cough", "fatigue", "shortness_of_breath"))

        assertEquals(listOf("cough", "fatigue", "shortness_of_breath"), favorites)
    }

    private fun setPrivateBoolean(viewModel: SymptomLogViewModel, fieldName: String, value: Boolean) {
        val field = SymptomLogViewModel::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        field.setBoolean(viewModel, value)
    }

    @Suppress("UNCHECKED_CAST")
    private fun resolvedFavorites(viewModel: SymptomLogViewModel, available: Set<String>): List<String> {
        val method = SymptomLogViewModel::class.java.getDeclaredMethod("resolvedFavorites", Set::class.java)
        method.isAccessible = true
        return method.invoke(viewModel, available) as List<String>
    }
}
