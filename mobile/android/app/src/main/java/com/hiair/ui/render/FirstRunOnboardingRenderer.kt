package com.hiair.ui.render

import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.OnboardingStore
import com.hiair.analytics.ProductAnalytics
import com.hiair.health.WearableHealthHost
import com.hiair.location.LocationBootstrapHost
import com.hiair.ui.design.HiAirComponents
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

        ctx.titleView.text = ctx.l("onboarding.title")
        ctx.bodyContainer.addView(
            HiAirComponents.brandHeader(
                activity,
                compact = true,
                showOrb = true,
                orbSizeDp = 56,
            ),
        )

        val card = HiAirComponents.cardContainer(activity)
        when (currentStep) {
            STEP_AUTH -> renderAuthStep(ctx, card)
            STEP_VALUE -> renderValueStep(ctx, card)
            STEP_LOCATION -> renderLocationStep(ctx, card)
            STEP_HEALTH -> renderHealthStep(ctx, card)
            STEP_DONE -> renderDoneStep(ctx, card)
        }
        ctx.bodyContainer.addView(card)

        ctx.bodyContainer.addView(V2Ui.spacer(activity, 12))
        ctx.bodyContainer.addView(
            navigationRow(ctx, isLoggedIn, onboardingStore, onComplete),
        )

        if (currentStep == STEP_VALUE && !isLoggedIn) {
            ProductAnalytics.track("onboarding_started")
        }
    }

    private fun renderAuthStep(ctx: RenderContext, card: LinearLayout) {
        val activity = ctx.activity
        card.addView(HiAirComponents.sectionTitle(activity, ctx.l("auth.title")))
        card.addView(V2Ui.styledSecondaryText(activity, ctx.l("onboarding.auth.body")))
        card.addView(V2Ui.spacer(activity, 8))
        val emailInput = HiAirComponents.inputField(activity, ctx.l("settings.email"))
        val passwordInput = HiAirComponents.inputField(activity, ctx.l("settings.password"))
        authEmailInput = emailInput
        authPasswordInput = passwordInput
        card.addView(emailInput)
        card.addView(passwordInput)
        card.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("settings.sign_up")).apply {
                setOnClickListener {
                    ctx.rootShell.settingsViewModel.setEmail(emailInput.text.toString())
                    ctx.rootShell.settingsViewModel.setPassword(passwordInput.text.toString())
                    Thread {
                        ctx.rootShell.settingsViewModel.signup {
                            activity.runOnUiThread {
                                ctx.persistSession()
                                if (ctx.rootShell.settingsViewModel.state.userId.isNotBlank()) {
                                    currentStep = STEP_VALUE
                                }
                                ctx.rerender()
                            }
                        }
                    }.start()
                }
            },
        )
        card.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("onboarding.auth.open_settings")).apply {
                setOnClickListener {
                    ctx.rootShell.openSettings()
                    ctx.rerender()
                }
            },
        )
    }

    private fun renderValueStep(ctx: RenderContext, card: LinearLayout) {
        val activity = ctx.activity
        card.addView(HiAirComponents.sectionTitle(activity, ctx.l("onboarding.step1.title")))
        card.addView(V2Ui.styledSecondaryText(activity, ctx.l("onboarding.step1.body")))
        card.addView(V2Ui.spacer(activity, 8))
        card.addView(bulletRow(ctx, ctx.l("onboarding.problem.heat")))
        card.addView(bulletRow(ctx, ctx.l("onboarding.problem.pm25")))
        card.addView(bulletRow(ctx, ctx.l("onboarding.problem.ozone")))
        card.addView(bulletRow(ctx, ctx.l("onboarding.problem.sensitive")))
    }

    private fun renderLocationStep(ctx: RenderContext, card: LinearLayout) {
        val activity = ctx.activity
        card.addView(HiAirComponents.sectionTitle(activity, ctx.l("onboarding.step5.title")))
        card.addView(V2Ui.styledBodyText(activity, ctx.l("onboarding.permissions.location.title")).apply {
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        card.addView(V2Ui.styledSecondaryText(activity, ctx.l("onboarding.permissions.location.body")))
    }

    private fun renderHealthStep(ctx: RenderContext, card: LinearLayout) {
        val activity = ctx.activity
        card.addView(HiAirComponents.sectionTitle(activity, ctx.l("wearable.consent.title")))
        card.addView(V2Ui.styledSecondaryText(activity, ctx.l("wearable.consent.body")))
        card.addView(V2Ui.styledSecondaryText(activity, ctx.l("wearable.consent.disclaimer")).apply {
            textSize = 12f
            setTextColor(Tokens.Text.tertiary)
        })
    }

    private fun renderDoneStep(ctx: RenderContext, card: LinearLayout) {
        val activity = ctx.activity
        card.addView(HiAirComponents.sectionTitle(activity, ctx.l("onboarding.step6.title")))
        card.addView(V2Ui.styledSecondaryText(activity, ctx.l("onboarding.step6.body")))
    }

    private fun bulletRow(ctx: RenderContext, text: String): TextView {
        return V2Ui.styledSecondaryText(ctx.activity, "• $text").apply {
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = V2Ui.dp(ctx.activity, 4) }
        }
    }

    private fun navigationRow(
        ctx: RenderContext,
        isLoggedIn: Boolean,
        onboardingStore: OnboardingStore,
        onComplete: () -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val row = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        if (currentStep > firstContentStep(isLoggedIn)) {
            row.addView(
                HiAirComponents.secondaryButton(activity, ctx.l("onboarding.back")).apply {
                    setOnClickListener {
                        currentStep = (currentStep - 1).coerceAtLeast(firstContentStep(isLoggedIn))
                        ctx.rerender()
                    }
                },
            )
        }

        when (currentStep) {
            STEP_AUTH -> Unit
            STEP_LOCATION -> {
                row.addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("onboarding.permissions.later")).apply {
                        setOnClickListener {
                            currentStep = STEP_HEALTH
                            ctx.rerender()
                        }
                    },
                )
            }
            STEP_HEALTH -> {
                row.addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("wearable.consent.skip")).apply {
                        setOnClickListener {
                            currentStep = STEP_DONE
                            ctx.rerender()
                        }
                    },
                )
            }
        }

        row.addView(
            HiAirComponents.primaryButton(activity, primaryButtonTitle(ctx)).apply {
                isEnabled = !authSubmitting
                setOnClickListener {
                    if (authSubmitting) return@setOnClickListener
                    handlePrimaryAction(ctx, isLoggedIn, onboardingStore, onComplete)
                }
            },
        )
        return row
    }

    private fun primaryButtonTitle(ctx: RenderContext): String {
        return when (currentStep) {
            STEP_AUTH -> ctx.l("settings.log_in")
            STEP_VALUE -> ctx.l("onboarding.next")
            STEP_LOCATION -> ctx.l("onboarding.permissions.allow")
            STEP_HEALTH -> ctx.l("wearable.consent.connect")
            STEP_DONE -> ctx.l("onboarding.open_forecast")
            else -> ctx.l("onboarding.next")
        }
    }

    private fun handlePrimaryAction(
        ctx: RenderContext,
        isLoggedIn: Boolean,
        onboardingStore: OnboardingStore,
        onComplete: () -> Unit,
    ) {
        when (currentStep) {
            STEP_AUTH -> submitAuthLogin(ctx)
            STEP_VALUE -> {
                currentStep = STEP_LOCATION
                ctx.rerender()
            }
            STEP_LOCATION -> {
                val host = ctx.activity as? LocationBootstrapHost
                host?.bootstrapLocation {
                    ctx.activity.runOnUiThread {
                        currentStep = STEP_HEALTH
                        ctx.rerender()
                    }
                } ?: run {
                    currentStep = STEP_HEALTH
                    ctx.rerender()
                }
            }
            STEP_HEALTH -> {
                val host = ctx.activity as? WearableHealthHost
                if (host != null && isLoggedIn) {
                    host.requestWearableConnect {
                        ctx.activity.runOnUiThread {
                            host.syncWearablesIfPermitted()
                            currentStep = STEP_DONE
                            ctx.rerender()
                        }
                    }
                } else {
                    currentStep = STEP_DONE
                    ctx.rerender()
                }
            }
            STEP_DONE -> {
                onboardingStore.setCompleted(true)
                ProductAnalytics.track("onboarding_completed")
                ctx.rootShell.openDashboard()
                onComplete()
                ctx.rerender()
            }
        }
    }

    private fun firstContentStep(isLoggedIn: Boolean): Int {
        return if (isLoggedIn) STEP_VALUE else STEP_AUTH
    }

    private fun submitAuthLogin(ctx: RenderContext) {
        val activity = ctx.activity
        val email = authEmailInput?.text?.toString()?.trim().orEmpty()
        val password = authPasswordInput?.text?.toString().orEmpty()
        if (email.isBlank() || password.isBlank()) {
            return
        }
        if (authSubmitting) return
        authSubmitting = true
        ctx.rerender()
        ctx.rootShell.settingsViewModel.setEmail(email)
        ctx.rootShell.settingsViewModel.setPassword(password)
        Thread {
            ctx.rootShell.settingsViewModel.login {
                activity.runOnUiThread {
                    authSubmitting = false
                    ctx.persistSession()
                    if (ctx.rootShell.settingsViewModel.state.userId.isNotBlank()) {
                        currentStep = STEP_VALUE
                    }
                    ctx.rerender()
                }
            }
        }.start()
    }
}
