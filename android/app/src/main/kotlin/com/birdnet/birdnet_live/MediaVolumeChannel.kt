package com.birdnet.birdnet_live

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Media volume (STREAM_MUSIC) for the listening screen warning.
 * `level` returns 0..1; `setLevel` takes 0..1 and shows the system volume UI.
 */
object MediaVolumeChannel {
    private const val CHANNEL = "fr.justcodeit.birdygo/media_volume"

    fun register(engine: FlutterEngine, context: Context) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            when (call.method) {
                "level" -> result.success(
                    if (max <= 0) null
                    else audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
                )
                "setLevel" -> {
                    val level = (call.arguments as? Number)?.toDouble()
                    if (level == null || max <= 0) {
                        result.error("bad_args", "level expected", null)
                    } else {
                        val index = Math.round(level.coerceIn(0.0, 1.0) * max).toInt()
                        audio.setStreamVolume(
                            AudioManager.STREAM_MUSIC,
                            index,
                            AudioManager.FLAG_SHOW_UI,
                        )
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
