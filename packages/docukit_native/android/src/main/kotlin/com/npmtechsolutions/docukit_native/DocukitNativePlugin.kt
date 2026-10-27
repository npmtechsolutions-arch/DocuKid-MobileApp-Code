package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
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
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveAs" -> saveAs(call, result)
            "openWith" -> openWith(call, result)
            "freeBytes" -> result.success(StatFs(appContext.filesDir.path).availableBytes)
            "beginBackgroundTask" -> result.success(0) // ADR-009: no foreground service in MVP
            "endBackgroundTask" -> result.success(null)
            "protectOutput" -> result.success(null) // iOS-only concern
            // SPIKE T8.0 (throwaway; debuggable builds only; delete in T8.3).
            "spikeSaveManyToTree" -> spikeSaveManyToTree(call, result)
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
        if (pendingSaveResult != null) {
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
        if (requestCode == REQUEST_SPIKE_TREE) return onSpikeTree(resultCode, data)
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
                    android.provider.DocumentsContract.deleteDocument(appContext.contentResolver, uri)
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

    // ---- SPIKE T8.0 (throwaway; delete in T8.3) -------------------------------
    // Measures saving N files into a folder picked with ACTION_OPEN_DOCUMENT_TREE,
    // once with DocumentFile.createFile and once with DocumentsContract.createDocument.
    // Returns timings only; never names or paths.
    private var spikeResult: MethodChannel.Result? = null
    private var spikePaths: List<String> = emptyList()
    private var spikeMime: String = "image/jpeg"

    private fun spikeSaveManyToTree(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val debuggable = (appContext.applicationInfo.flags and
            android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable || act == null || spikeResult != null) {
            result.success(mapOf("status" to "failed", "code" to "unavailable"))
            return
        }
        spikePaths = call.argument<List<String>>("paths") ?: emptyList()
        spikeMime = call.argument<String>("mime") ?: "image/jpeg"
        spikeResult = result
        act.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), REQUEST_SPIKE_TREE)
    }

    private fun onSpikeTree(resultCode: Int, data: Intent?): Boolean {
        val result = spikeResult ?: return true
        spikeResult = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(mapOf("status" to "cancelled"))
            return true
        }
        io.execute {
            val out = try {
                val resolver = appContext.contentResolver
                val root = androidx.documentfile.provider.DocumentFile.fromTreeUri(appContext, tree)!!
                // A: DocumentFile — subfolder, findFile (collision check) + createFile + copy.
                val t0 = System.nanoTime()
                val dirA = root.createDirectory("spikeA_${System.currentTimeMillis()}")!!
                var createNsA = 0L
                spikePaths.forEachIndexed { i, path ->
                    val name = "file_$i.jpg"
                    val c0 = System.nanoTime()
                    if (dirA.findFile(name) != null) throw IllegalStateException("dup")
                    val doc = dirA.createFile(spikeMime, name)!!
                    createNsA += System.nanoTime() - c0
                    copyToUri(File(path), doc.uri)
                }
                val totalA = System.nanoTime() - t0
                // B: DocumentsContract.createDocument directly (no findFile listing).
                val t1 = System.nanoTime()
                val dirB = root.createDirectory("spikeB_${System.currentTimeMillis()}")!!
                var createNsB = 0L
                spikePaths.forEachIndexed { i, path ->
                    val c0 = System.nanoTime()
                    val uri = android.provider.DocumentsContract.createDocument(
                        resolver, dirB.uri, spikeMime, "file_$i.jpg")!!
                    createNsB += System.nanoTime() - c0
                    copyToUri(File(path), uri)
                }
                val totalB = System.nanoTime() - t1
                val countA = dirA.listFiles().size
                val countB = dirB.listFiles().size
                mapOf(
                    "status" to "ok",
                    "files" to spikePaths.size,
                    "documentFileTotalMs" to totalA / 1_000_000,
                    "documentFileCreateMs" to createNsA / 1_000_000,
                    "documentFileCount" to countA,
                    "contractTotalMs" to totalB / 1_000_000,
                    "contractCreateMs" to createNsB / 1_000_000,
                    "contractCount" to countB,
                )
            } catch (e: Exception) {
                mapOf("status" to "failed", "code" to e.javaClass.simpleName)
            }
            main.post { result.success(out) }
        }
        return true
    }
    // ---- end SPIKE T8.0 --------------------------------------------------------

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
        private const val REQUEST_SPIKE_TREE = 0xD0C8 // SPIKE T8.0
        private const val BUFFER = 64 * 1024
    }
}
