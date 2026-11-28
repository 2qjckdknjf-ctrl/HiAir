package com.hiair.ui.settings

import com.hiair.network.ApiClient
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.mockito.ArgumentMatchers.*
import org.mockito.Mockito.*

class SettingsProfileOwnershipTest {
    private fun signIn(model: SettingsViewModel, user: String) {
        model.setUserId(user)
        model.setAccessToken("token-$user")
    }

    @Test
    fun lateProfileListCannotHydrateTheNextAccountsLocationOrProfile() {
        val api = mock(ApiClient::class.java)
        val model = SettingsViewModel(api)
        signIn(model, "a")
        `when`(api.listProfiles(eq("a"), anyString())).thenAnswer {
            signIn(model, "b")
            model.setProfileId("profile-b")
            """[{"id":"profile-a","home_lat":41.39,"home_lon":2.17}]"""
        }
        assertNull(model.ensureProfile(expectedUserId = "a", expectedAccessToken = "token-a"))
        assertEquals("profile-b", model.state.profileId)
        assertEquals(0.0, model.state.latitude, 0.0)
        assertEquals(0, model.state.locationRevision)
    }

    @Test
    fun switchedAccountDoesNotCreateAProfileAfterAnEmptyOldList() {
        val api = mock(ApiClient::class.java)
        val model = SettingsViewModel(api)
        signIn(model, "a")
        model.hydrateProfileLocation(JSONObject("""{"home_lat":41.39,"home_lon":2.17}"""))
        `when`(api.listProfiles(eq("a"), anyString())).thenAnswer {
            signIn(model, "b")
            "[]"
        }
        assertNull(model.ensureProfile())
        verify(api, never()).createProfile(anyString(), anyString(), anyString(), anyString(), anyDouble(), anyDouble())
    }

    @Test
    fun lateCreatedProfileCannotOverwriteTheNextAccountsProfile() {
        val api = mock(ApiClient::class.java)
        val model = SettingsViewModel(api)
        signIn(model, "a")
        model.hydrateProfileLocation(JSONObject("""{"home_lat":41.39,"home_lon":2.17}"""))
        `when`(api.listProfiles(eq("a"), anyString())).thenReturn("[]")
        `when`(api.createProfile(eq("a"), anyString(), anyString(), anyString(), anyDouble(), anyDouble())).thenAnswer {
            signIn(model, "b")
            model.setProfileId("profile-b")
            """{"id":"profile-a"}"""
        }
        val revision = model.state.locationRevision
        assertNull(model.ensureProfile())
        assertEquals("profile-b", model.state.profileId)
        assertEquals(revision, model.state.locationRevision)
    }

    @Test
    fun switchingAccountsClearsACarriedProfileBeforeTheNextLookup() {
        val api = mock(ApiClient::class.java)
        val model = SettingsViewModel(api)
        signIn(model, "a")
        model.setProfileId("profile-a")
        signIn(model, "b")
        assertEquals("", model.state.profileId)
        `when`(api.listProfiles(eq("b"), anyString())).thenReturn("""[{"id":"profile-b"}]""")
        assertEquals("profile-b", model.ensureProfile())
        assertEquals("profile-b", model.state.profileId)
    }

    @Test
    fun callerCapturedBeforeLookupCannotRequestAnotherAccountsProfile() {
        val api = mock(ApiClient::class.java)
        val model = SettingsViewModel(api)
        signIn(model, "b")
        assertNull(model.ensureProfile(expectedUserId = "a", expectedAccessToken = "token-a"))
        verifyNoInteractions(api)
    }

    @Test
    fun missingAuthCannotReuseAPreviouslyCachedProfile() {
        val model = SettingsViewModel(mock(ApiClient::class.java))
        signIn(model, "a")
        model.setProfileId("profile-a")
        model.setAccessToken("")
        assertNull(model.ensureProfile())
    }
}
