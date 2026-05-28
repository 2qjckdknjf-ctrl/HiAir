package com.hiair.ui.design

enum class HiAirLayoutMode {
    COMPACT,
    STANDARD,
    TABLET,
    EXPANDED,
}

object HiAirScreenMetrics {
    const val compactMaxDp = 360
    const val tabletMinDp = 600
    const val expandedMinDp = 840
    const val contentMaxDp = 680

    fun layoutMode(widthDp: Int): HiAirLayoutMode {
        return when {
            widthDp >= expandedMinDp -> HiAirLayoutMode.EXPANDED
            widthDp >= tabletMinDp -> HiAirLayoutMode.TABLET
            widthDp < compactMaxDp -> HiAirLayoutMode.COMPACT
            else -> HiAirLayoutMode.STANDARD
        }
    }

    fun allowsTwoColumn(widthDp: Int): Boolean = widthDp >= tabletMinDp

    fun heroOrbDp(widthDp: Int): Int {
        return when (layoutMode(widthDp)) {
            HiAirLayoutMode.COMPACT -> (widthDp * 0.20f).toInt().coerceAtMost(72)
            HiAirLayoutMode.STANDARD -> (widthDp * 0.22f).toInt().coerceAtMost(96)
            HiAirLayoutMode.TABLET -> (widthDp * 0.16f).toInt().coerceAtMost(140)
            HiAirLayoutMode.EXPANDED -> (widthDp * 0.14f).toInt().coerceAtMost(160)
        }
    }

    fun horizontalPaddingDp(widthDp: Int): Int {
        return when (layoutMode(widthDp)) {
            HiAirLayoutMode.COMPACT -> HiAirSpacing.md
            HiAirLayoutMode.STANDARD -> HiAirSpacing.md
            HiAirLayoutMode.TABLET -> HiAirSpacing.xl
            HiAirLayoutMode.EXPANDED -> HiAirSpacing.xl
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
