package com.hiair

import android.app.Activity
import android.graphics.Rect
import android.view.View
import android.widget.ScrollView
import androidx.test.platform.app.InstrumentationRegistry
import com.hiair.ui.theme.V2Ui
import org.junit.Assert.assertTrue

object HiAirGeometryTestSupport {
    private const val DEFAULT_TIMEOUT_MS = 8_000L
    private const val POLL_MS = 50L

    data class LayoutBoundsReport(
        val bodyChildCount: Int,
        val bodyWidth: Int,
        val bodyHeight: Int,
        val contentFrameWidth: Int,
        val contentFrameHeight: Int,
        val contentScrollWidth: Int,
        val contentScrollHeight: Int,
        val navShellWidth: Int,
        val navShellHeight: Int,
        val navRowWidth: Int,
        val navRowHeight: Int,
        val titleHeight: Int,
        val rootInnerHeight: Int,
        val contentFrameBounds: Rect,
        val navShellBounds: Rect,
        val scrollable: Boolean,
    ) {
        fun summary(): String = buildString {
            append("bodyChildCount=$bodyChildCount ")
            append("body=${bodyWidth}x$bodyHeight ")
            append("contentFrame=${contentFrameWidth}x$contentFrameHeight ")
            append("contentScroll=${contentScrollWidth}x$contentScrollHeight ")
            append("navShell=${navShellWidth}x$navShellHeight ")
            append("navRow=${navRowWidth}x$navRowHeight ")
            append("titleHeight=$titleHeight rootInnerHeight=$rootInnerHeight ")
            append("contentFrameBounds=$contentFrameBounds navShellBounds=$navShellBounds ")
            append("scrollable=$scrollable")
        }
    }

    enum class LayoutFailureMode {
        NO_BODY_CHILDREN,
        COLLAPSED_VIEWPORT,
        READINESS_CONTRACT,
        OK,
    }

    fun collectLayoutBounds(activity: AppMainActivity): LayoutBoundsReport {
        val root = activity.rootViewForTests()
        val body = activity.bodyContainerForTests()
        val contentFrame = activity.contentFrameForTests()
        val contentScroll = activity.contentScrollForTests()
        val navShell = activity.navShellForTests()
        val navRow = activity.navRowForTests()
        val title = activity.titleViewForTests()
        val contentLoc = IntArray(2)
        val navLoc = IntArray(2)
        contentFrame.getLocationOnScreen(contentLoc)
        navShell.getLocationOnScreen(navLoc)
        val rootInnerHeight = root.height - root.paddingTop - root.paddingBottom
        return LayoutBoundsReport(
            bodyChildCount = body.childCount,
            bodyWidth = body.width,
            bodyHeight = body.height,
            contentFrameWidth = contentFrame.width,
            contentFrameHeight = contentFrame.height,
            contentScrollWidth = contentScroll.width,
            contentScrollHeight = contentScroll.height,
            navShellWidth = navShell.width,
            navShellHeight = navShell.height,
            navRowWidth = navRow.width,
            navRowHeight = navRow.height,
            titleHeight = title.height,
            rootInnerHeight = rootInnerHeight,
            contentFrameBounds = Rect(
                contentLoc[0],
                contentLoc[1],
                contentLoc[0] + contentFrame.width,
                contentLoc[1] + contentFrame.height,
            ),
            navShellBounds = Rect(
                navLoc[0],
                navLoc[1],
                navLoc[0] + navShell.width,
                navLoc[1] + navShell.height,
            ),
            scrollable = body.height > contentScroll.height + dp(activity, 8),
        )
    }

    fun classifyLayoutFailure(report: LayoutBoundsReport): LayoutFailureMode {
        if (report.bodyChildCount <= 0) return LayoutFailureMode.NO_BODY_CHILDREN
        if (report.contentFrameHeight <= 0 ||
            report.contentScrollHeight <= 0 ||
            report.bodyWidth <= 0
        ) {
            return LayoutFailureMode.COLLAPSED_VIEWPORT
        }
        return LayoutFailureMode.OK
    }

