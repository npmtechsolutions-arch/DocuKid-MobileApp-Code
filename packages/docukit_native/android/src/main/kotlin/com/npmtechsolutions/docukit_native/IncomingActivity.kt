package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.app.ActivityManager
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

    /** Leaves no task behind: a kept task would be revived later with this same share (T8.12, R36). */
    private fun done() = if (isTaskRoot) finishAndRemoveTask() else finish()

    private fun openApp() {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
        // Bring DocuKit's existing task forward as it is (a picker, an ad or a
        // purchase on top stays there). Matching by intent isn't enough: a task
        // started some other way would get a second MainActivity — and a second
        // engine — on top (found on the emulator, R36).
        val tasks = getSystemService(ActivityManager::class.java)?.appTasks.orEmpty()
        val existing = tasks.firstOrNull { it.taskInfo.baseActivity == launch.component }
        if (existing != null) {
            existing.moveToFront()
            return
        }
        // Not running: start it as the launcher would.
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        startActivity(launch)
    }

    companion object {
        private val copier = Executors.newSingleThreadExecutor()
    }
}
