package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import java.util.concurrent.Executors

/**
 * Receives shares and "Open with" (FR-SHR-01). DocuKit's MainActivity stays
 * singleTop: this invisible activity copies the files while it holds the read
 * grant, queues them, then brings DocuKit forward the way the launcher does,
 * so there's never a second engine and nothing above MainActivity (a picker,
 * an ad, consent, a purchase) is cleared — see DECISIONS ADR-063 / C-5.
 */
class IncomingActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Recreated after a config change, or relaunched from history/recents:
        // the files were already taken; just bring DocuKit forward.
        if (savedInstanceState != null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            openApp()
            done()
            return
        }
        val uris = IncomingFiles.urisOf(intent)
        if (uris.isEmpty()) {
            openApp()
            done()
            return
        }
        val ctx = applicationContext
        copier.execute {
            val batch = IncomingFiles.copy(ctx, uris)
            runOnUiThread {
                IncomingFiles.post(batch)
                openApp()
                done()
            }
        }
    }

    private fun done() = AppForeground.finish(this)

    private fun openApp() = AppForeground.bring(this)

    companion object {
        private val copier = Executors.newSingleThreadExecutor()
    }
}
