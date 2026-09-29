package com.birdnet.birdnet_live

import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Launcher icon per bird theme (J6i). Each bird has an activity-alias in the
 * manifest (AliasLoriot, AliasMartin, AliasFlamant, AliasEtourneau); exactly
 * one is enabled. `setIcon(bird)` remembers the choice and applies it when the
 * activity stops (app goes to the background): switching aliases while the app
 * is on screen would make some launchers close it.
 */
object AppIconChannel {
    private const val CHANNEL = "fr.justcodeit.birdygo/app_icon"
    private const val PACKAGE_CLASS = "com.birdnet.birdnet_live"
    private val BIRDS = listOf("loriot", "martin", "flamant", "etourneau")

    private var pending: String? = null

    fun register(engine: FlutterEngine, activity: FlutterActivity) {
        val context = activity as android.content.Context
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val bird = call.arguments as? String
                    if (bird == null || bird !in BIRDS) {
                        result.error("bad_args", "known bird name expected", null)
                    } else {
                        pending = bird
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        activity.lifecycle.addObserver(LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) applyPending(context)
        })
    }

    private fun aliasName(bird: String) =
        "$PACKAGE_CLASS.Alias${bird.replaceFirstChar { it.uppercase() }}"

    /** Enables the pending bird's alias first, then disables the others. */
    private fun applyPending(context: android.content.Context) {
        val bird = pending ?: return
        pending = null
        val pm = context.packageManager
        fun set(name: String, state: Int) {
            val cn = ComponentName(context.packageName, name)
            if (pm.getComponentEnabledSetting(cn) != state) {
                pm.setComponentEnabledSetting(cn, state, PackageManager.DONT_KILL_APP)
            }
        }
        set(aliasName(bird), PackageManager.COMPONENT_ENABLED_STATE_ENABLED)
        for (other in BIRDS) {
            if (other != bird) set(aliasName(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
        }
    }
}
