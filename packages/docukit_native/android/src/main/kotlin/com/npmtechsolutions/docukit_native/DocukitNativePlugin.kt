package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintJobInfo
import android.print.PrintManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.WindowManager
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
import java.io.FileOutputStream
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
        (appContext as? Application)?.registerActivityLifecycleCallbacks(foreground)
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
        (appContext as? Application)?.unregisterActivityLifecycleCallbacks(foreground)
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
            "batteryState" -> result.success(batteryState())
            "setSecure" -> setSecure(call.argument<Boolean>("on") == true, result)
            "printPdf" -> printPdf(call, result)
            "printingAvailable" -> result.success(true) // the Print Framework is always there on API 26+
            "setPrivacyCover" -> result.success(null) // iOS only; Android uses FLAG_SECURE
            "beginBackgroundTask" -> result.success(0) // ADR-009: no foreground service in MVP
            "endBackgroundTask" -> result.success(null)
            "protectOutput" -> result.success(null) // iOS-only concern
            "saveManyToFolder" -> saveManyToFolder(call, result)
            "openAppSettings" -> openAppSettings(result)
            // FR-SHR-03 cold start: batches that arrived before the engine listened.
            "getIncomingFiles" -> result.success(IncomingFiles.drain())
            // FR-SCN-22 cold start: the shortcut route that started DocuKit.
            "takePendingRoute" -> result.success(PendingRoute.take())
            // 1.5 reminders: the IANA zone for TZDateTime scheduling.
            "deviceTimeZone" -> result.success(java.util.TimeZone.getDefault().id)
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

    /** 1.5 indexing (FR-LIB-16): the sticky ACTION_BATTERY_CHANGED broadcast; no permission needed. */
    private fun batteryState(): Map<String, Any> {
        val i = appContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return mapOf("level" to -1, "charging" to false)
        val level = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val plugged = i.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
        return mapOf("level" to if (level >= 0 && scale > 0) level * 100 / scale else -1, "charging" to plugged)
    }

    /** 1.5 FR-LCK-05: FLAG_SECURE while a locked-scope screen shows (blank in recents, no screenshots). */
    private fun setSecure(on: Boolean, result: MethodChannel.Result) {
        val a = activity ?: return result.success(false)
        a.runOnUiThread {
            if (on) a.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            else a.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            result.success(true)
        }
    }

    /**
     * DocuKit's activities that are started, in this process. The system print
     * dialog runs in the print spooler's process, so 0 while it shows is
     * normal; 0 after the job left the dialog means the user left DocuKit.
     */
    private var startedActivities = 0
    private val foreground = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityStarted(a: Activity) { startedActivities++ }
        override fun onActivityStopped(a: Activity) { if (startedActivities > 0) startedActivities-- }
        override fun onActivityCreated(a: Activity, b: Bundle?) {}
        override fun onActivityResumed(a: Activity) {}
        override fun onActivityPaused(a: Activity) {}
        override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
        override fun onActivityDestroyed(a: Activity) {}
    }

    /**
     * 1.6 Print (RELEASE_PRINT §4.2, ADR-069): hands the PDF at `path` to the
     * system print dialog. The adapter streams the file (8 KB, on [io],
     * honouring cancel) — a path, never bytes over the channel. Answers once:
     * `sent` when the job completes, or once it has left the dialog and the
     * user leaves DocuKit, or after 10 minutes still queued / blocked (a
     * blocked job can resume; R73 documents this); `cancelled`; `failed`.
     * Never "printed": the phone only knows the job was handed over.
     */
    private fun printPdf(call: MethodCall, result: MethodChannel.Result) {
        var answered = false
        fun answer(status: String) {
            if (answered) return
            answered = true
            result.success(mapOf("status" to status))
        }
        val a = activity ?: return answer("failed")
        val path = call.argument<String>("path") ?: return answer("failed")
        if (!File(path).canRead()) return answer("failed")
        val name = call.argument<String>("jobName") ?: "DocuKit"
        val pm = a.getSystemService(Context.PRINT_SERVICE) as PrintManager
        val adapter = object : PrintDocumentAdapter() {
            override fun onLayout(
                oldAttributes: PrintAttributes?, newAttributes: PrintAttributes, cancel: CancellationSignal?,
                callback: LayoutResultCallback, extras: Bundle?,
            ) {
                if (cancel?.isCanceled == true) return callback.onLayoutCancelled()
                val info = PrintDocumentInfo.Builder(name)
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .setPageCount(PrintDocumentInfo.PAGE_COUNT_UNKNOWN)
                    .build()
                // The sheets are fixed: a paper change doesn't change our content.
                callback.onLayoutFinished(info, oldAttributes == null)
            }

            override fun onWrite(
                pages: Array<out PageRange>, destination: ParcelFileDescriptor, cancel: CancellationSignal?,
                callback: WriteResultCallback,
            ) {
                io.execute {
                    try {
                        FileInputStream(path).use { input ->
                            FileOutputStream(destination.fileDescriptor).use { output ->
                                val buf = ByteArray(8 * 1024)
                                while (true) {
                                    if (cancel?.isCanceled == true) {
                                        main.post { callback.onWriteCancelled() }
                                        return@execute
                                    }
                                    val n = input.read(buf)
                                    if (n < 0) break
                                    output.write(buf, 0, n)
                                }
                            }
                        }
                        main.post { callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES)) }
                    } catch (e: Exception) {
                        main.post { callback.onWriteFailed(null) }
                    }
                }
            }
        }
        val job = try {
            pm.print(name, adapter, printAttributes(call))
        } catch (e: Exception) {
            return answer("failed")
        }
        var seconds = 0
        main.postDelayed(object : Runnable {
            override fun run() {
                val state = job.info?.state ?: PrintJobInfo.STATE_FAILED
                val leftDialog = state == PrintJobInfo.STATE_QUEUED || state == PrintJobInfo.STATE_STARTED ||
                    state == PrintJobInfo.STATE_BLOCKED
                val status = when {
                    state == PrintJobInfo.STATE_COMPLETED -> "sent"
                    state == PrintJobInfo.STATE_FAILED -> "failed"
                    state == PrintJobInfo.STATE_CANCELED -> "cancelled"
                    leftDialog && startedActivities == 0 -> "sent"
                    seconds >= 600 -> if (state == PrintJobInfo.STATE_CREATED) "cancelled" else "sent"
                    else -> null
                }
                if (status != null) return answer(status)
                seconds++
                main.postDelayed(this, 1000)
            }
        }, 1000)
    }

    /**
     * Preselects the composed paper: without it the dialog uses its own
     * default (Letter on the T13.0 emulator) and "Save as PDF" rescales our
     * sheets. A size within 1 mm of a predefined one uses it (the printer
     * knows it by name); others — 5 × 7 in, Same as document — are custom.
     */
    private fun printAttributes(call: MethodCall): PrintAttributes? {
        val wPt = call.argument<Double>("widthPt") ?: return null
        val hPt = call.argument<Double>("heightPt") ?: return null
        val w = Math.round(minOf(wPt, hPt) * 1000 / 72).toInt()
        val h = Math.round(maxOf(wPt, hPt) * 1000 / 72).toInt()
        val known = listOf(
            PrintAttributes.MediaSize.ISO_A4, PrintAttributes.MediaSize.ISO_A5,
            PrintAttributes.MediaSize.NA_LETTER, PrintAttributes.MediaSize.NA_LEGAL,
            PrintAttributes.MediaSize.NA_INDEX_4X6,
        ).firstOrNull { Math.abs(it.widthMils - w) <= 40 && Math.abs(it.heightMils - h) <= 40 }
        val media = known ?: if (Math.abs(w - 5000) <= 40 && Math.abs(h - 7000) <= 40) {
            // No predefined 5 × 7 in on Android (there is 5 × 8).
            PrintAttributes.MediaSize("docukit_5x7", "5 × 7 in", 5000, 7000)
        } else {
            val label = "${Math.round(w * 0.0254)} × ${Math.round(h * 0.0254)} mm"
            PrintAttributes.MediaSize("docukit_${w}x$h", label, w, h)
        }
        val landscape = call.argument<Boolean>("landscape") == true
        return PrintAttributes.Builder().setMediaSize(if (landscape) media.asLandscape() else media.asPortrait()).build()
    }
}
