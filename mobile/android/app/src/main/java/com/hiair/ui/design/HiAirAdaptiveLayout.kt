package com.hiair.ui.design

enum class HiAirLayoutMode {
    COMPACT,
    STANDARD,
    TABLET,
    EXPANDED,
}

object HiAirScreenMetrics {
    const val compactMaxDp = 360
    const val mediumMinDp = 600
    const val expandedMinDp = 840
    const val contentCanvasMaxDp = 1080
    const val contentCanvasExpandedDp = 1120
    const val readingColumnMaxDp = 680
    const val ctaMaxWidthDp = 520
    const val navBarMaxWidthDp = 720

    fun layoutMode(widthDp: Int): HiAirLayoutMode {
        return when {
            widthDp >= expandedMinDp -> HiAirLayoutMode.EXPANDED
            widthDp >= mediumMinDp -> HiAirLayoutMode.TABLET
            widthDp < compactMaxDp -> HiAirLayoutMode.COMPACT
            else -> HiAirLayoutMode.STANDARD
        }
    }

    fun contentMaxWidthDp(widthDp: Int): Int {
        return when (layoutMode(widthDp)) {
            HiAirLayoutMode.COMPACT, HiAirLayoutMode.STANDARD -> widthDp
            HiAirLayoutMode.TABLET -> minOf(widthDp - 48, 840)
            HiAirLayoutMode.EXPANDED -> minOf(widthDp - 64, contentCanvasExpandedDp)
        }
    }

    fun gridColumnCount(widthDp: Int, maxColumns: Int = 3): Int {
        return when (layoutMode(widthDp)) {
            HiAirLayoutMode.COMPACT, HiAirLayoutMode.STANDARD -> 1
            HiAirLayoutMode.TABLET -> minOf(2, maxColumns)
            HiAirLayoutMode.EXPANDED -> maxColumns.coerceAtMost(4)
        }
    }

    fun allowsTwoColumn(widthDp: Int): Boolean = widthDp >= mediumMinDp

    fun heroOrbDp(widthDp: Int): Int {
        return when (layoutMode(widthDp)) {
            HiAirLayoutMode.COMPACT -> 260
            HiAirLayoutMode.STANDARD -> 280
            HiAirLayoutMode.TABLET -> 320
            HiAirLayoutMode.EXPANDED -> 360
        }.coerceIn(220, 420)
    }

    fun horizontalPaddingDp(widthDp: Int): Int {
        return when (layoutMode(widthDp)) {
            HiAirLayoutMode.COMPACT -> HiAirSpacing.md
            HiAirLayoutMode.STANDARD -> HiAirSpacing.md + 4
            HiAirLayoutMode.TABLET -> HiAirSpacing.xl
            HiAirLayoutMode.EXPANDED -> HiAirSpacing.xl + 8
        }
    }
}

object HiAirResponsiveSpacing {
    fun cardSpacing(mode: HiAirLayoutMode): Int {
        return when (mode) {
            HiAirLayoutMode.COMPACT -> HiAirSpacing.sm
            HiAirLayoutMode.STANDARD -> HiAirSpacing.md
            HiAirLayoutMode.TABLET -> HiAirSpacing.lg
            HiAirLayoutMode.EXPANDED -> HiAirSpacing.lg
        }
    }
}
