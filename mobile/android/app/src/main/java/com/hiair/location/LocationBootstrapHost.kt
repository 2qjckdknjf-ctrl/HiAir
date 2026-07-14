package com.hiair.location

fun interface LocationBootstrapHost {
    fun bootstrapLocation(onComplete: () -> Unit)
}
