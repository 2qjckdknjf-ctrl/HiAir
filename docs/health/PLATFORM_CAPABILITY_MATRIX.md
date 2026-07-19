# Platform Capability Matrix

| Canonical Metric | HealthKit Type | Health Connect Record | Unit | Aggregation |
|------------------|----------------|-----------------------|------|-------------|
| steps | `stepCount` | `StepsRecord` | count | daily sum |
| distance_walking_running | `distanceWalkingRunning` | `DistanceRecord` | m | daily sum |
| active_energy | `activeEnergyBurned` | `ActiveCaloriesBurnedRecord` | kcal | daily sum |
| basal_energy | `basalEnergyBurned` | `BasalMetabolicRateRecord` / total energy | kcal | daily sum / estimate |
| exercise_minutes | `appleExerciseTime` | `ExerciseSessionRecord` duration | min | daily sum |
| stand_minutes | `appleStandTime` | UNSUPPORTED ON PLATFORM | min | daily sum |
| flights_climbed | `flightsClimbed` | `FloorsClimbedRecord` | count | daily sum |
| workout_count / duration / type | `HKWorkout` | `ExerciseSessionRecord` | — | daily aggregates |
| heart_rate | `heartRate` | `HeartRateRecord` | bpm | avg/min/max (device aggregate) |
| resting_heart_rate | `restingHeartRate` | `RestingHeartRateRecord` | bpm | latest/avg |
| walking_heart_rate_avg | `walkingHeartRateAverage` | UNSUPPORTED ON PLATFORM | bpm | latest |
| hrv_sdnn | `heartRateVariabilitySDNN` | — | ms | avg |
| hrv_rmssd | — | `HeartRateVariabilityRmssdRecord` | ms | avg |
| respiratory_rate | `respiratoryRate` | `RespiratoryRateRecord` | /min | avg/min/max |
| oxygen_saturation | `oxygenSaturation` | `OxygenSaturationRecord` | % | avg/min/max/latest |
| sleep_* | `HKCategoryType.sleepAnalysis` | `SleepSessionRecord` | min | stage mapping |
| body_temperature | `bodyTemperature` | `BodyTemperatureRecord` | °C | latest/avg |
| wrist_temperature | `appleSleepingWristTemperature` | skin temp if available | °C | latest + baseline |
| vo2_max | `vo2Max` | `Vo2MaxRecord` | mL/kg/min | latest |
| mindfulness_minutes | `mindfulSession` | UNSUPPORTED / limited | min | daily sum |
| weight | `bodyMass` | `WeightRecord` | kg | latest (opt-in) |
| height | `height` | `HeightRecord` | cm | latest (opt-in) |
| body_fat | `bodyFatPercentage` | `BodyFatRecord` | % | latest (opt-in) |
| blood_pressure_* | `bloodPressure` | `BloodPressureRecord` | mmHg | opt-in only |
| blood_glucose | `bloodGlucose` | `BloodGlucoseRecord` | mg/dL | opt-in only |

## Sleep stage mapping

| Canonical | HealthKit | Health Connect |
|-----------|-----------|----------------|
| sleep_awake | `.awake` / `.awakeInBed` | `STAGE_TYPE_AWAKE` |
| sleep_core_light | `.asleepCore` / `.asleepUnspecified` | `STAGE_TYPE_LIGHT` / unknown asleep |
| sleep_deep | `.asleepDeep` | `STAGE_TYPE_DEEP` |
| sleep_rem | `.asleepREM` | `STAGE_TYPE_REM` |
| sleep_total | sum of asleep stages | sum of asleep stages |
| sleep_in_bed | inBed / session span | session start–end |

Absence of stages is **not** an error — store total only with `quality_state=partial`.
