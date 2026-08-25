package com.hiair.ui.settings

import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsDeletionDetailTest {
    @Test
    fun formatDeletionDetailIncludesOperationIdAndStages() {
        val payload = JSONObject(
            """
            {
              "operation_id": "op-99",
              "stages": {"apple_revoke": "failed", "supabase_delete": "pending"}
            }
            """.trimIndent()
        )
        val detail = SettingsViewModel.formatDeletionDetail(payload)
        assertTrue(detail.contains("operation_id: op-99"))
        assertTrue(detail.contains("apple_revoke: failed"))
    }
}
