package com.hiair.ui.render

import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import com.hiair.StoreScreenshotMode
import com.hiair.BuildConfig
import com.hiair.health.WearableHealthHost
import android.widget.ArrayAdapter
import android.widget.AdapterView
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.markGeometry
import com.hiair.ui.design.Tokens
import com.hiair.ui.family.FamilyRiskParser
import com.hiair.ui.theme.V2Ui
import java.util.Locale

internal object SettingsScreenRenderer {
    fun render(ctx: RenderContext) {
        val ctx = ctx.withStoreContentRoot("settings")
        if (StoreScreenshotMode.active) {
            renderStoreScreenshot(ctx)
            return
        }
        renderFullSettings(ctx)
    }

    private fun renderStoreScreenshot(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val state = rootShell.settingsViewModel.state
        val bodyContainer = ctx.bodyContainer

        ctx.titleView.text = ctx.l("title.settings")
        com.hiair.ui.design.HiAirV4Presentation.applyTitleAxisAlignment(ctx.titleView, activity)

        val canvas = com.hiair.ui.design.HiAirV4Presentation.boundedCanvasHost(activity)
        bodyContainer.addView(canvas)

        val header = V2Ui.styledSecondaryText(activity, ctx.l("settings.subtitle")).apply {
            textSize = 13f
            gravity = Gravity.CENTER_HORIZONTAL
        }
        canvas.addView(header)

        val accountCard = HiAirComponents.cardContainer(activity).apply {
            markGeometry(com.hiair.ui.accessibility.HiAirGeometryMarkers.SETTINGS_ACCOUNT)
            addView(sectionTitle(ctx, "auth.title"))
            addView(V2Ui.styledBodyText(activity, state.email).apply { textSize = 15f })
            addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.premium_active")))
        }

        val wearableConnected = state.wearableStatus.contains("connected", ignoreCase = true) ||
            state.wearableStatus.contains("подключ", ignoreCase = true)
        val wearablesCard = HiAirComponents.cardContainer(activity).apply {
            markGeometry(com.hiair.ui.accessibility.HiAirGeometryMarkers.SETTINGS_HEALTH)
            addView(sectionTitle(ctx, "settings.wearables.title"))
            addView(V2Ui.styledSecondaryText(activity, state.wearableStatus))
            if (wearableConnected) {
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("settings.wearables.disconnect")).apply {
                        layoutParams = com.hiair.ui.design.HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                    },
                )
            } else {
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("wearable.consent.connect")).apply {
                        layoutParams = com.hiair.ui.design.HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                    },
                )
            }
        }

        val prefsNotifications = HiAirComponents.cardContainer(activity).apply {
            addView(sectionTitle(ctx, "settings.notifications"))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.push")))
        }

        val prefsSubscription = HiAirComponents.cardContainer(activity).apply {
            addView(sectionTitle(ctx, "settings.subscription"))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.premium_active")))
            addView(sectionTitle(ctx, "settings.profile"))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.persona_adult")))
        }

        val securityCard = com.hiair.ui.design.HiAirV4Glass.sectionCard(
            activity,
            com.hiair.ui.design.HiAirV4Glass.Emphasis.DESTRUCTIVE,
        ).apply {
            markGeometry(com.hiair.ui.accessibility.HiAirGeometryMarkers.SETTINGS_DESTRUCTIVE)
            addView(sectionTitle(ctx, "settings.security_privacy"))
            addView(
                HiAirComponents.secondaryButton(activity, ctx.l("settings.privacy_export")).apply {
                    layoutParams = com.hiair.ui.design.HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                },
            )
            addView(V2Ui.spacer(activity, 8))
            addView(
                HiAirComponents.secondaryButton(activity, ctx.l("settings.delete_account")).apply {
                    layoutParams = com.hiair.ui.design.HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                    setTextColor(Tokens.Feedback.errorSoft)
                },
            )
        }

        val snapshot = com.hiair.ui.design.HiAirResponsiveLayout.windowSnapshot(activity)
        val useTwoColumn = com.hiair.ui.design.HiAirScreenMetrics.allowsTwoColumn(snapshot.rawWindowWidthDp)
        if (useTwoColumn) {
            fun settingsRow(left: android.view.View, right: android.view.View): LinearLayout {
                return LinearLayout(activity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    )
                    val leftCol = LinearLayout(activity).apply {
                        orientation = LinearLayout.VERTICAL
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    }
                    val rightCol = LinearLayout(activity).apply {
                        orientation = LinearLayout.VERTICAL
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                            marginStart = V2Ui.dp(activity, com.hiair.ui.design.HiAirSpacing.md)
                        }
                    }
                    leftCol.addView(left)
                    rightCol.addView(right)
                    addView(leftCol)
                    addView(rightCol)
                }
            }
            val host = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                markGeometry(com.hiair.ui.accessibility.HiAirGeometryMarkers.SETTINGS_SECTIONS)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
            }
            host.addView(settingsRow(accountCard, prefsNotifications))
            host.addView(V2Ui.spacer(activity, com.hiair.ui.design.HiAirSpacing.sm))
            host.addView(settingsRow(wearablesCard, prefsSubscription))
            host.addView(V2Ui.spacer(activity, com.hiair.ui.design.HiAirSpacing.sm))
            host.addView(
                settingsRow(
                    android.widget.Space(activity),
                    securityCard,
                ),
            )
            canvas.addView(host)
        } else {
            listOf(accountCard, wearablesCard, prefsNotifications, prefsSubscription, securityCard).forEach {
                canvas.addView(it)
            }
        }
    }

    private fun sectionTitle(ctx: RenderContext, key: String): TextView {
        return HiAirComponents.sectionTitle(ctx.activity, ctx.l(key))
    }

    private fun renderFullSettings(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer
        val persistSession = ctx.persistSession
        val clearSession = ctx.clearSession

        bodyContainer.addView(HiAirComponents.screenWordmark(activity, ctx.l("nav.settings")))
        HiAirComponents.hidePageTitle(titleView)
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.subtitle")).apply { textSize = 13f })
        val emailInput = HiAirComponents.inputField(activity, ctx.l("settings.email"))
        val passwordInput = HiAirComponents.inputField(activity, ctx.l("settings.password"))
        val pushAlertsBox = CheckBox(activity).apply { text = ctx.l("settings.push"); isChecked = true }
        val morningBriefingBox = CheckBox(activity).apply { text = ctx.l("settings.morning_briefing"); isChecked = false }
        val morningBriefingTimeInput = EditText(activity).apply { hint = ctx.l("settings.morning_briefing_time"); setText("07:30") }
        val profileAlertingBox = CheckBox(activity).apply { text = ctx.l("settings.profile_alerting"); isChecked = true }
        val quietStartInput = EditText(activity).apply { hint = ctx.l("settings.quiet_start"); setText("22") }
        val quietEndInput = EditText(activity).apply { hint = ctx.l("settings.quiet_end"); setText("7") }
        val thresholdSpinner = Spinner(activity)
        val thresholdOptions = listOf("medium", "high", "very_high")
        val thresholdLabels = listOf(
            ctx.l("settings.threshold_medium"),
            ctx.l("settings.threshold_high"),
            ctx.l("settings.threshold_very_high")
        )
        thresholdSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, thresholdLabels)
        val languageSpinner = Spinner(activity)
        val languageOptions = listOf("ru", "en", "es", "it", "fr")
        val languageLabels = listOf(
            ctx.l("settings.language_ru"),
            ctx.l("settings.language_en"),
            ctx.l("settings.language_es"),
            ctx.l("settings.language_it"),
            ctx.l("settings.language_fr")
        )
        languageSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, languageLabels)
        val personaSpinner = Spinner(activity)
        val personaOptions = listOf("adult", "child", "elderly", "asthma", "allergy", "runner", "worker")
        val personaLabels = listOf(
            ctx.l("settings.persona_adult"),
            ctx.l("settings.persona_child"),
            ctx.l("settings.persona_elderly"),
            ctx.l("settings.persona_asthma"),
            ctx.l("settings.persona_allergy"),
            ctx.l("settings.persona_runner"),
            ctx.l("settings.persona_worker")
        )
        personaSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, personaLabels)
        val subscriptionSpinner = Spinner(activity)
        val aiWindowInput = EditText(activity).apply { hint = ctx.l("settings.ai_window"); setText("24") }
        val languageLabel = TextView(activity).apply { text = ctx.l("settings.language"); textSize = 14f; setTextColor(Tokens.Text.secondary) }
        val aiMetricLabel = TextView(activity).apply { text = ctx.l("settings.ai_metric"); textSize = 14f; setTextColor(Tokens.Text.secondary) }
        val aiMetricSpinner = Spinner(activity)
        val aiMetricOptions = listOf("total", "fallback", "guardrail", "errors", "timeout", "network", "server")
        val aiMetricLabels = listOf(
            ctx.l("settings.ai_metric_total"),
            ctx.l("settings.ai_metric_fallback"),
            ctx.l("settings.ai_metric_guardrail"),
            ctx.l("settings.ai_metric_errors"),
            ctx.l("settings.ai_metric_timeout"),
            ctx.l("settings.ai_metric_network"),
            ctx.l("settings.ai_metric_server")
        )
        aiMetricSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, aiMetricLabels)
        val aiModeLabel = TextView(activity).apply { text = ctx.l("settings.ai_mode"); textSize = 14f; setTextColor(Tokens.Text.secondary) }
        val aiModeSpinner = Spinner(activity)
        val aiModeOptions = listOf("bars", "line")
        val aiModeLabels = listOf(ctx.l("settings.ai_mode_bars"), ctx.l("settings.ai_mode_line"))
        aiModeSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, aiModeLabels)
        val aiSummaryText = TextView(activity).apply { text = ctx.l("settings.ai_summary"); textSize = 14f; setTextColor(Tokens.Text.secondary) }
        val aiTrendText = TextView(activity).apply { text = ctx.l("settings.ai_trend"); textSize = 14f; setTextColor(Tokens.Text.secondary) }
        val aiGraphText = TextView(activity).apply { text = ctx.l("settings.ai_graph"); textSize = 14f; setTextColor(Tokens.Feedback.info) }
        val aiRangeText = TextView(activity).apply { text = "${ctx.l("settings.ai_range")}: -"; textSize = 13f; setTextColor(Tokens.Text.secondary) }
        val aiAxisText = TextView(activity).apply { text = "${ctx.l("settings.ai_axis")}: -"; textSize = 13f; setTextColor(Tokens.Text.secondary) }
        val aiRequestStatusText = TextView(activity).apply { text = "${ctx.l("settings.ai_request_status")}: ${ctx.l("settings.ai_request_idle")}"; textSize = 13f; setTextColor(Tokens.Text.secondary) }
        val aiLastUpdatedText = TextView(activity).apply { text = "${ctx.l("settings.ai_last_updated")}: -"; textSize = 13f; setTextColor(Tokens.Text.secondary) }
        val aiInlineErrorText = TextView(activity).apply { text = ""; textSize = 13f; setTextColor(Tokens.Feedback.errorSoft) }
        val aiTrendChart = AITrendChartView(activity).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                V2Ui.dp(activity, 72)
            )
        }
        val aiBreakdownText = TextView(activity).apply { text = ctx.l("settings.ai_breakdown"); textSize = 14f; setTextColor(Tokens.Text.secondary) }
        val statusText = TextView(activity).apply { text = ctx.l("settings.load_save"); textSize = 16f; setTextColor(Tokens.Text.secondary) }
        val aiRetryButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.ai_retry_now"))
        val mainHandler = Handler(Looper.getMainLooper())
        var aiRefreshRunnable: Runnable? = null
        var aiTimeoutRunnable: Runnable? = null

        fun applyAiState(state: com.hiair.ui.settings.SettingsState) {
            aiSummaryText.text = state.aiSummaryText
            aiTrendText.text = state.aiTrendText
            aiGraphText.text = state.aiTrendGraphText
            val chartPoints = chartPointsForMetric(state, state.aiChartMetric)
            aiTrendChart.setChartMode(state.aiChartMode)
            aiTrendChart.setTrendPoints(chartPoints)
            aiRangeText.text = "${ctx.l("settings.ai_range")}: ${rangeText(chartPoints)}"
            aiAxisText.text = "${ctx.l("settings.ai_axis")}: ${state.aiTrendStartLabel} -> ${state.aiTrendEndLabel}"
            val statusLabel = when {
                state.aiRequestInFlight -> ctx.l("settings.ai_request_loading")
                state.aiRequestTimedOut -> ctx.l("settings.ai_request_timeout")
                else -> ctx.l("settings.ai_request_idle")
            }
            aiRequestStatusText.text = "${ctx.l("settings.ai_request_status")}: $statusLabel"
            aiLastUpdatedText.text = "${ctx.l("settings.ai_last_updated")}: ${state.aiLastUpdatedLabel}"
            aiInlineErrorText.text = state.aiInlineErrorText
            aiRetryButton.text = if (state.aiInlineActionText.isBlank()) ctx.l("settings.ai_retry_now") else state.aiInlineActionText
            aiRetryButton.isEnabled = state.aiInlineActionType != "retry_later"
            aiRetryButton.alpha = if (aiRetryButton.isEnabled) 1f else 0.65f
            aiRetryButton.visibility = if (state.aiInlineErrorText.isNotBlank() || state.aiRequestTimedOut) android.view.View.VISIBLE else android.view.View.GONE
            aiBreakdownText.text = state.aiBreakdownText
        }

        fun requestAiRefreshDebounced(delayMs: Long = 500L) {
            aiRefreshRunnable?.let(mainHandler::removeCallbacks)
            aiRefreshRunnable = Runnable {
                statusText.text = ctx.l("common.loading")
                val requestId = rootShell.settingsViewModel.beginAiSummaryRequest()
                aiRequestStatusText.text = "${ctx.l("settings.ai_request_status")}: ${ctx.l("settings.ai_request_loading")}"
                aiTimeoutRunnable?.let(mainHandler::removeCallbacks)
                aiTimeoutRunnable = Runnable {
                    rootShell.settingsViewModel.markAiSummaryTimeout(requestId)
                    applyAiState(rootShell.settingsViewModel.state)
                }
                mainHandler.postDelayed(aiTimeoutRunnable!!, 8000L)
                Thread {
                    rootShell.settingsViewModel.loadAiSummary(requestId = requestId)
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        if (requestId != rootShell.settingsViewModel.currentAiSummaryRequestId()) {
                            return@runOnUiThread
                        }
                        aiTimeoutRunnable?.let(mainHandler::removeCallbacks)
                        applyAiState(state)
                        statusText.text = state.statusText
                    }
                }.start()
            }
            mainHandler.postDelayed(aiRefreshRunnable!!, delayMs)
        }
        aiRetryButton.setOnClickListener { requestAiRefreshDebounced(delayMs = 0L) }

        val loginButton = HiAirComponents.primaryButton(activity, ctx.l("settings.log_in")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setEmail(emailInput.text.toString())
                rootShell.settingsViewModel.setPassword(passwordInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.login {
                        activity.runOnUiThread {
                            val state = rootShell.settingsViewModel.state
                            persistSession()
                            statusText.text = state.statusText
                            ctx.rerender()
                        }
                    }
                }.start()
            }
        }
        val signupButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.sign_up")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setEmail(emailInput.text.toString())
                rootShell.settingsViewModel.setPassword(passwordInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.signup()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        persistSession()
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val loadButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.load")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                Thread {
                    rootShell.settingsViewModel.loadSettings()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        pushAlertsBox.isChecked = state.pushAlertsEnabled
                        val thresholdIndex = thresholdOptions.indexOf(state.alertThreshold)
                        if (thresholdIndex >= 0) thresholdSpinner.setSelection(thresholdIndex)
                        val personaIndex = personaOptions.indexOf(state.defaultPersona)
                        if (personaIndex >= 0) personaSpinner.setSelection(personaIndex)
                        val langIndex = languageOptions.indexOf(state.preferredLanguage)
                        if (langIndex >= 0) languageSpinner.setSelection(langIndex)
                        profileAlertingBox.isChecked = state.profileBasedAlerting
                        morningBriefingBox.isChecked = state.morningBriefingEnabled
                        morningBriefingTimeInput.setText(state.morningBriefingTime)
                        quietStartInput.setText(state.quietHoursStart.toString())
                        quietEndInput.setText(state.quietHoursEnd.toString())
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val saveButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.save")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setPushAlertsEnabled(pushAlertsBox.isChecked)
                val selectedThresholdIndex = thresholdSpinner.selectedItemPosition.coerceIn(0, thresholdOptions.lastIndex)
                rootShell.settingsViewModel.setAlertThreshold(thresholdOptions[selectedThresholdIndex])
                val selectedPersonaIndex = personaSpinner.selectedItemPosition.coerceIn(0, personaOptions.lastIndex)
                rootShell.settingsViewModel.setDefaultPersona(personaOptions[selectedPersonaIndex])
                val selectedLangIndex = languageSpinner.selectedItemPosition.coerceIn(0, languageOptions.lastIndex)
                rootShell.settingsViewModel.setPreferredLanguage(languageOptions[selectedLangIndex])
                rootShell.settingsViewModel.setProfileBasedAlerting(profileAlertingBox.isChecked)
                rootShell.settingsViewModel.setMorningBriefingEnabled(morningBriefingBox.isChecked)
                rootShell.settingsViewModel.setMorningBriefingTime(morningBriefingTimeInput.text.toString())
                rootShell.settingsViewModel.setQuietHoursStart(quietStartInput.text.toString().toIntOrNull() ?: 22)
                rootShell.settingsViewModel.setQuietHoursEnd(quietEndInput.text.toString().toIntOrNull() ?: 7)
                Thread {
                    rootShell.settingsViewModel.saveSettings()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        persistSession()
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val loadPlansButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.load_plans")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                Thread {
                    rootShell.settingsViewModel.loadSubscriptionPlans()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        val labels = state.subscriptionPlans.map { "${it.second} (${it.first})" }
                        subscriptionSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, labels)
                        val selectedIndex = state.subscriptionPlans.indexOfFirst { it.first == state.selectedPlanId }
                        if (selectedIndex >= 0) subscriptionSpinner.setSelection(selectedIndex)
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val loadSubscriptionButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.load_subscription")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                Thread {
                    rootShell.settingsViewModel.loadSubscriptionStatus()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = "${state.statusText} Status=${state.subscriptionStatus}" }
                }.start()
            }
        }
        val activateSubscriptionButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.activate_subscription")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                val selectedIndex = subscriptionSpinner.selectedItemPosition
                val plans = rootShell.settingsViewModel.state.subscriptionPlans
                if (selectedIndex in plans.indices) rootShell.settingsViewModel.setSelectedPlanId(plans[selectedIndex].first)
                Thread {
                    rootShell.settingsViewModel.activateSubscription()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = "${state.statusText} Status=${state.subscriptionStatus}" }
                }.start()
            }
        }
        val cancelSubscriptionButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.cancel_subscription")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                Thread {
                    rootShell.settingsViewModel.cancelSubscription()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = "${state.statusText} Status=${state.subscriptionStatus}" }
                }.start()
            }
        }
        val logoutButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.log_out")).apply {
            setOnClickListener {
                rootShell.settingsViewModel.resetSessionAfterLogout()
                rootShell.dashboardViewModel.reset()
                clearSession()
                statusText.text = ctx.l("settings.logged_out")
                ctx.rerender()
            }
        }
        val privacyExportSummary = V2Ui.styledSecondaryText(
            activity,
            rootShell.settingsViewModel.state.privacyExportSummary
        ).apply {
            textSize = 13f
        }
        val exportPrivacyButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.privacy_export")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                Thread {
                    rootShell.settingsViewModel.exportPrivacyData()
                    val updated = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        privacyExportSummary.text = updated.privacyExportSummary
                        statusText.text = updated.statusText
                    }
                }.start()
            }
        }
        val deleteAccountButton = HiAirComponents.secondaryButton(activity, ctx.l("settings.delete_account")).apply {
            setOnClickListener {
