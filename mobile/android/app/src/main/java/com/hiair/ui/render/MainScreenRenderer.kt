package com.hiair.ui.render

import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.OnboardingStore
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.ui.navigation.RootShellViewModel

class MainScreenRenderer(
    private val activity: AppCompatActivity,
    private val rootShell: RootShellViewModel,
    private val titleView: TextView,
    private val bodyContainer: LinearLayout,
    private val overlayContainer: FrameLayout,
    private val persistSession: () -> Unit,
    private val clearSession: () -> Unit,
    private val rerender: () -> Unit,
        restorePurchases = restorePurchases,
