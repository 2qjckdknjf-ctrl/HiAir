package com.hiair.ui.design

import android.view.View

fun <T : View> T.markGeometry(marker: String): T {
    contentDescription = marker
    return this
}
