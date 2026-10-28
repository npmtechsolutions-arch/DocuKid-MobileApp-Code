package com.npmtechsolutions.docukit_native

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent

/**
 * Brings DocuKit's existing task forward as it is, the way the launcher does,
 * so nothing above MainActivity (a picker, an ad, consent, a purchase) is
 * cleared and there's never a second engine (ADR-063, ADR-065). Used by the
 * invisible relay activities (share-in, launcher shortcut).
 */
internal object AppForeground {
    fun bring(activity: Activity) {
        val launch = activity.packageManager.getLaunchIntentForPackage(activity.packageName) ?: return
        // Matching by intent isn't enough: a task started some other way would
        // get a second MainActivity — and a second engine — on top (R36).
        val tasks = activity.getSystemService(ActivityManager::class.java)?.appTasks.orEmpty()
        val existing = tasks.firstOrNull { it.taskInfo.baseActivity == launch.component }
        if (existing != null) {
            existing.moveToFront()
            return
        }
        // Not running: start it as the launcher would.
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        activity.startActivity(launch)
    }

    /** Leaves no task behind, so recents can't revive the relay later (T8.12, R36). */
    fun finish(activity: Activity) = if (activity.isTaskRoot) activity.finishAndRemoveTask() else activity.finish()
}
