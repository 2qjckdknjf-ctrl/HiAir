package com.hiair.ui.render

import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.ui.navigation.RootShellViewModel

class MainScreenRenderer(
    private val activity: AppCompatActivity,
    private val rootShell: RootShellViewModel,
    private val titleView: TextView,
    private val bodyContainer: LinearLayout,
    private val session: com.hiair.StoredSession,
    private val persistSession: () -> Unit,
    private val updateSession: (com.hiair.StoredSession) -> Unit,
    private val clearSession: () -> Unit,
    private val rerender: () -> Unit
) {
    private val ctx = RenderContext(
        activity = activity,
        rootShell = rootShell,
        titleView = titleView,
        bodyContainer = bodyContainer,
        session = session,
        persistSession = persistSession,
        updateSession = updateSession,
        clearSession = clearSession,
        rerender = rerender
    )

    fun renderOnboarding() = OnboardingScreenRenderer.render(ctx)

    fun renderDashboard() = DashboardScreenRenderer.render(ctx)

    fun renderPlanner() = PlannerScreenRenderer.render(ctx)

    fun renderSymptoms() = SymptomsScreenRenderer.render(ctx)

    fun renderSettings() = SettingsScreenRenderer.render(ctx)
}
