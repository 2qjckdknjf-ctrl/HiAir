package com.hiair.ui.design

import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.format.FormatStyle
import java.util.Locale

/** Locale-aware date/time formatting for UI. Never surface raw ISO-8601 to users. */
object HiAirHumanDate {
    enum class Style {
        DATE,
        TIME,
        DATE_TIME,
        DATE_MEDIUM,
    }

    private val fractionalInstant: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX")

    fun parseIso(iso: String): Instant? {
        val trimmed = iso.trim()
        if (trimmed.isEmpty()) return null
        return try {
            Instant.parse(trimmed)
        } catch (_: DateTimeParseException) {
            try {
                ZonedDateTime.parse(trimmed).toInstant()
            } catch (_: DateTimeParseException) {
                try {
                    LocalDateTime.parse(trimmed).atZone(ZoneId.of("UTC")).toInstant()
                } catch (_: DateTimeParseException) {
                    try {
                        ZonedDateTime.parse(trimmed, fractionalInstant).toInstant()
                    } catch (_: DateTimeParseException) {
                        null
                    }
                }
            }
        }
    }

    fun format(
        instant: Instant,
        locale: Locale = Locale.getDefault(),
        style: Style = Style.DATE_TIME,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): String {
        val zoned = instant.atZone(zoneId)
        val formatter = when (style) {
            Style.DATE -> DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT).withLocale(locale)
            Style.TIME -> DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale)
            Style.DATE_TIME -> DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT, FormatStyle.SHORT)
                .withLocale(locale)
            Style.DATE_MEDIUM -> DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)
        }
        return formatter.format(zoned)
    }

    fun formatIso(
        iso: String,
        locale: Locale = Locale.getDefault(),
        style: Style = Style.DATE_TIME,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): String? {
        val instant = parseIso(iso) ?: return null
        return format(instant, locale, style, zoneId)
    }

    /** Prefer human string; if ISO cannot be parsed, return a non-ISO fallback (never the raw ISO). */
    fun display(
        iso: String,
        locale: Locale = Locale.getDefault(),
        style: Style = Style.DATE_TIME,
        unavailable: String = "—",
    ): String = formatIso(iso, locale, style) ?: unavailable

    /** Compact range for planner windows, e.g. "08:00–09:00". */
    fun timeRange(
        start: Instant,
        end: Instant,
        locale: Locale = Locale.getDefault(),
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): String {
        val startText = format(start, locale, Style.TIME, zoneId)
        val endText = format(end, locale, Style.TIME, zoneId)
        return "$startText–$endText"
    }

    fun timeRangeIso(
        startIso: String,
        endIso: String,
        locale: Locale = Locale.getDefault(),
        unavailable: String = "—",
    ): String {
        val start = parseIso(startIso) ?: return unavailable
        val end = parseIso(endIso) ?: return unavailable
        return timeRange(start, end, locale)
    }
}
