package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Target of the launcher shortcut "Scan" (FR-SCN-22, ADR-065). Launcher
 * shortcuts start their activity with NEW_TASK | CLEAR_TASK; pointing them at
 * MainActivity would wipe whatever DocuKit had open. This invisible activity
 * runs in its own task instead: it queues the route, brings DocuKit forward
 * untouched and removes itself. Not exported: only the launcher (on DocuKit's
 * behalf) can start it.
 */
class ShortcutActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val fresh = savedInstanceState == null && intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0
        if (fresh) routeOf(intent.data)?.let(PendingRoute::post)
        AppForeground.bring(this)
        AppForeground.finish(this)
    }

    companion object {
        /** `docukit://open/tool/scan?autostart=1` → `/tool/scan?autostart=1`; anything else → null. */
        fun routeOf(data: Uri?): String? {
            if (data == null || data.scheme != "docukit" || data.host != "open") return null
            val path = data.path ?: return null
            if (!path.startsWith("/tool/")) return null
            return if (data.query.isNullOrEmpty()) path else "$path?${data.query}"
        }
    }
}

/** The last shortcut route, until Dart takes it (cold start) or is told (warm). */
object PendingRoute {
    private var pending: String? = null
    private var listener: ((String) -> Unit)? = null

    @Synchronized
    fun setListener(l: ((String) -> Unit)?) {
        listener = l
    }

    @Synchronized
    fun post(route: String) {
        val l = listener
        if (l != null) l(route) else pending = route
    }

    @Synchronized
    fun take(): String? = pending.also { pending = null }
}