    fun assertRootShellLayoutInvariants(
        activity: AppMainActivity,
        expectScrollableBody: Boolean = false,
    ) {
        val report = collectLayoutBounds(activity)
        val failure = classifyLayoutFailure(report)
        assertTrue(
            "layout failure=$failure ${report.summary()}",
            failure == LayoutFailureMode.OK,
        )

        val navPaddingAllowance = dp(activity, 24)
        assertTrue(
            "contentFrame height=${report.contentFrameHeight}",
            report.contentFrameHeight > 0,
        )
        val contentBudget = (report.rootInnerHeight - report.titleHeight - report.navShellHeight)
            .coerceAtLeast(1)
        assertTrue(
            "contentFrame=${report.contentFrameHeight} budget=$contentBudget ${report.summary()}",
            report.contentFrameHeight >= (contentBudget * 0.60f).toInt(),
        )
        assertTrue(
            "navShell=${report.navShellHeight} navRow=${report.navRowHeight}",
            report.navShellHeight in report.navRowHeight..(report.navRowHeight + navPaddingAllowance),
        )
        assertTrue(
            "navShell too tall=${report.navShellHeight} rootInner=${report.rootInnerHeight}",
            report.navShellHeight < (report.rootInnerHeight * 0.25f).toInt(),
        )
        assertTrue(
            "navigation overlaps content ${report.summary()}",
            report.navShellBounds.top >= report.contentFrameBounds.bottom - dp(activity, 2),
        )
        assertTrue(
            "contentScroll collapsed ${report.summary()}",
            report.contentScrollWidth > 0 && report.contentScrollHeight > 0,
        )
        assertTrue("body width collapsed ${report.summary()}", report.bodyWidth > 0)
        if (expectScrollableBody) {
            assertTrue(
                "expected scrollable symptoms body ${report.summary()}",
                report.scrollable,
            )
        }
    }

    fun waitForMarker(activity: Activity, marker: String, timeoutMs: Long = DEFAULT_TIMEOUT_MS): View {
        requireNotMainThread("waitForMarker")
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val deadline = System.currentTimeMillis() + timeoutMs
        var lastWidth = 0
        while (System.currentTimeMillis() < deadline) {
            var found: View? = null
            instrumentation.runOnMainSync {
                found = findByContentDescription(activity.window.decorView, marker)
                lastWidth = found?.width ?: 0
            }
            if (found != null && lastWidth > 0 && found!!.height > 0) {
                instrumentation.waitForIdleSync()
                return found!!
            }
            Thread.sleep(POLL_MS)
        }
        throw AssertionError("Timeout waiting for geometry marker=$marker lastWidth=$lastWidth")
    }

