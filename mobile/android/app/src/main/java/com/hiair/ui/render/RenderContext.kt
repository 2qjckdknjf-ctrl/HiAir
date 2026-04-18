package com.hiair.ui.render

import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.RootShellViewModel

data class RenderContext(
    val activity: AppCompatActivity,
    val rootShell: RootShellViewModel,
    val titleView: TextView,
    val bodyContainer: LinearLayout,
    val persistSession: () -> Unit,
    val clearSession: () -> Unit,
    val rerender: () -> Unit
) {
    fun l(key: String): String = AndroidL10n.t(key, rootShell.settingsViewModel.state.preferredLanguage)
}
