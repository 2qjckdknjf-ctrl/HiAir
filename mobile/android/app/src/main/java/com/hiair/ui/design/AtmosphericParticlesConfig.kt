package com.hiair.ui.design

data class ParticleConfig(
    val count: Int,
    val minOpacity: Float,
    val maxOpacity: Float,
    val speed: Float
)

object AtmosphericParticlesConfig {
    fun forPm25(pm25: Double): ParticleConfig {
        return when {
            pm25 < 15.0 -> ParticleConfig(count = 3, minOpacity = 0.08f, maxOpacity = 0.18f, speed = 0.22f)
            pm25 < 35.0 -> ParticleConfig(count = 5, minOpacity = 0.14f, maxOpacity = 0.28f, speed = 0.18f)
            pm25 < 55.0 -> ParticleConfig(count = 7, minOpacity = 0.20f, maxOpacity = 0.34f, speed = 0.14f)
            else -> ParticleConfig(count = 8, minOpacity = 0.24f, maxOpacity = 0.40f, speed = 0.10f)
        }
    }
}