    fun waitForLayout(activity: Activity, view: View, timeoutMs: Long = DEFAULT_TIMEOUT_MS) {
        requireNotMainThread("waitForLayout")
        if (view.width > 0 && view.height > 0) {
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            return
        }
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            var ready = false
            instrumentation.runOnMainSync {
                ready = view.width > 0 && view.height > 0
            }
            if (ready) {
                instrumentation.waitForIdleSync()
                return
            }
            Thread.sleep(POLL_MS)
        }
        throw AssertionError("Timeout waiting for layout w=${view.width} h=${view.height}")
    }

    fun waitForRootShellLayout(activity: AppMainActivity, timeoutMs: Long = DEFAULT_TIMEOUT_MS): LayoutBoundsReport {
        requireNotMainThread("waitForRootShellLayout")
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val deadline = System.currentTimeMillis() + timeoutMs
        var lastReport: LayoutBoundsReport? = null
        while (System.currentTimeMillis() < deadline) {
            instrumentation.runOnMainSync {
                lastReport = collectLayoutBounds(activity)
            }
            val report = lastReport!!
            if (classifyLayoutFailure(report) == LayoutFailureMode.OK && report.contentFrameHeight > 0) {
                instrumentation.waitForIdleSync()
                return report
            }
            Thread.sleep(POLL_MS)
        }
        throw AssertionError(
            "Timeout waiting for root shell layout ${lastReport?.summary() ?: "unknown"}",
        )
    }

    fun assertClearOfNavigation(activity: AppMainActivity, view: View, clearanceDp: Int = 8) {
        val nav = activity.navShellForTests()
        waitForLayout(activity, nav)
        val navLoc = IntArray(2)
        val viewLoc = IntArray(2)
        nav.getLocationOnScreen(navLoc)
        view.getLocationOnScreen(viewLoc)
        val viewBottom = viewLoc[1] + view.height
        val clearancePx = dp(activity, clearanceDp)
        assertTrue(
            "view bottom=$viewBottom navTop=${navLoc[1]} marker=${view.contentDescription}",
            viewBottom <= navLoc[1] - clearancePx,
        )
    }

    fun assertBodyPaddingMeetsNavContract(activity: AppMainActivity) {
        val body = activity.bodyContainerForTests()
        val nav = activity.navShellForTests()
        waitForLayout(activity, body)
        waitForLayout(activity, nav)
        val expected = com.hiair.ui.design.HiAirNavClearance.requiredBottomTailPx(activity, nav)
        assertTrue(
            "body bottom padding=${body.paddingBottom} expected>=$expected",
            body.paddingBottom >= expected - dp(activity, 4),
        )
    }

    fun scrollContentToEnd(activity: AppMainActivity) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        instrumentation.runOnMainSync {
            val scroll = activity.contentScrollForTests()
            scroll.post { scroll.fullScroll(ScrollView.FOCUS_DOWN) }
        }
        instrumentation.waitForIdleSync()
        Thread.sleep(200)
    }

    fun assertWithinContentBounds(
        markerView: View,
        bodyView: View,
        snapshot: com.hiair.ui.design.HiAirWindowLayoutSnapshot,
    ) {
        val markerLoc = IntArray(2)
        val bodyLoc = IntArray(2)
        markerView.getLocationOnScreen(markerLoc)
        bodyView.getLocationOnScreen(bodyLoc)
        val markerLeft = markerLoc[0]
        val markerRight = markerLoc[0] + markerView.width
        val bodyLeft = bodyLoc[0]
        val bodyRight = bodyLoc[0] + bodyView.width
        assertTrue(
            "marker=${markerView.contentDescription} left=$markerLeft bodyLeft=$bodyLeft",
            markerLeft >= bodyLeft - 2,
        )
        assertTrue(
            "marker=${markerView.contentDescription} right=$markerRight bodyRight=$bodyRight",
            markerRight <= bodyRight + 2,
        )
        assertTrue("marker width > 0", markerView.width > 0)
        assertTrue("final content width bound", markerView.width <= snapshot.finalContentWidthPx + 8)
    }

    fun assertMinTouchTargetDp(activity: Activity, view: View, minDp: Int = 48) {
        val density = activity.resources.displayMetrics.density
        val minPx = (minDp * density).toInt()
        assertTrue("touch height ${view.height} >= $minPx", view.height >= minPx - 2)
    }

    private fun dp(activity: Activity, value: Int): Int = V2Ui.dp(activity, value)

    private fun requireNotMainThread(name: String) {
        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
            throw IllegalStateException("$name must not run on the main thread")
        }
    }

    internal fun findByContentDescription(root: View, marker: String): View? {
        if (marker == root.contentDescription) return root
        if (root is android.view.ViewGroup) {
            for (i in 0 until root.childCount) {
                val found = findByContentDescription(root.getChildAt(i), marker)
                if (found != null) return found
            }
        }
        return null
    }
}
