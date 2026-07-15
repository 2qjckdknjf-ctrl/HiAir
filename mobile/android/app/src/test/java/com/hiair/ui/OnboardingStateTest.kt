package com.hiair.ui

import com.hiair.ui.navigation.AppPhase
import com.hiair.ui.navigation.OnboardingStep
import org.junit.Assert.assertEquals
import org.junit.Test

class OnboardingStateTest {
    @Test
    fun defaultRootShellStartsOnboardingWhenNotCompleted() {
        val rootShell = com.hiair.ui.navigation.RootShellViewModel()
        rootShell.startOnboarding()
        assertEquals(AppPhase.ONBOARDING, rootShell.state.phase)
        assertEquals(OnboardingStep.WELCOME, rootShell.state.onboardingStep)
    }

    @Test
    fun completingOnboardingOpensMainTabs() {
        val rootShell = com.hiair.ui.navigation.RootShellViewModel()
        rootShell.startOnboarding()
        rootShell.completeOnboarding()
        assertEquals(AppPhase.MAIN, rootShell.state.phase)
    }
}
