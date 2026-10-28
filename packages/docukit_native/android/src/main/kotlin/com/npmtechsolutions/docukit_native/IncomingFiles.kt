package com.npmtechsolutions.docukit_native

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import java.io.File
import java.util.UUID

/**
 * Files shared or "opened with" DocuKit (FR-SHR-01/04), copied while the
 * sender's read grant is still valid, then queued in-process until the
 * Flutter side takes them. Never logs names or paths.
 */
object IncomingFiles {
    /** More than 50 images + 20 PDFs is never kept (FR-SHR-06); Dart applies the per-kind caps. */
    const val MAX_FILES = 70

    private val pending = mutableListOf<Map<String, Any?>>()
    private var listener: ((Map<String, Any?>) -> Unit)? = null

    @Synchronized
    fun setListener(l: ((Map<String, Any?>) -> Unit)?) {
        listener = l
    }

    /** Delivers a batch to the running engine, or keeps it for [drain] (cold start). */
    @Synchronized
    fun post(batch: Map<String, Any?>) {
        val l = listener
        if (l != null) l(batch) else pending.add(batch)
    }

    @Synchronized
    fun drain(): List<Map<String, Any?>> {
        val out = pending.toList()
        pending.clear()
        return out
    }

    fun urisOf(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        val out = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> stream(intent)?.let { out.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> out.addAll(streams(intent))
            Intent.ACTION_VIEW -> intent.data?.let { out.add(it) }
        }
        if (out.isEmpty()) out.addAll(clip(intent.clipData))
        return out.distinct()
    }

    @Suppress("DEPRECATION")
    private fun stream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)) ?: emptyList()

    private fun clip(c: ClipData?): List<Uri> = if (c == null) emptyList() else (0 until c.itemCount).mapNotNull { c.getItemAt(it).uri }

    /** Copies up to [MAX_FILES] into cacheDir/incoming/<uuid>/ (64 KB stream copy). */
    fun copy(ctx: Context, uris: List<Uri>): Map<String, Any?> {
        val dir = File(ctx.cacheDir, "incoming/${UUID.randomUUID()}").apply { mkdirs() }
        val files = mutableListOf<Map<String, String>>()
        val used = mutableSetOf<String>()
        var failed = 0
        for ((i, uri) in uris.take(MAX_FILES).withIndex()) {
            try {
                val name = unique(safeName(displayName(ctx, uri) ?: "file_${i + 1}"), used)
                val out = File(dir, name)
                val input = ctx.contentResolver.openInputStream(uri) ?: throw IllegalStateException()
                input.use { src -> out.outputStream().use { dst -> src.copyTo(dst, 64 * 1024) } }
                files.add(mapOf("path" to out.absolutePath, "name" to name))
            } catch (e: Exception) {
                failed++
            }
        }
        return mapOf("dir" to dir.absolutePath, "files" to files, "truncated" to (uris.size > MAX_FILES), "failed" to failed)
    }

    private fun displayName(ctx: Context, uri: Uri): String? = try {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (_: Exception) {
        null
    } ?: uri.lastPathSegment

    /** A file name only: no folders, no characters the file system rejects. */
    private fun safeName(raw: String): String {
        val base = raw.substringAfterLast('/').replace(Regex("[\\\\:*?\"<>|\\x00-\\x1F]"), "_").trim().trim('.')
        return if (base.isEmpty()) "file" else base.take(120)
    }

    private fun unique(name: String, used: MutableSet<String>): String {
        var candidate = name
        var n = 1
        val dot = name.lastIndexOf('.')
        while (!used.add(candidate.lowercase())) {
            candidate = if (dot > 0) "${name.substring(0, dot)} ($n)${name.substring(dot)}" else "$name ($n)"
            n++
        }
        return candidate
    }
}
