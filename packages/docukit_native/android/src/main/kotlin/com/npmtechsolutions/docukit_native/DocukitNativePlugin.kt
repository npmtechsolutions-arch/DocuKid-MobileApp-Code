package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

/**
 * DocuKit native bridge (ARCHITECTURE §6.4). Streams from file paths; never
 * moves file bytes over the platform channel. Never logs names or paths.
 */
class DocukitNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var incoming: EventChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSavePath: String? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "docukit/native")
        channel.setMethodCallHandler(this)
        // FR-SHR-03 warm start: files that arrive while DocuKit runs.
        incoming = EventChannel(flutterPluginBinding.binaryMessenger, "docukit/incoming")
        incoming.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                IncomingFiles.setListener { batch -> main.post { events.success(batch) } }
            }

            override fun onCancel(arguments: Any?) = IncomingFiles.setListener(null)
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        incoming.setStreamHandler(null)
        IncomingFiles.setListener(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveAs" -> saveAs(call, result)
            "openWith" -> openWith(call, result)
            "freeBytes" -> result.success(StatFs(appContext.filesDir.path).availableBytes)
            "beginBackgroundTask" -> result.success(0) // ADR-009: no foreground service in MVP
            "endBackgroundTask" -> result.success(null)
            "protectOutput" -> result.success(null) // iOS-only concern
            "saveManyToFolder" -> saveManyToFolder(call, result)
            // FR-SHR-03 cold start: batches that arrived before the engine listened.
            "getIncomingFiles" -> result.success(IncomingFiles.drain())
            // SPIKE T9.0 (throwaway; debuggable builds only; delete in T9.1).
            "spikeScanAvailability" -> spikeScanAvailability(result)
            "spikeScan" -> spikeScan(call, result)
            "spikeScanInstall" -> spikeScanInstall(result)
            else -> result.notImplemented()
        }
    }

    private fun saveAs(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val path = call.argument<String>("path")
        if (act == null || path == null) {
            result.success(mapOf("status" to "failed", "code" to "no_activity"))
            return
        }
        if (pendingSaveResult != null || pendingMany != null) {
            result.success(mapOf("status" to "failed", "code" to "busy"))
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mime") ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: File(path).name)
        }
        pendingSaveResult = result
        pendingSavePath = path
        try {
            act.startActivityForResult(intent, REQUEST_SAVE)
        } catch (e: ActivityNotFoundException) {
            pendingSaveResult = null
            pendingSavePath = null
            result.success(mapOf("status" to "failed", "code" to "no_picker"))
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_SAVE_MANY) return onSaveMany(resultCode, data)
        if (requestCode == REQUEST_SPIKE_SCAN) return onSpikeScan(resultCode, data)
        if (requestCode != REQUEST_SAVE) return false
        val result = pendingSaveResult ?: return true
        val path = pendingSavePath
        pendingSaveResult = null
        pendingSavePath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            result.success(mapOf("status" to "cancelled"))
            return true
        }
        io.execute {
            val outcome = try {
                copyToUri(File(path), uri)
                mapOf("status" to "saved", "name" to displayName(uri))
            } catch (e: Exception) {
                // Remove the empty document the picker created, best effort.
                try {
                    DocumentsContract.deleteDocument(appContext.contentResolver, uri)
                } catch (_: Exception) {
                }
                mapOf("status" to "failed", "code" to "write_failed")
            }
            main.post { result.success(outcome) }
        }
        return true
    }

    private fun copyToUri(src: File, uri: Uri) {
        val resolver = appContext.contentResolver
        FileInputStream(src).use { input ->
            val out = resolver.openOutputStream(uri, "wt") ?: throw IllegalStateException("no stream")
            out.use { output ->
                val buffer = ByteArray(BUFFER)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    output.write(buffer, 0, n)
                }
                output.flush()
            }
        }
    }

    private fun displayName(uri: Uri): String? = try {
        appContext.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (_: Exception) {
        null
    }

    private fun openWith(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val path = call.argument<String>("path")
        val mime = call.argument<String>("mime") ?: "*/*"
        if (act == null || path == null) {
            result.success(false)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(act, "${act.packageName}.docukit.fileprovider", File(path))
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (view.resolveActivity(act.packageManager) == null) {
                result.success(false)
                return
            }
            val chooser = Intent.createChooser(view, null).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            act.startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // ---- Save many (FR-BAT-02, ADR-060) -------------------------------------
    // The user picks a folder once (one-time grant; no persisted permission).
    // Each file is created with DocumentsContract.createDocument (the provider
    // adds " (1)" on a clash, so there's no findFile scan) and stream-copied.

    private var pendingMany: MethodChannel.Result? = null
    private var pendingManyItems: List<Map<String, String>> = emptyList()

    private fun saveManyToFolder(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val items = call.argument<List<Map<String, String>>>("items")
        if (act == null || items.isNullOrEmpty()) {
            result.success(mapOf("status" to "failed", "code" to "no_activity"))
            return
        }
        if (pendingSaveResult != null || pendingMany != null) {
            result.success(mapOf("status" to "failed", "code" to "busy"))
            return
        }
        pendingMany = result
        pendingManyItems = items
        try {
            act.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), REQUEST_SAVE_MANY)
        } catch (e: ActivityNotFoundException) {
            pendingMany = null
            pendingManyItems = emptyList()
            result.success(mapOf("status" to "failed", "code" to "no_picker"))
        }
    }

    private fun onSaveMany(resultCode: Int, data: Intent?): Boolean {
        val result = pendingMany ?: return true
        val items = pendingManyItems
        pendingMany = null
        pendingManyItems = emptyList()
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(mapOf("status" to "cancelled"))
            return true
        }
        io.execute {
            val outcome = try {
                val resolver = appContext.contentResolver
                val folder = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                var saved = 0
                val failed = mutableListOf<Int>()
                for ((index, item) in items.withIndex()) {
                    var created: Uri? = null
                    try {
                        val path = item["path"] ?: throw IllegalArgumentException()
                        created = DocumentsContract.createDocument(
                            resolver, folder, item["mime"] ?: "application/octet-stream", item["name"] ?: File(path).name,
                        ) ?: throw IllegalStateException()
                        copyToUri(File(path), created)
                        saved++
                    } catch (e: Exception) {
                        failed.add(index)
                        // Never leave an empty or half-written file behind.
                        created?.let {
                            try {
                                DocumentsContract.deleteDocument(resolver, it)
                            } catch (_: Exception) {
                            }
                        }
                    }
                }
                mapOf(
                    "status" to "saved",
                    "savedCount" to saved,
                    "failedCount" to failed.size,
                    "failedIndexes" to failed,
                    "folderName" to displayName(folder),
                )
            } catch (e: Exception) {
                mapOf("status" to "failed", "code" to "write_failed")
            }
            main.post { result.success(outcome) }
        }
        return true
    }


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    // ---- SPIKE T9.0 (throwaway; delete in T9.1) -------------------------------
    // Launches the ML Kit document scanner (full mode, JPEG, gallery import) and
    // copies the pages into destDir. Returns counts, timings and error codes only.
    private var spikeScanResult: MethodChannel.Result? = null
    private var spikeScanDir: String? = null
    private var spikeScanStarted = 0L

    private fun spikeDebuggable() = (appContext.applicationInfo.flags and
        android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun spikeOnline(): Boolean {
        val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun spikeScanAvailability(result: MethodChannel.Result) {
        if (!spikeDebuggable()) return result.success(mapOf("status" to "failed", "code" to "unavailable"))
        val gms = com.google.android.gms.common.GoogleApiAvailability.getInstance()
        val code = gms.isGooglePlayServicesAvailable(appContext)
        val gmsVersion = try {
            appContext.packageManager.getPackageInfo("com.google.android.gms", 0).longVersionCode
        } catch (_: Exception) { -1L }
        val base = mapOf(
            "gmsStatus" to code,
            "gmsSuccess" to (code == com.google.android.gms.common.ConnectionResult.SUCCESS),
            "gmsVersion" to gmsVersion,
            "online" to spikeOnline(),
        )
        val scanner = com.google.mlkit.vision.documentscanner.GmsDocumentScanning.getClient(spikeOptions(5, true))
        val started = System.currentTimeMillis()
        com.google.android.gms.common.moduleinstall.ModuleInstall.getClient(appContext)
            .areModulesAvailable(scanner)
            .addOnSuccessListener { r ->
                result.success(base + mapOf("moduleAvailable" to r.areModulesAvailable(),
                    "ms" to (System.currentTimeMillis() - started)))
            }
            .addOnFailureListener { e ->
                result.success(base + mapOf("moduleError" to e.javaClass.simpleName,
                    "moduleCode" to ((e as? com.google.android.gms.common.api.ApiException)?.statusCode ?: -1)))
            }
    }

    private fun spikeScanInstall(result: MethodChannel.Result) {
        if (!spikeDebuggable()) return result.success(mapOf("status" to "failed", "code" to "unavailable"))
        val scanner = com.google.mlkit.vision.documentscanner.GmsDocumentScanning.getClient(spikeOptions(5, true))
        val started = System.currentTimeMillis()
        val request = com.google.android.gms.common.moduleinstall.ModuleInstallRequest.newBuilder()
            .addApi(scanner)
            .build()
        com.google.android.gms.common.moduleinstall.ModuleInstall.getClient(appContext)
            .installModules(request)
            .addOnSuccessListener { r ->
                result.success(mapOf("alreadyInstalled" to r.areModulesAlreadyInstalled(),
                    "sessionId" to r.sessionId, "online" to spikeOnline(),
                    "ms" to (System.currentTimeMillis() - started)))
            }
            .addOnFailureListener { e ->
                result.success(mapOf("installError" to e.javaClass.simpleName,
                    "code" to ((e as? com.google.android.gms.common.api.ApiException)?.statusCode ?: -1),
                    "online" to spikeOnline(), "ms" to (System.currentTimeMillis() - started)))
            }
    }

    private fun spikeOptions(limit: Int, gallery: Boolean) =
        com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.Builder()
            .setScannerMode(com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .setGalleryImportAllowed(gallery)
            .setPageLimit(limit)
            .setResultFormats(com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .build()

    private fun spikeScan(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val dir = call.argument<String>("destDir")
        if (!spikeDebuggable() || act == null || dir == null || spikeScanResult != null) {
            return result.success(mapOf("status" to "failed", "code" to "unavailable"))
        }
        val scanner = com.google.mlkit.vision.documentscanner.GmsDocumentScanning.getClient(
            spikeOptions(call.argument<Int>("pageLimit") ?: 5, true))
        spikeScanResult = result
        spikeScanDir = dir
        spikeScanStarted = System.currentTimeMillis()
        val online = spikeOnline()
        scanner.getStartScanIntent(act)
            .addOnSuccessListener { sender ->
                try {
                    act.startIntentSenderForResult(sender, REQUEST_SPIKE_SCAN, null, 0, 0, 0)
                } catch (e: Exception) {
                    spikeScanResult = null
                    result.success(mapOf("status" to "failed", "code" to "launch_" + e.javaClass.simpleName))
                }
            }
            .addOnFailureListener { e ->
                spikeScanResult = null
                result.success(mapOf(
                    "status" to "failed",
                    "error" to e.javaClass.name,
                    "mlkitCode" to ((e as? com.google.mlkit.common.MlKitException)?.errorCode ?: -1),
                    "online" to online,
                    "ms" to (System.currentTimeMillis() - spikeScanStarted),
                ))
            }
    }

    private fun onSpikeScan(resultCode: Int, data: Intent?): Boolean {
        val result = spikeScanResult ?: return true
        val dir = spikeScanDir
        spikeScanResult = null
        spikeScanDir = null
        val uiMs = System.currentTimeMillis() - spikeScanStarted
        val scan = com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult.fromActivityResultIntent(data)
        if (resultCode != Activity.RESULT_OK || scan == null || dir == null) {
            result.success(mapOf("status" to "cancelled", "resultCode" to resultCode, "uiMs" to uiMs))
            return true
        }
        io.execute {
            val copyStart = System.currentTimeMillis()
            val sizes = mutableListOf<Long>()
            val outcome = try {
                File(dir).mkdirs()
                for ((i, page) in (scan.pages ?: emptyList()).withIndex()) {
                    val out = File(dir, "page_%03d.jpg".format(i + 1))
                    appContext.contentResolver.openInputStream(page.imageUri)!!.use { input ->
                        out.outputStream().use { input.copyTo(it, BUFFER) }
                    }
                    sizes.add(out.length())
                }
                mapOf("status" to "completed", "pages" to sizes.size, "bytes" to sizes,
                    "hasPdf" to (scan.pdf != null), "uiMs" to uiMs,
                    "copyMs" to (System.currentTimeMillis() - copyStart))
            } catch (e: Exception) {
                mapOf("status" to "failed", "code" to "copy_" + e.javaClass.simpleName)
            }
            main.post { result.success(outcome) }
        }
        return true
    }

    companion object {
        private const val REQUEST_SAVE = 0xD0C1
        private const val REQUEST_SAVE_MANY = 0xD0C2
        private const val REQUEST_SPIKE_SCAN = 0xD0C9 // SPIKE T9.0
        private const val BUFFER = 64 * 1024
    }
}
