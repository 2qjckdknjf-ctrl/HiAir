package com.hiair.ui.render

import android.graphics.Typeface
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import com.hiair.StoreScreenshotMode
import com.hiair.StoreScreenshotMockSeeder
import com.hiair.ui.design.HiAirColors
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.symptoms.SymptomCategory
import com.hiair.ui.symptoms.SymptomLogState
import com.hiair.ui.theme.V2Ui

internal object SymptomsScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val bodyContainer = ctx.bodyContainer

