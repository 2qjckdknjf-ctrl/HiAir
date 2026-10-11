package com.hiair.ui.render

import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.OnboardingStore
import com.hiair.StoreScreenshotMode
import com.hiair.analytics.ProductAnalytics
import com.hiair.health.WearableHealthHost
import com.hiair.location.LocationBootstrapHost
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirScreenMetrics
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui

internal object FirstRunOnboardingRenderer {
    private const val STEP_AUTH = 0
    private const val STEP_VALUE = 1
    private const val STEP_LOCATION = 2
    private const val STEP_HEALTH = 3
    private const val STEP_DONE = 4

    var currentStep: Int = STEP_VALUE
        private set

    private var authEmailInput: android.widget.EditText? = null
    private var authPasswordInput: android.widget.EditText? = null
    private var authSubmitting: Boolean = false

    fun primaryAuthButtonCountForStep(step: Int): Int {
        return if (step == STEP_AUTH) 1 else 0
    }

    fun resetStepForSession(isLoggedIn: Boolean) {
        currentStep = if (isLoggedIn) STEP_VALUE else STEP_AUTH
    }

    fun prepareStoreScreenshotWelcome() {
        currentStep = STEP_VALUE
    }

    fun render(
        ctx: RenderContext,
        onboardingStore: OnboardingStore,
        onComplete: () -> Unit,
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val settings = rootShell.settingsViewModel.state
        val isLoggedIn = settings.userId.isNotBlank() && settings.accessToken.isNotBlank()

        if (currentStep == STEP_AUTH && isLoggedIn) {
            currentStep = STEP_VALUE
        }
        if (currentStep > STEP_AUTH && !isLoggedIn) {
            currentStep = STEP_AUTH
        }

