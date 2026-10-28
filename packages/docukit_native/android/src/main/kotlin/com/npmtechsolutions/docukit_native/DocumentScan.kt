package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executor

/**
 * Scan Document on Android (RELEASE_V1_2 §4.3, ADR-041): the ML Kit document
 * scanner in full mode, JPEG pages only (ADR-042), copied into the job folder.
 * Results that arrive after Android killed the app are kept for Dart to take
 * (FR-SCN-20). Never logs names or paths.
 */
internal class DocumentScan(
    private val appContext: Context,
    private val io: Executor,
    private val main: Handler,
) {
    private var pendingScan: MethodChannel.Result? = null
    private val pendingPrepare = mutableListOf<MethodChannel.Result>()
    private var prepareListener: InstallStatusListener? = null

    /** Debug builds only: pretend this status (e.g. "noPlayServices"). */
    private var override: String? = null

    private val prefs get() = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun debuggable() = (appContext.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun hasPlayServices() =
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(appContext) == ConnectionResult.SUCCESS

    private fun online(): Boolean {
        val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun client(maxPages: Int, gallery: Boolean) = GmsDocumentScanning.getClient(
        GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .setGalleryImportAllowed(gallery)
            .setPageLimit(maxPages)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .build()
    )

    fun debugSetOverride(call: MethodCall, result: MethodChannel.Result) {
        if (debuggable()) override = call.argument<String>("status")
        result.success(null)
    }

    /** ready | needsDownload | noPlayServices */
    fun availability(result: MethodChannel.Result) {
        override?.let { forced ->
            val status = if (forced in AVAILABILITY) forced else "ready"
            return result.success(mapOf("status" to status))
        }
        if (!hasPlayServices()) return result.success(mapOf("status" to "noPlayServices"))
        ModuleInstall.getClient(appContext)
            .areModulesAvailable(client(MAX_PAGES, true))
            .addOnSuccessListener { r ->
                result.success(mapOf("status" to if (r.areModulesAvailable()) "ready" else "needsDownload"))
            }
            .addOnFailureListener { result.success(mapOf("status" to "needsDownload")) }
    }

    /**
     * Asks Play services for the scanner module and answers when it is
     * installed (ready) or fails (offline / failed). Offline answers at once
     * but leaves the request queued. Dart applies the 60 s limit (FR-SCN-07).
     */
    fun prepare(result: MethodChannel.Result) {
        if (override != null) return result.success(mapOf("status" to "ready"))
        if (!hasPlayServices()) return result.success(mapOf("status" to "failed"))
        val isOnline = online()
        if (isOnline) pendingPrepare.add(result)
        if (prepareListener == null) {
            val install = ModuleInstall.getClient(appContext)
            val listener = InstallStatusListener { update ->
                when (update.installState) {
                    ModuleInstallStatusUpdate.InstallState.STATE_COMPLETED -> finishPrepare("ready")
                    ModuleInstallStatusUpdate.InstallState.STATE_FAILED,
                    ModuleInstallStatusUpdate.InstallState.STATE_CANCELED ->
                        finishPrepare(if (online()) "failed" else "offline")
                }
            }
            prepareListener = listener
            val request = ModuleInstallRequest.newBuilder()
                .addApi(client(MAX_PAGES, true))
                .setListener(listener)
                .build()
            install.installModules(request)
                .addOnSuccessListener { r -> if (r.areModulesAlreadyInstalled()) finishPrepare("ready") }
                .addOnFailureListener { finishPrepare(if (online()) "failed" else "offline") }
        }
        if (!isOnline) result.success(mapOf("status" to "offline"))
    }

    private fun finishPrepare(status: String) {
        main.post {
            prepareListener?.let { ModuleInstall.getClient(appContext).unregisterListener(it) }
            prepareListener = null
            val waiting = pendingPrepare.toList()
            pendingPrepare.clear()
            waiting.forEach { it.success(mapOf("status" to status)) }
        }
    }

    fun scan(activity: Activity?, call: MethodCall, result: MethodChannel.Result) {
        val destDir = call.argument<String>("destDir")
        val maxPages = (call.argument<Int>("maxPages") ?: MAX_PAGES).coerceIn(1, MAX_PAGES)
        val gallery = call.argument<Boolean>("allowGalleryImport") ?: true
        if (activity == null || destDir == null || pendingScan != null) return result.success(failed("unknown"))
        override?.let { forced ->
            if (forced == "cancelled") return result.success(mapOf("status" to "cancelled"))
            if (forced in ERROR_CODES) return result.success(failed(forced))
        }
        if (!hasPlayServices()) return result.success(failed("noPlayServices"))
        pendingScan = result
        // Kept until the result arrives, so it can still be handled after process death.
        prefs.edit().putString(KEY_DEST, destDir).apply()
        client(maxPages, gallery).getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                try {
                    activity.startIntentSenderForResult(sender, REQUEST_SCAN, null, 0, 0, 0)
                } catch (e: Exception) {
                    endScan(failed("unknown"))
                }
            }
            .addOnFailureListener { e ->
                val code = when {
                    (e as? MlKitException)?.errorCode != MlKitException.UNAVAILABLE -> "unknown"
                    online() -> "moduleUnavailable"
                    else -> "offline"
                }
                endScan(failed(code))
            }
    }

    private fun endScan(outcome: Map<String, Any>) {
        prefs.edit().remove(KEY_DEST).apply()
        val r = pendingScan
        pendingScan = null
        r?.success(outcome)
    }

    /** The scanner's activity result; also arrives after process death. */
    fun onActivityResult(resultCode: Int, data: Intent?): Boolean {
        val destDir = prefs.getString(KEY_DEST, null)
        val waiting = pendingScan
        pendingScan = null
        prefs.edit().remove(KEY_DEST).apply()
        val deliver: (Map<String, Any>) -> Unit = { outcome ->
            if (waiting != null) {
                waiting.success(outcome)
            } else if (destDir != null) {
                restored = mapOf("destDir" to destDir, "result" to outcome)
            }
        }
        val scan = if (resultCode == Activity.RESULT_OK) GmsDocumentScanningResult.fromActivityResultIntent(data) else null
        val pages = scan?.pages.orEmpty()
        if (scan == null || destDir == null || pages.isEmpty()) {
            deliver(if (resultCode == Activity.RESULT_OK && destDir == null) failed("unknown") else mapOf("status" to "cancelled"))
            return true
        }
        io.execute {
            val outcome = copyPages(pages.map { it.imageUri }, File(destDir))
            main.post { deliver(outcome) }
        }
        return true
    }

    /** Copies each page to destDir/page_###.jpg, numbered after the pages already there. */
    private fun copyPages(uris: List<android.net.Uri>, dir: File): Map<String, Any> {
        val written = mutableListOf<File>()
        return try {
            dir.mkdirs()
            var next = (dir.list().orEmpty().mapNotNull { PAGE_NAME.matchEntire(it)?.groupValues?.get(1)?.toIntOrNull() }
                .maxOrNull() ?: 0) + 1
            for (uri in uris) {
                val out = File(dir, "page_%03d.jpg".format(next++))
                val input = appContext.contentResolver.openInputStream(uri) ?: throw IllegalStateException("no stream")
                input.use { src -> out.outputStream().use { src.copyTo(it, BUFFER) } }
                written.add(out)
            }
            mapOf("status" to "completed", "pagePaths" to written.map { it.path })
        } catch (e: Exception) {
            written.forEach { it.delete() }
            failed(if (e is IOException) "storage" else "unknown")
        }
    }

    fun takeRestored(result: MethodChannel.Result) {
        result.success(restored)
        restored = null
    }

    private fun failed(code: String) = mapOf("status" to "failed", "errorCode" to code)

    companion object {
        const val REQUEST_SCAN = 0xD0C3
        private const val MAX_PAGES = 50
        private const val BUFFER = 64 * 1024
        private const val PREFS = "docukit_native_scan"
        private const val KEY_DEST = "dest_dir"
        private val PAGE_NAME = Regex("page_(\\d+)\\.jpg")
        private val AVAILABILITY = setOf("ready", "needsDownload", "noPlayServices", "unsupported", "cameraDenied")
        private val ERROR_CODES = setOf("moduleUnavailable", "offline", "noPlayServices", "unsupported", "cameraDenied", "storage", "unknown")

        /** A result received with nobody waiting (the app was restarted). */
        @Volatile
        private var restored: Map<String, Any>? = null
    }
}
