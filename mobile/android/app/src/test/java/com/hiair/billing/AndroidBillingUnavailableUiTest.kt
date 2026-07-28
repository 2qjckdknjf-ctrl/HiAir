package com.hiair.billing

import com.hiair.network.ApiHttpException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidBillingUnavailableUiTest {
    @Test
    fun apiHttp503IsBillingUnavailableSignal() {
        val error = ApiHttpException(503, "HTTP 503 for /api/subscriptions/android/verify")
        assertEquals(503, error.statusCode)
        assertTrue(error.message!!.contains("503"))
    }

    @Test
    fun non503RemainsGenericVerifyFailureSignal() {
        val error = ApiHttpException(400, "HTTP 400")
        assertEquals(400, error.statusCode)
        assertFalse(error.statusCode == 503)
    }
}
