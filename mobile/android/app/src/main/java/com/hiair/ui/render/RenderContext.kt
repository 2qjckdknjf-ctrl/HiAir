package com.hiair.ui.render

import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.StoreScreenshotMode
import com.hiair.StoreScreenshotReadiness
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.RootShellViewModel

data class RenderContext(
    val activity: AppCompatActivity,
    val rootShell: RootShellViewModel,
    val titleView: TextView,
    val bodyContainer: LinearLayout,
    val overlayContainer: FrameLayout,
    val persistSession: () -> Unit,
    val clearSession: () -> Unit,
    val rerender: () -> Unit,
    val presentationOnly: Boolean = false,
) {
    fun l(key: String): String = AndroidL10n.t(key, rootShell.settingsViewModel.state.preferredLanguage)

    /** Dedicated content root so screen/root/ready/geometry markers never share one node. */
    fun withStoreContentRoot(target: String): RenderContext {
        if (!StoreScreenshotMode.active) return this
        val marker = StoreScreenshotReadiness.contentRootForTarget(target) ?: return this
        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            contentDescription = marker
        }
        bodyContainer.addView(root)
        return copy(bodyContainer = root)
    }
}
