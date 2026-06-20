package com.hiair.ui.render

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.widget.ArrayAdapter
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.hiair.StoredSession
import com.hiair.ui.navigation.OnboardingStep
import com.hiair.ui.theme.V2Ui

internal object OnboardingScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer
        val session = ctx.session
        val step = rootShell.state.onboardingStep

        titleView.text = ctx.l("onboarding.title")
        bodyContainer.addView(
            V2Ui.styledSecondaryText(activity, stepLabel(ctx, step)).apply { textSize = 13f }
        )

        when (step) {
            OnboardingStep.WELCOME -> renderWelcome(ctx)
            OnboardingStep.VALUE -> renderValue(ctx)
            OnboardingStep.PERSONA -> renderPersona(ctx)
            OnboardingStep.LOCATION -> renderLocation(ctx)
            OnboardingStep.NOTIFICATIONS -> renderNotifications(ctx)
            OnboardingStep.HEALTH -> renderHealth(ctx)
            OnboardingStep.FIRST_RESULT -> renderFirstResult(ctx)
        }
    }

    private fun renderWelcome(ctx: RenderContext) {
        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.welcome_headline")).apply { textSize = 22f })
            addView(V2Ui.spacer(ctx.activity, 8))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.welcome_body")))
        }
        ctx.bodyContainer.addView(card)
        ctx.bodyContainer.addView(primaryNext(ctx, OnboardingStep.VALUE))
        ctx.bodyContainer.addView(guestEntry(ctx))
    }

    private fun renderValue(ctx: RenderContext) {
        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.value_headline")).apply { textSize = 20f })
            addView(V2Ui.spacer(ctx.activity, 8))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.value_body")))
        }
        ctx.bodyContainer.addView(card)
        ctx.bodyContainer.addView(primaryNext(ctx, OnboardingStep.PERSONA))
    }

    private fun renderPersona(ctx: RenderContext) {
        val personaSpinner = Spinner(ctx.activity)
        val personaOptions = listOf("adult", "child", "elderly", "asthma", "allergy", "runner")
        val personaLabels = personaOptions.map { ctx.l("settings.persona_$it") }
        personaSpinner.adapter = ArrayAdapter(ctx.activity, android.R.layout.simple_spinner_dropdown_item, personaLabels)
        val selectedIndex = personaOptions.indexOf(ctx.session.persona).coerceAtLeast(0)
        personaSpinner.setSelection(selectedIndex)

        val sensitivitySpinner = Spinner(ctx.activity)
        val sensitivityOptions = listOf("low", "medium", "high")
        val sensitivityLabels = listOf(
            if (ctx.rootShell.settingsViewModel.state.preferredLanguage == "en") "Low" else "Низкая",
            if (ctx.rootShell.settingsViewModel.state.preferredLanguage == "en") "Medium" else "Средняя",
            if (ctx.rootShell.settingsViewModel.state.preferredLanguage == "en") "High" else "Высокая"
        )
        sensitivitySpinner.adapter =
            ArrayAdapter(ctx.activity, android.R.layout.simple_spinner_dropdown_item, sensitivityLabels)
        sensitivitySpinner.setSelection(sensitivityOptions.indexOf(ctx.session.sensitivityLevel).coerceAtLeast(1))

        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.persona_headline")))
            addView(V2Ui.spacer(ctx.activity, 6))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.persona_body")))
            addView(V2Ui.spacer(ctx.activity, 8))
            addView(personaSpinner)
            addView(V2Ui.spacer(ctx.activity, 6))
            addView(sensitivitySpinner)
        }
        ctx.bodyContainer.addView(card)

        val next = V2Ui.primaryButton(ctx.activity, ctx.l("onboarding.continue")).apply {
            setOnClickListener {
                ctx.updateSession(
                    ctx.session.copy(
                        persona = personaOptions[personaSpinner.selectedItemPosition],
                        sensitivityLevel = sensitivityOptions[sensitivitySpinner.selectedItemPosition]
                    )
                )
                ctx.rootShell.setOnboardingStep(OnboardingStep.LOCATION)
                ctx.rerender()
            }
        }
        ctx.bodyContainer.addView(next)
    }

    private fun renderLocation(ctx: RenderContext) {
        val latInput = EditText(ctx.activity).apply {
            hint = ctx.l("onboarding.latitude")
            setText(ctx.session.homeLat.toString())
        }
        val lonInput = EditText(ctx.activity).apply {
            hint = ctx.l("onboarding.longitude")
            setText(ctx.session.homeLon.toString())
        }
        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.location_headline")))
            addView(V2Ui.spacer(ctx.activity, 6))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.location_body")))
            addView(V2Ui.spacer(ctx.activity, 8))
            addView(latInput)
            addView(lonInput)
        }
        ctx.bodyContainer.addView(card)

        val grant = V2Ui.secondaryButton(ctx.activity, ctx.l("onboarding.grant_location")).apply {
            setOnClickListener {
                ActivityCompat.requestPermissions(
                    ctx.activity,
                    arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
                    1001
                )
                val granted = ContextCompat.checkSelfPermission(
                    ctx.activity,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                ctx.updateSession(ctx.session.copy(locationGranted = granted))
            }
        }
        ctx.bodyContainer.addView(grant)

        val next = V2Ui.primaryButton(ctx.activity, ctx.l("onboarding.continue")).apply {
            setOnClickListener {
                val lat = latInput.text.toString().toDoubleOrNull() ?: 41.39
                val lon = lonInput.text.toString().toDoubleOrNull() ?: 2.17
                ctx.updateSession(ctx.session.copy(homeLat = lat, homeLon = lon))
                ctx.rootShell.setOnboardingStep(OnboardingStep.NOTIFICATIONS)
                ctx.rerender()
            }
        }
        ctx.bodyContainer.addView(next)
    }

    private fun renderNotifications(ctx: RenderContext) {
        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.notifications_headline")))
            addView(V2Ui.spacer(ctx.activity, 6))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.notifications_body")))
        }
        ctx.bodyContainer.addView(card)
        ctx.bodyContainer.addView(V2Ui.secondaryButton(ctx.activity, ctx.l("onboarding.skip")).apply {
            setOnClickListener {
                ctx.updateSession(ctx.session.copy(notificationsGranted = false))
                ctx.rootShell.setOnboardingStep(OnboardingStep.HEALTH)
                ctx.rerender()
            }
        })
        ctx.bodyContainer.addView(primaryNext(ctx, OnboardingStep.HEALTH))
    }

    private fun renderHealth(ctx: RenderContext) {
        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.health_headline")))
            addView(V2Ui.spacer(ctx.activity, 6))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.health_body")))
            addView(V2Ui.spacer(ctx.activity, 6))
            addView(V2Ui.styledSecondaryText(ctx.activity, ctx.l("onboarding.health_optional")))
        }
        ctx.bodyContainer.addView(card)
        ctx.bodyContainer.addView(V2Ui.secondaryButton(ctx.activity, ctx.l("onboarding.skip")).apply {
            setOnClickListener {
                ctx.updateSession(ctx.session.copy(healthOptIn = false))
                ctx.rootShell.setOnboardingStep(OnboardingStep.FIRST_RESULT)
                ctx.rerender()
            }
        })
        ctx.bodyContainer.addView(V2Ui.primaryButton(ctx.activity, ctx.l("onboarding.enable_health")).apply {
            setOnClickListener {
                ctx.updateSession(ctx.session.copy(healthOptIn = true))
                ctx.rootShell.setOnboardingStep(OnboardingStep.FIRST_RESULT)
                ctx.rerender()
            }
        })
    }

    private fun renderFirstResult(ctx: RenderContext) {
        val resultText = TextView(ctx.activity).apply {
            text = ctx.l("common.loading")
            setTextColor(Color.parseColor("#A6B6D2"))
        }
        val card = V2Ui.cardContainer(ctx.activity).apply {
            addView(V2Ui.styledBodyText(ctx.activity, ctx.l("onboarding.first_result_headline")))
            addView(V2Ui.spacer(ctx.activity, 8))
            addView(resultText)
        }
        ctx.bodyContainer.addView(card)

        Thread {
            val settings = ctx.rootShell.settingsViewModel.state
            ctx.rootShell.dashboardViewModel.refresh(
                userId = ctx.session.userId,
                accessToken = ctx.session.accessToken.ifBlank { null },
                profileId = ctx.session.profileId.ifBlank { null },
                persona = ctx.session.persona,
                lat = ctx.session.homeLat,
                lon = ctx.session.homeLon,
                language = settings.preferredLanguage,
                isGuest = ctx.session.isGuest
            )
            val state = ctx.rootShell.dashboardViewModel.state
            ctx.activity.runOnUiThread {
                resultText.text = when (state.loadState) {
                    com.hiair.ui.DashboardLoadState.SUCCESS ->
                        "${state.morningBriefing}\n\n${ctx.l("dashboard.current_risk_title")}: ${state.riskScore ?: "—"} (${state.riskLevel})"
                    com.hiair.ui.DashboardLoadState.ERROR -> state.errorMessage
                    else -> ctx.l("dashboard.no_data")
                }
            }
        }.start()

        ctx.bodyContainer.addView(V2Ui.primaryButton(ctx.activity, ctx.l("onboarding.finish")).apply {
            setOnClickListener {
                ctx.updateSession(ctx.session.copy(onboardingCompleted = true))
                ctx.rootShell.completeOnboarding()
                ctx.rerender()
            }
        })
    }

    private fun primaryNext(ctx: RenderContext, step: OnboardingStep) =
        V2Ui.primaryButton(ctx.activity, ctx.l("onboarding.continue")).apply {
            setOnClickListener {
                ctx.rootShell.setOnboardingStep(step)
                ctx.rerender()
            }
        }

    private fun guestEntry(ctx: RenderContext) =
        V2Ui.secondaryButton(ctx.activity, ctx.l("onboarding.continue_guest")).apply {
            setOnClickListener {
                ctx.updateSession(ctx.session.copy(isGuest = true))
                ctx.rootShell.setOnboardingStep(OnboardingStep.VALUE)
                ctx.rerender()
            }
        }

    private fun stepLabel(ctx: RenderContext, step: OnboardingStep): String {
        val labels = mapOf(
            OnboardingStep.WELCOME to "onboarding.step.welcome",
            OnboardingStep.VALUE to "onboarding.step.value",
            OnboardingStep.PERSONA to "onboarding.step.persona",
            OnboardingStep.LOCATION to "onboarding.step.location",
            OnboardingStep.NOTIFICATIONS to "onboarding.step.notifications",
            OnboardingStep.HEALTH to "onboarding.step.health",
            OnboardingStep.FIRST_RESULT to "onboarding.step.first_result"
        )
        return ctx.l(labels[step] ?: "onboarding.step.welcome")
    }
}
