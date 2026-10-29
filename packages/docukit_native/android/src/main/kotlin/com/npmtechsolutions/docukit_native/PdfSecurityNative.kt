package com.npmtechsolutions.docukit_native

import android.content.Context
import android.os.Handler
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executor

/**
 * Protect / Unlock PDF on Android with PdfBox-Android (RELEASE_V1_4 §4.6,
 * ADR-049). Passwords arrive as Strings and are NEVER logged or kept; they go
 * out of scope when the call ends. Files are streamed from and to paths; no
 * PDF bytes cross the channel.
 */
class PdfSecurityNative(private val context: Context, private val io: Executor, private val main: Handler) {
    @Volatile private var loaderReady = false

    private fun ensureLoader() {
        if (!loaderReady) {
            PDFBoxResourceLoader.init(context)
            loaderReady = true
        }
    }

    /** Large inputs use a scratch file instead of memory (§4.6). */
    private fun memory(file: File): MemoryUsageSetting =
        if (file.length() > 50L * 1024 * 1024) MemoryUsageSetting.setupTempFileOnly() else MemoryUsageSetting.setupMainMemoryOnly()

    fun protect(call: MethodCall, result: MethodChannel.Result) {
        val inPath = call.argument<String>("inPath")
        val outPath = call.argument<String>("outPath")
        val user = call.argument<String>("userPassword")
        val owner = call.argument<String>("ownerPassword")
        // Debug-only fixture switch: no permissions (an owner-restricted PDF).
        val restrict = call.argument<Boolean>("debugRestrict") == true
        if (inPath == null || outPath == null || user == null || owner == null) {
            result.success(mapOf("status" to "failed", "code" to "bad_args"))
            return
        }
        io.execute {
            val outcome = try {
                ensureLoader()
                val src = File(inPath)
                PDDocument.load(src, memory(src)).use { doc ->
                    val permissions = AccessPermission()
                    if (restrict) {
                        permissions.setCanPrint(false)
                        permissions.setCanModify(false)
                    }
                    val policy = StandardProtectionPolicy(owner, user, permissions)
                    policy.encryptionKeyLength = 256
                    doc.protect(policy)
                    doc.save(File(outPath))
                }
                mapOf("status" to "ok")
            } catch (e: InvalidPasswordException) {
                mapOf("status" to "failed", "code" to "encrypted")
            } catch (e: Throwable) {
                // Never the message: it may contain a path.
                mapOf("status" to "failed", "code" to e.javaClass.simpleName)
            }
            main.post { result.success(outcome) }
        }
    }

    fun unlock(call: MethodCall, result: MethodChannel.Result) {
        val inPath = call.argument<String>("inPath")
        val outPath = call.argument<String>("outPath")
        val password = call.argument<String>("password")
        if (inPath == null || outPath == null || password == null) {
            result.success(mapOf("status" to "failed", "code" to "bad_args"))
            return
        }
        io.execute {
            val outcome = try {
                ensureLoader()
                val src = File(inPath)
                PDDocument.load(src, password, memory(src)).use { doc ->
                    if (!doc.isEncrypted) {
                        mapOf("status" to "notEncrypted")
                    } else {
                        doc.isAllSecurityToBeRemoved = true
                        doc.save(File(outPath))
                        mapOf("status" to "ok")
                    }
                }
            } catch (e: InvalidPasswordException) {
                mapOf("status" to "wrongPassword")
            } catch (e: Throwable) {
                mapOf("status" to "failed", "code" to e.javaClass.simpleName)
            }
            main.post { result.success(outcome) }
        }
    }

    /** none | openPassword | ownerOnly */
    fun protection(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.success("none")
            return
        }
        io.execute {
            val outcome = try {
                ensureLoader()
                val src = File(path)
                PDDocument.load(src, memory(src)).use { doc -> if (doc.isEncrypted) "ownerOnly" else "none" }
            } catch (e: InvalidPasswordException) {
                "openPassword"
            } catch (e: Throwable) {
                "failed"
            }
            main.post { result.success(outcome) }
        }
    }
}
