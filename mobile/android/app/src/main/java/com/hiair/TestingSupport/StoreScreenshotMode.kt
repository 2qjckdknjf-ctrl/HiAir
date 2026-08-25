package com.hiair

/** DEBUG-only gate for deterministic store screenshot / instrumentation state. */
object StoreScreenshotMode {
    @Volatile
    var active: Boolean = false
        private set

    @Volatile
    var targetScreen: String? = null
        private set

    @Volatile
    var captureRunId: String? = null
        private set

    fun activate(screen: String?, runId: String?) {
        if (!BuildConfig.DEBUG) return
        active = true
        targetScreen = screen?.lowercase()
        captureRunId = runId?.takeIf { it.isNotBlank() }
    }

    fun deactivate() {
        active = false
        targetScreen = null
        captureRunId = null
    }
}
