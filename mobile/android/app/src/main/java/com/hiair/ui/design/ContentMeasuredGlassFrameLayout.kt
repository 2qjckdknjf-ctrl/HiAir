package com.hiair.ui.design

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout

/**
 * Glass navigation shell whose height is driven only by foreground content.
 * Background blur is laid out to exact measured shell bounds and does not
 * participate in wrap-content height calculation.
 */
class ContentMeasuredGlassFrameLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : FrameLayout(context, attrs, defStyleAttr) {
    private var blurView: View? = null
    private var contentView: View? = null

    fun setGlassLayers(blur: View, content: View) {
        removeAllViews()
        blurView = blur
        contentView = content
        addView(blur)
        addView(content)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val content = contentView
        if (content == null) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            return
        }

        val widthMode = MeasureSpec.getMode(widthMeasureSpec)
        val widthSize = MeasureSpec.getSize(widthMeasureSpec)
        val contentWidthSpec = when (widthMode) {
            MeasureSpec.EXACTLY -> MeasureSpec.makeMeasureSpec(widthSize, MeasureSpec.EXACTLY)
            MeasureSpec.AT_MOST -> MeasureSpec.makeMeasureSpec(widthSize, MeasureSpec.AT_MOST)
            else -> MeasureSpec.makeMeasureSpec(widthSize, MeasureSpec.AT_MOST)
        }
        val contentHeightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        content.measure(contentWidthSpec, contentHeightSpec)

        val resolvedWidth = resolveSize(content.measuredWidth, widthMeasureSpec)
        val resolvedHeight = content.measuredHeight.coerceAtLeast(0)

        blurView?.measure(
            MeasureSpec.makeMeasureSpec(resolvedWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(resolvedHeight, MeasureSpec.EXACTLY),
        )

        setMeasuredDimension(resolvedWidth, resolvedHeight)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = right - left
        val height = bottom - top
        blurView?.layout(0, 0, width, height)
        contentView?.layout(0, 0, width, height)
    }
}
