package com.hiair.ui.planner

import java.time.Instant
import java.time.ZoneId

enum class ActionTimePreference(val id: String, private val firstHour: Int, private val endHour: Int) {
    ANY("any", 0, 24), MORNING("morning", 6, 12), AFTERNOON("afternoon", 12, 18), EVENING("evening", 18, 24);

    fun bounds(timezone: String, now: Instant = Instant.now()): Pair<String?, String?> {
        if (this == ANY) return null to null
        val zone = runCatching { ZoneId.of(timezone) }.getOrNull() ?: return null to null
        var day = now.atZone(zone).toLocalDate()
        fun end() = (if (endHour == 24) day.plusDays(1).atStartOfDay(zone)
                     else day.atTime(endHour, 0).atZone(zone)).minusSeconds(1)
        if (end().toInstant() < now) day = day.plusDays(1)
        val start = day.atTime(firstHour, 0).atZone(zone)
        val earliest = if (start.toInstant() < now) now.atZone(zone) else start
        return earliest.toOffsetDateTime().toString() to end().toOffsetDateTime().toString()
    }
}
