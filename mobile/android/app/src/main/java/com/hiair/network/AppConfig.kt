package com.hiair.network

import com.hiair.BuildConfig

object AppConfig {
    val apiBaseUrl: String = BuildConfig.API_BASE_URL
    val supabaseUrl: String = BuildConfig.SUPABASE_URL
    val supabaseAnonKey: String = BuildConfig.SUPABASE_ANON_KEY
    val supabaseRedirectUri: String = BuildConfig.SUPABASE_REDIRECT_URI
}
