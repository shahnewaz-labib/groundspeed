package com.shahnewaz.groundspeed

import android.Manifest
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var locationManager: LocationManager? = null
    private var gnssCallback: GnssStatus.Callback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GNSS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) return

                    if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        events.error("PERMISSION_DENIED", "Fine location permission missing", null)
                        return
                    }

                    val lm = applicationContext
                        .getSystemService(LOCATION_SERVICE) as LocationManager
                    locationManager = lm

                    val callback = object : GnssStatus.Callback() {
                        override fun onSatelliteStatusChanged(status: GnssStatus) {
                            val total = status.satelliteCount
                            var used = 0
                            val sats = ArrayList<Map<String, Any>>(total)
                            for (i in 0 until total) {
                                val inFix = status.usedInFix(i)
                                if (inFix) used++
                                sats.add(
                                    mapOf(
                                        "id" to status.getSvid(i),
                                        "c" to constellationName(status.getConstellationType(i)),
                                        "az" to status.getAzimuthDegrees(i),
                                        "el" to status.getElevationDegrees(i),
                                        "snr" to status.getCn0DbHz(i),
                                        "u" to inFix,
                                    )
                                )
                            }
                            val payload = mapOf(
                                "used" to used,
                                "total" to total,
                                "sats" to sats,
                            )
                            mainHandler.post { events.success(payload) }
                        }
                    }
                    gnssCallback = callback
                    try {
                        @Suppress("DEPRECATION")
                        lm.registerGnssStatusCallback(callback)
                    } catch (_: SecurityException) {
                        events.error("REGISTER_FAILED", "GNSS registration failed", null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unregister()
                }
            })
    }

    private fun constellationName(type: Int): String = when (type) {
        GnssStatus.CONSTELLATION_GPS -> "GPS"
        GnssStatus.CONSTELLATION_GLONASS -> "GLONASS"
        GnssStatus.CONSTELLATION_GALILEO -> "GALILEO"
        GnssStatus.CONSTELLATION_BEIDOU -> "BEIDOU"
        GnssStatus.CONSTELLATION_QZSS -> "QZSS"
        GnssStatus.CONSTELLATION_SBAS -> "SBAS"
        GnssStatus.CONSTELLATION_IRNSS -> "NAVIC"
        else -> "UNKNOWN"
    }

    private fun unregister() {
        val cb = gnssCallback ?: return
        try {
            locationManager?.unregisterGnssStatusCallback(cb)
        } catch (_: Exception) {
            // Receiver already torn down.
        }
        gnssCallback = null
    }

    override fun onDestroy() {
        unregister()
        super.onDestroy()
    }

    companion object {
        const val GNSS_CHANNEL = "groundspeed/gnss"
    }
}
