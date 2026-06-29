package com.hiair

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

class StoredSessionTest {
    @Test
    fun `stored session keeps all auth fields`() {
        val session = StoredSession(
            email = "user@example.com",
            userId = "user-1",
            accessToken = "access-token",
            refreshToken = "refresh-token",
            profileId = "profile-1"
        )

        assertEquals("user@example.com", session.email)
        assertEquals("user-1", session.userId)
        assertEquals("access-token", session.accessToken)
        assertEquals("refresh-token", session.refreshToken)
        assertEquals("profile-1", session.profileId)
    }

    @Test
    fun `session store saves loads and clears`() {
        val prefs = mock(SharedPreferences::class.java)
        val editor = mock(SharedPreferences.Editor::class.java)
        `when`(prefs.edit()).thenReturn(editor)
        `when`(editor.putString("email", "person@example.com")).thenReturn(editor)
        `when`(editor.putString("user_id", "user-123")).thenReturn(editor)
        `when`(editor.putString("access_token", "access-123")).thenReturn(editor)
        `when`(editor.putString("refresh_token", "refresh-123")).thenReturn(editor)
        `when`(editor.putString("profile_id", "profile-123")).thenReturn(editor)
        `when`(editor.clear()).thenReturn(editor)
        `when`(prefs.getString("email", "")).thenReturn("person@example.com")
        `when`(prefs.getString("user_id", "")).thenReturn("user-123")
        `when`(prefs.getString("access_token", "")).thenReturn("access-123")
        `when`(prefs.getString("refresh_token", "")).thenReturn("refresh-123")
        `when`(prefs.getString("profile_id", "")).thenReturn("profile-123")

        val store = SessionStore(prefs)
        val initial = StoredSession(
            email = "person@example.com",
            userId = "user-123",
            accessToken = "access-123",
            refreshToken = "refresh-123",
            profileId = "profile-123"
        )

        store.save(initial)
        val loaded = store.load()
        assertEquals(initial.email, loaded.email)
        assertEquals(initial.userId, loaded.userId)
        assertEquals(initial.accessToken, loaded.accessToken)
        assertEquals(initial.refreshToken, loaded.refreshToken)
        assertEquals(initial.profileId, loaded.profileId)
        verify(editor, times(1)).apply()

        store.clear()
        verify(editor).clear()
        verify(editor, times(2)).apply()
    }
}
