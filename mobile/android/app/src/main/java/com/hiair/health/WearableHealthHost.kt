package com.hiair.health

/** Host activity exposes wearable connect/sync to screen renderers. */
interface WearableHealthHost {
    fun requestWearableConnect(onComplete: () -> Unit)
    fun syncWearablesIfPermitted()
}
