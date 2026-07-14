package com.hiair.location

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.hiair.analytics.ProductAnalytics
import com.hiair.ui.settings.SettingsViewModel

class LocationController(
    private val activity: AppCompatActivity,
    private val settingsViewModel: SettingsViewModel,
) {
    private val fusedClient = LocationServices.getFusedLocationProviderClient(activity)
    private var pendingBootstrap = false

    private val permissionLauncher: ActivityResultLauncher<Array<String>> =
        activity.registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            val granted = result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
            ProductAnalytics.track(
                "location_permission_status",
                mapOf("granted" to granted.toString())
            )
            if (pendingBootstrap) {
                pendingBootstrap = false
                if (granted) {
                    fetchAndApply(onComplete = {})
                }
            }
        }

    fun bootstrapLocation(onComplete: () -> Unit) {
        if (!hasPermission()) {
            pendingBootstrap = true
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                )
            )
            onComplete()
            return
        }
        fetchAndApply(onComplete)
    }

    fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null)
        )
        activity.startActivity(intent)
    }

    private fun hasPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun fetchAndApply(onComplete: () -> Unit) {
        val token = CancellationTokenSource()
        fusedClient.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, token.token)
            .addOnSuccessListener { location ->
                if (location != null && GeoCoordinates.isValid(location)) {
                    val applied = settingsViewModel.applyDeviceLocation(location.latitude, location.longitude)
                    if (applied) {
                        ProductAnalytics.track(
                            "location_fetch_success",
                            mapOf(
                                "source" to LocationSource.DEVICE.raw,
                                "accuracy_bucket" to GeoCoordinates.accuracyBucket(location),
                            )
                        )
                    }
                } else {
                    ProductAnalytics.track("location_fetch_failed", mapOf("reason" to "invalid_coordinate"))
                }
                onComplete()
            }
            .addOnFailureListener {
                ProductAnalytics.track("location_fetch_failed", mapOf("reason" to "error"))
                onComplete()
            }
    }
}
