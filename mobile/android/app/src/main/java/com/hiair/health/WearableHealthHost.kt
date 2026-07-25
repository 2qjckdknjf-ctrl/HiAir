package com.hiair.health

/** Host activity exposes wearable connect/sync/revoke to screen renderers. */
interface WearableHealthHost {
    fun requestWearableConnect(onComplete: () -> Unit)
    fun syncWearablesIfPermitted()
    fun revokeWearablesLocalFirst(deleteData: Boolean = false, onComplete: (remoteCleanupSucceeded: Boolean) -> Unit)
}
