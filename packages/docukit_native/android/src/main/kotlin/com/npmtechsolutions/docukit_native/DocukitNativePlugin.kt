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
    private lateinit var routes: EventChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private lateinit var scanner: DocumentScan
    private lateinit var security: PdfSecurityNative

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSavePath: String? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        scanner = DocumentScan(appContext, io, main)
        security = PdfSecurityNative(appContext, io, main)
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
        // FR-SCN-22 warm start: a launcher shortcut while DocuKit runs (ADR-065).
        routes = EventChannel(flutterPluginBinding.binaryMessenger, "docukit/routes")
        routes.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                PendingRoute.setListener { route -> main.post { events.success(route) } }
            }

            override fun onCancel(arguments: Any?) = PendingRoute.setListener(null)
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        incoming.setStreamHandler(null)
        IncomingFiles.setListener(null)
        routes.setStreamHandler(null)
        PendingRoute.setListener(null)
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
            "openAppSettings" -> openAppSettings(result)
            // FR-SHR-03 cold start: batches that arrived before the engine listened.
            "getIncomingFiles" -> result.success(IncomingFiles.drain())
            // FR-SCN-22 cold start: the shortcut route that started DocuKit.
            "takePendingRoute" -> result.success(PendingRoute.take())
            // Scan Document (RELEASE_V1_2 §4.3).
            "scanAvailability" -> scanner.availability(result)
            "prepareScanner" -> scanner.prepare(result)
            "scanDocument" -> scanner.scan(activity, call, result)
            "takeRestoredScan" -> scanner.takeRestored(result)
            "debugSetScanOverride" -> scanner.debugSetOverride(call, result)
            // Protect / Unlock PDF (RELEASE_V1_4 §4.6). Arguments are never logged.
            "protectPdf" -> security.protect(call, result)
            "unlockPdf" -> security.unlock(call, result)
            "pdfProtection" -> security.protection(call, result)
            else -> result.notImplemented()
        }
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        val intent = Intent(
            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", appContext.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        result.success(
            try {
                appContext.startActivity(intent)
                true
            } catch (e: ActivityNotFoundException) {
                false
            }
        )
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
        if (requestCode == DocumentScan.REQUEST_SCAN) return scanner.onActivityResult(resultCode, data)
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

    companion object {
        private const val REQUEST_SAVE = 0xD0C1
        private const val REQUEST_SAVE_MANY = 0xD0C2
        private const val BUFFER = 64 * 1024
    }
}
