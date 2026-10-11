package com.hiair.ui.config

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.appcompat.app.AppCompatActivity

/** Canonical production legal URLs (shared by paywall, settings, store metadata). */
object HiAirLegalUrls {
    const val TERMS = "https://hiair.io/terms/"
    const val PRIVACY = "https://hiair.io/privacy/"
    const val SUPPORT_EMAIL = "hello@hiair.io"
    const val PLAY_MANAGE_SUBSCRIPTIONS = "https://play.google.com/store/account/subscriptions"

    fun openTerms(activity: AppCompatActivity): Boolean = openUrl(activity, TERMS)

    fun openPrivacy(activity: AppCompatActivity): Boolean = openUrl(activity, PRIVACY)

    fun openSupport(activity: AppCompatActivity): Boolean {
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$SUPPORT_EMAIL"))
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            openUrl(activity, "https://hiair.io")
        }
    }

    fun openPlayManageSubscriptions(activity: AppCompatActivity): Boolean {
        val packaged = "$PLAY_MANAGE_SUBSCRIPTIONS?sku=hiair_premium_monthly&package=com.hiair"
        return openUrl(activity, packaged) || openUrl(activity, PLAY_MANAGE_SUBSCRIPTIONS)
    }

    fun openUrl(activity: AppCompatActivity, url: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        if (intent.resolveActivity(activity.packageManager) == null) {
            return false
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
