package com.hiair.ui.family

import org.json.JSONObject

data class FamilyMemberItem(
    val id: String,
    val memberProfileId: String,
    val relation: String,
    val label: String?,
)

object FamilyMembersParser {
    fun parseList(raw: String): List<FamilyMemberItem> {
        val members = JSONObject(raw).optJSONArray("members") ?: return emptyList()
        return buildList {
            for (index in 0 until members.length()) {
                add(parseMember(members.getJSONObject(index)))
            }
        }
    }

    fun parseMember(raw: String): FamilyMemberItem = parseMember(JSONObject(raw))

    private fun parseMember(json: JSONObject): FamilyMemberItem {
        return FamilyMemberItem(
            id = json.optString("id"),
            memberProfileId = json.optString("memberProfileId"),
            relation = json.optString("relation"),
            label = json.optString("label").takeIf { it.isNotBlank() },
        )
    }
}
