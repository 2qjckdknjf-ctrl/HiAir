package com.hiair.ui.render

import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.widget.ArrayAdapter
import android.widget.AdapterView
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui

internal object SettingsScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer
        val persistSession = ctx.persistSession
        val clearSession = ctx.clearSession

        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("common.city_updated")).apply { textSize = 11f })
        titleView.text = ctx.l("title.settings")
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.subtitle")).apply { textSize = 13f })
        val emailInput = EditText(activity).apply { hint = ctx.l("settings.email") }
        val passwordInput = EditText(activity).apply { hint = ctx.l("settings.password") }
        val userIdInput = EditText(activity).apply { hint = ctx.l("settings.user_id") }
        val tokenInput = EditText(activity).apply { hint = ctx.l("settings.token") }
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
        val languageOptions = listOf("ru", "en")
        val languageLabels = listOf(ctx.l("settings.language_ru"), ctx.l("settings.language_en"))
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
        val languageLabel = TextView(activity).apply { text = ctx.l("settings.language"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiMetricLabel = TextView(activity).apply { text = ctx.l("settings.ai_metric"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
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
        val aiModeLabel = TextView(activity).apply { text = ctx.l("settings.ai_mode"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiModeSpinner = Spinner(activity)
        val aiModeOptions = listOf("bars", "line")
        val aiModeLabels = listOf(ctx.l("settings.ai_mode_bars"), ctx.l("settings.ai_mode_line"))
        aiModeSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, aiModeLabels)
        val aiSummaryText = TextView(activity).apply { text = ctx.l("settings.ai_summary"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiTrendText = TextView(activity).apply { text = ctx.l("settings.ai_trend"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiGraphText = TextView(activity).apply { text = ctx.l("settings.ai_graph"); textSize = 14f; setTextColor(Color.parseColor("#7BCBFF")) }
        val aiRangeText = TextView(activity).apply { text = "${ctx.l("settings.ai_range")}: -"; textSize = 13f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiAxisText = TextView(activity).apply { text = "${ctx.l("settings.ai_axis")}: -"; textSize = 13f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiRequestStatusText = TextView(activity).apply { text = "${ctx.l("settings.ai_request_status")}: ${ctx.l("settings.ai_request_idle")}"; textSize = 13f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiLastUpdatedText = TextView(activity).apply { text = "${ctx.l("settings.ai_last_updated")}: -"; textSize = 13f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiInlineErrorText = TextView(activity).apply { text = ""; textSize = 13f; setTextColor(Color.parseColor("#FF9AA2")) }
        val aiTrendChart = AITrendChartView(activity).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                V2Ui.dp(activity, 72)
            )
        }
        val aiBreakdownText = TextView(activity).apply { text = ctx.l("settings.ai_breakdown"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
        val statusText = TextView(activity).apply { text = ctx.l("settings.load_save"); textSize = 16f; setTextColor(Color.parseColor("#A6B6D2")) }
        val aiRetryButton = V2Ui.secondaryButton(activity, ctx.l("settings.ai_retry_now"))
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

        val signupButton = V2Ui.secondaryButton(activity, ctx.l("settings.sign_up")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setEmail(emailInput.text.toString())
                rootShell.settingsViewModel.setPassword(passwordInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.signup()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        userIdInput.setText(state.userId)
                        tokenInput.setText(state.accessToken)
                        persistSession()
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val loginButton = V2Ui.secondaryButton(activity, ctx.l("settings.log_in")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setEmail(emailInput.text.toString())
                rootShell.settingsViewModel.setPassword(passwordInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.login()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        userIdInput.setText(state.userId)
                        tokenInput.setText(state.accessToken)
                        persistSession()
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val loadButton = V2Ui.secondaryButton(activity, ctx.l("settings.load")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
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
        val saveButton = V2Ui.secondaryButton(activity, ctx.l("settings.save")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
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
        val loadPlansButton = V2Ui.secondaryButton(activity, ctx.l("settings.load_plans")).apply {
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
        val loadSubscriptionButton = V2Ui.secondaryButton(activity, ctx.l("settings.load_subscription")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.loadSubscriptionStatus()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = "${state.statusText} Status=${state.subscriptionStatus}" }
                }.start()
            }
        }
        val activateSubscriptionButton = V2Ui.secondaryButton(activity, ctx.l("settings.activate_subscription")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
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
        val cancelSubscriptionButton = V2Ui.secondaryButton(activity, ctx.l("settings.cancel_subscription")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.cancelSubscription()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = "${state.statusText} Status=${state.subscriptionStatus}" }
                }.start()
            }
        }
        val logoutButton = V2Ui.secondaryButton(activity, ctx.l("settings.log_out")).apply {
            setOnClickListener {
                rootShell.settingsViewModel.setUserId("")
                rootShell.settingsViewModel.setAccessToken("")
                rootShell.settingsViewModel.setPassword("")
                clearSession()
                userIdInput.setText("")
                tokenInput.setText("")
                statusText.text = ctx.l("settings.logged_out")
            }
        }
        val loadAiSummaryButton = V2Ui.secondaryButton(activity, ctx.l("settings.load_ai_summary")).apply {
            setOnClickListener {
                val windowHours = aiWindowInput.text.toString().toIntOrNull() ?: 24
                rootShell.settingsViewModel.setAiSummaryHours(windowHours)
                requestAiRefreshDebounced(delayMs = 0L)
            }
        }

        aiMetricSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: android.view.View?, position: Int, id: Long) {
                val metric = aiMetricOptions[position.coerceIn(0, aiMetricOptions.lastIndex)]
                rootShell.settingsViewModel.setAiChartMetric(metric)
                val state = rootShell.settingsViewModel.state
                val chartPoints = chartPointsForMetric(state, metric)
                aiGraphText.text = state.aiTrendGraphText
                aiTrendChart.setTrendPoints(chartPoints)
                aiRangeText.text = "${ctx.l("settings.ai_range")}: ${rangeText(chartPoints)}"
                if (state.aiTrendPoints.isEmpty()) {
                    requestAiRefreshDebounced()
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }
        aiModeSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: android.view.View?, position: Int, id: Long) {
                val mode = aiModeOptions[position.coerceIn(0, aiModeOptions.lastIndex)]
                rootShell.settingsViewModel.setAiChartMode(mode)
                aiTrendChart.setChartMode(mode)
                if (rootShell.settingsViewModel.state.aiTrendPoints.isEmpty()) {
                    requestAiRefreshDebounced()
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }

        val authRow = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(signupButton)
            addView(loginButton)
        }

        fun sectionTitle(key: String): TextView = V2Ui.styledBodyText(activity, ctx.l(key)).apply { textSize = 17f }

        val state = rootShell.settingsViewModel.state
        userIdInput.setText(state.userId)
        tokenInput.setText(state.accessToken)
        emailInput.setText(state.email)
        pushAlertsBox.isChecked = state.pushAlertsEnabled
        profileAlertingBox.isChecked = state.profileBasedAlerting
        morningBriefingBox.isChecked = state.morningBriefingEnabled
        morningBriefingTimeInput.setText(state.morningBriefingTime)
        quietStartInput.setText(state.quietHoursStart.toString())
        quietEndInput.setText(state.quietHoursEnd.toString())
        val thresholdIndex = thresholdOptions.indexOf(state.alertThreshold)
        if (thresholdIndex >= 0) thresholdSpinner.setSelection(thresholdIndex)
        val personaIndex = personaOptions.indexOf(state.defaultPersona)
        if (personaIndex >= 0) personaSpinner.setSelection(personaIndex)
        val langIndex = languageOptions.indexOf(state.preferredLanguage)
        if (langIndex >= 0) languageSpinner.setSelection(langIndex)
        if (state.subscriptionPlans.isNotEmpty()) {
            val labels = state.subscriptionPlans.map { "${it.second} (${it.first})" }
            subscriptionSpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, labels)
            val selectedIndex = state.subscriptionPlans.indexOfFirst { it.first == state.selectedPlanId }
            if (selectedIndex >= 0) subscriptionSpinner.setSelection(selectedIndex)
        }
        if (statusText.text.isNullOrBlank() || statusText.text == ctx.l("settings.load_save")) {
            statusText.text = "${ctx.l("settings.load_save")} Subscription=${state.subscriptionStatus}"
        }
        aiSummaryText.text = state.aiSummaryText
        aiTrendText.text = state.aiTrendText
        aiGraphText.text = state.aiTrendGraphText
        applyAiState(state)
        aiWindowInput.setText(state.aiSummaryHours.toString())
        val metricIndex = aiMetricOptions.indexOf(state.aiChartMetric)
        if (metricIndex >= 0) aiMetricSpinner.setSelection(metricIndex, false)
        val modeIndex = aiModeOptions.indexOf(state.aiChartMode)
        if (modeIndex >= 0) aiModeSpinner.setSelection(modeIndex, false)
        aiWindowInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) {
                val parsed = s?.toString()?.toIntOrNull() ?: return
                val normalized = if (parsed <= 24) 24 else 72
                if (normalized != rootShell.settingsViewModel.state.aiSummaryHours) {
                    rootShell.settingsViewModel.setAiSummaryHours(normalized)
                    requestAiRefreshDebounced()
                }
            }
        })

        val accountCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.security_privacy"))
            addView(emailInput)
            addView(passwordInput)
            addView(authRow)
            addView(userIdInput)
            addView(tokenInput)
            addView(statusText)
            addView(logoutButton)
        }
        bodyContainer.addView(accountCard)

        val notificationsCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.notifications"))
            addView(pushAlertsBox)
            addView(morningBriefingBox)
            addView(morningBriefingTimeInput)
            if (state.userId.isBlank()) {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.briefing_setup_hint")))
            }
            addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.morning_briefing_hint")))
            addView(profileAlertingBox)
            addView(quietStartInput)
            addView(quietEndInput)
            addView(thresholdSpinner)
            addView(loadButton)
            addView(saveButton)
        }
        bodyContainer.addView(notificationsCard)

        val defaultsCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.profile_defaults"))
            addView(personaSpinner)
            addView(languageLabel)
            addView(languageSpinner)
        }
        bodyContainer.addView(defaultsCard)

        val subscriptionCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.subscription"))
            addView(subscriptionSpinner)
            addView(loadPlansButton)
            addView(loadSubscriptionButton)
            addView(activateSubscriptionButton)
            addView(cancelSubscriptionButton)
        }
        bodyContainer.addView(subscriptionCard)

        val advancedAiContainer = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            addView(aiMetricLabel)
            addView(aiMetricSpinner)
            addView(aiModeLabel)
            addView(aiModeSpinner)
            addView(aiGraphText)
            addView(aiRangeText)
            addView(aiAxisText)
            addView(aiRequestStatusText)
            addView(aiLastUpdatedText)
            addView(aiInlineErrorText)
            addView(aiRetryButton)
            addView(aiTrendChart)
            addView(aiBreakdownText)
        }
        val advancedAiToggle = V2Ui.secondaryButton(activity, ctx.l("settings.advanced_controls")).apply {
            setOnClickListener {
                val expanded = advancedAiContainer.visibility == View.VISIBLE
                advancedAiContainer.visibility = if (expanded) View.GONE else View.VISIBLE
                text = if (expanded) {
                    ctx.l("settings.advanced_controls")
                } else {
                    ctx.l("settings.advanced_controls_hide")
                }
            }
        }

        val aiCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.ai_observability"))
            addView(aiWindowInput)
            addView(aiSummaryText)
            addView(aiTrendText)
            addView(advancedAiToggle)
            addView(advancedAiContainer)
            addView(loadAiSummaryButton)
        }
        bodyContainer.addView(aiCard)

        fun swatchRow(label: String, color: Int): LinearLayout {
            val dot = View(activity).apply {
                layoutParams = LinearLayout.LayoutParams(V2Ui.dp(activity, 14), V2Ui.dp(activity, 14)).apply {
                    rightMargin = V2Ui.dp(activity, 8)
                }
                background = V2Ui.cardBackground(
                    activity,
                    fillHex = String.format("#%08X", color),
                    strokeHex = "#40FFFFFF",
                    radiusDp = 999
                )
            }
            val text = V2Ui.styledSecondaryText(activity, label).apply { textSize = 13f }
            return LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(dot)
                addView(text)
            }
        }

        val tokenCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.advanced_controls"))
            addView(V2Ui.styledSecondaryText(activity, "Developer · Design tokens"))
            addView(swatchRow("Risk low", Tokens.RiskAccent.low))
            addView(swatchRow("Risk moderate", Tokens.RiskAccent.moderate))
            addView(swatchRow("Risk high", Tokens.RiskAccent.high))
            addView(swatchRow("Risk very high", Tokens.RiskAccent.veryHigh))
            addView(swatchRow("CTA start", Tokens.Cta.start))
            addView(swatchRow("CTA end", Tokens.Cta.end))
        }
        bodyContainer.addView(tokenCard)

        bodyContainer.addView(V2Ui.primaryButton(activity, ctx.l("settings.sync_now")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
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
                    val savedState = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        persistSession()
                        statusText.text = savedState.statusText
                    }
                }.start()
            }
        })
    }

    private fun chartPointsForMetric(state: com.hiair.ui.settings.SettingsState, metric: String): List<Int> {
        return when (metric) {
            "fallback" -> state.aiTrendFallbackPoints
            "guardrail" -> state.aiTrendGuardrailPoints
            "errors" -> state.aiTrendErrorPoints
            "timeout" -> state.aiTrendTimeoutPoints
            "network" -> state.aiTrendNetworkPoints
            "server" -> state.aiTrendServerPoints
            else -> state.aiTrendPoints
        }
    }

    private fun rangeText(points: List<Int>): String {
        if (points.isEmpty()) return "-"
        val min = points.minOrNull() ?: 0
        val max = points.maxOrNull() ?: 0
        return "$min-$max"
    }
}
