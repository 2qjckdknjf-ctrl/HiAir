package com.hiair

import org.junit.Assert.assertEquals
import org.junit.Test

class StoredSessionTest {
    @Test
    fun `stored session keeps all auth fields`() {
        val session = StoredSession(
            email = "user@example.com",
            userId = "user-1",
            accessToken = "access-token",
            refreshToken = "refresh-token"
        )

        assertEquals("user@example.com", session.email)
        assertEquals("user-1", session.userId)
        assertEquals("access-token", session.accessToken)
        assertEquals("refresh-token", session.refreshToken)
    }
}
