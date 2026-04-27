package com.hiair.ui.render

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.location.LocationManager
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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
        val profileIdInput = EditText(activity).apply { hint = ctx.l("settings.profile_id") }
        val pushTokenInput = EditText(activity).apply { hint = ctx.l("settings.push_device_token") }
        val pushAlertsBox = CheckBox(activity).apply { text = ctx.l("settings.push"); isChecked = true }
        val profileAlertingBox = CheckBox(activity).apply { text = ctx.l("settings.profile_alerting"); isChecked = true }
        val quietStartInput = EditText(activity).apply { hint = ctx.l("settings.quiet_start"); setText("22") }
        val quietEndInput = EditText(activity).apply { hint = ctx.l("settings.quiet_end"); setText("7") }
        val homeLatInput = EditText(activity).apply { hint = ctx.l("settings.home_lat"); setText("41.39") }
        val homeLonInput = EditText(activity).apply { hint = ctx.l("settings.home_lon"); setText("2.17") }
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
        val sensitivitySpinner = Spinner(activity)
        val sensitivityOptions = listOf("low", "medium", "high")
        val sensitivityLabels = listOf(
            ctx.l("settings.sensitivity_low"),
            ctx.l("settings.sensitivity_medium"),
            ctx.l("settings.sensitivity_high")
        )
        sensitivitySpinner.adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, sensitivityLabels)
        val subscriptionSpinner = Spinner(activity)
        val languageLabel = TextView(activity).apply { text = ctx.l("settings.language"); textSize = 14f; setTextColor(Color.parseColor("#A6B6D2")) }
        val statusText = TextView(activity).apply { text = ctx.l("settings.load_save"); textSize = 16f; setTextColor(Color.parseColor("#A6B6D2")) }

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
                        profileIdInput.setText(state.profileId)
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
                        profileIdInput.setText(state.profileId)
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
        val createProfileButton = V2Ui.secondaryButton(activity, ctx.l("settings.create_profile")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
                val selectedPersonaIndex = personaSpinner.selectedItemPosition.coerceIn(0, personaOptions.lastIndex)
                val selectedSensitivityIndex = sensitivitySpinner.selectedItemPosition.coerceIn(0, sensitivityOptions.lastIndex)
                rootShell.settingsViewModel.setDefaultPersona(personaOptions[selectedPersonaIndex])
                rootShell.settingsViewModel.setSensitivityLevel(sensitivityOptions[selectedSensitivityIndex])
                rootShell.settingsViewModel.setHomeLat(homeLatInput.text.toString().toDoubleOrNull() ?: 41.39)
                rootShell.settingsViewModel.setHomeLon(homeLonInput.text.toString().toDoubleOrNull() ?: 2.17)
                Thread {
                    rootShell.settingsViewModel.createProfile()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        profileIdInput.setText(state.profileId)
                        ctx.rootShell.symptomLogViewModel.updateProfileId(state.profileId)
                        persistSession()
                        statusText.text = state.statusText
                    }
                }.start()
            }
        }
        val registerPushButton = V2Ui.secondaryButton(activity, ctx.l("settings.register_push_device")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
                rootShell.settingsViewModel.setProfileId(profileIdInput.text.toString())
                rootShell.settingsViewModel.setPushDeviceToken(pushTokenInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.registerPushDeviceToken()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = state.statusText }
                }.start()
            }
        }
        val useCurrentLocationButton = V2Ui.secondaryButton(activity, ctx.l("settings.use_current_location")).apply {
            setOnClickListener {
                val fineGranted = ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                val coarseGranted = ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                if (!fineGranted && !coarseGranted) {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        ),
                        REQUEST_LOCATION
                    )
                    statusText.text = ctx.l("settings.location_permission_requested")
                    return@setOnClickListener
                }
                val locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                val location = providers.firstNotNullOfOrNull { provider ->
                    runCatching { locationManager.getLastKnownLocation(provider) }.getOrNull()
                }
                if (location == null) {
                    statusText.text = ctx.l("settings.location_unavailable")
                    return@setOnClickListener
                }
                homeLatInput.setText("%.5f".format(location.latitude))
                homeLonInput.setText("%.5f".format(location.longitude))
                rootShell.settingsViewModel.setHomeLat(location.latitude)
                rootShell.settingsViewModel.setHomeLon(location.longitude)
                statusText.text = ctx.l("settings.location_updated")
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
        val exportPrivacyButton = V2Ui.secondaryButton(activity, ctx.l("settings.export_privacy_data")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.exportPrivacyData()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread { statusText.text = state.statusText }
                }.start()
            }
        }
        val deleteAccountButton = V2Ui.secondaryButton(activity, ctx.l("settings.delete_account")).apply {
            setOnClickListener {
                statusText.text = ctx.l("common.loading")
                rootShell.settingsViewModel.setUserId(userIdInput.text.toString())
                rootShell.settingsViewModel.setAccessToken(tokenInput.text.toString())
                Thread {
                    rootShell.settingsViewModel.deleteAccount()
                    val state = rootShell.settingsViewModel.state
                    activity.runOnUiThread {
                        clearSession()
                        userIdInput.setText("")
                        tokenInput.setText("")
                        profileIdInput.setText("")
                        statusText.text = state.statusText
                    }
                }.start()
            }
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
        profileIdInput.setText(state.profileId)
        pushTokenInput.setText(state.pushDeviceToken)
        emailInput.setText(state.email)
        pushAlertsBox.isChecked = state.pushAlertsEnabled
        profileAlertingBox.isChecked = state.profileBasedAlerting
        quietStartInput.setText(state.quietHoursStart.toString())
        quietEndInput.setText(state.quietHoursEnd.toString())
        val thresholdIndex = thresholdOptions.indexOf(state.alertThreshold)
        if (thresholdIndex >= 0) thresholdSpinner.setSelection(thresholdIndex)
        val personaIndex = personaOptions.indexOf(state.defaultPersona)
        if (personaIndex >= 0) personaSpinner.setSelection(personaIndex)
        val sensitivityIndex = sensitivityOptions.indexOf(state.sensitivityLevel)
        if (sensitivityIndex >= 0) sensitivitySpinner.setSelection(sensitivityIndex)
        homeLatInput.setText(state.homeLat.toString())
        homeLonInput.setText(state.homeLon.toString())
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
        val accountCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.security_privacy"))
            addView(emailInput)
            addView(passwordInput)
            addView(authRow)
            addView(userIdInput)
            addView(tokenInput)
            addView(profileIdInput)
            addView(statusText)
            addView(exportPrivacyButton)
            addView(deleteAccountButton)
            addView(logoutButton)
        }
        bodyContainer.addView(accountCard)

        val notificationsCard = V2Ui.cardContainer(activity).apply {
            addView(sectionTitle("settings.notifications"))
            addView(pushAlertsBox)
            addView(pushTokenInput)
            addView(registerPushButton)
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
            addView(sensitivitySpinner)
            addView(homeLatInput)
            addView(homeLonInput)
            addView(useCurrentLocationButton)
            addView(createProfileButton)
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

    private const val REQUEST_LOCATION = 4108
}
