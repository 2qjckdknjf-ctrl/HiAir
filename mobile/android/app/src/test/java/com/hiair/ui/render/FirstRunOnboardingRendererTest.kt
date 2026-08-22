package com.hiair.ui.render

import org.junit.Assert.assertEquals
import org.junit.Test

class FirstRunOnboardingRendererTest {
    @Test
    fun resetStepForSession_startsAtAuthWhenLoggedOut() {
        FirstRunOnboardingRenderer.resetStepForSession(isLoggedIn = false)
        assertEquals(0, FirstRunOnboardingRenderer.currentStep)
    }

    @Test
    fun resetStepForSession_skipsAuthWhenLoggedIn() {
        FirstRunOnboardingRenderer.resetStepForSession(isLoggedIn = true)
        assertEquals(1, FirstRunOnboardingRenderer.currentStep)
    }
}
