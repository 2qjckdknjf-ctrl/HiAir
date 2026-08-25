package com.hiair.ui.design

import android.app.Activity
import android.content.Context
import android.view.View
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.hiair.ui.theme.V2Ui

/**
 * Unified scroll-tail contract for nav-bearing screens:
 * requiredBottomTail = measuredNavShellHeight + systemBottomInset + V4 spacing.
 */
object HiAirNavClearance {
    fun requiredBottomTailPx(context: Context, navShell: View?): Int {
        val activity = context as? Activity
        val bottomInset = if (activity != null) systemBottomInsetPx(activity) else 0
        val navHeight = if (navShell != null && navShell.visibility == View.VISIBLE) {
            navShell.height.coerceAtLeast(V2Ui.dp(context, 72))
        } else {
            0
        }
        val spacing = V2Ui.dp(context, HiAirSpacing.lg)
        return navHeight + bottomInset + spacing
    }

    fun systemBottomInsetPx(activity: Activity): Int {
        return systemInsets(activity).bottom
    }

    fun systemInsets(activity: Activity): Insets {
        val compat = ViewCompat.getRootWindowInsets(activity.window.decorView) ?: return Insets.NONE
        return compat.getInsets(
            WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
        )
    }
}
