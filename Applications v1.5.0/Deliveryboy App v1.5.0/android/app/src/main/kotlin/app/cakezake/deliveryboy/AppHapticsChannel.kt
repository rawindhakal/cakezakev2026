package app.cakezake.deliveryboy

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Backs Dart's AppHaptics on Android. Flutter's HapticFeedback goes through
 * View.performHapticFeedback, which devices without predefined vibration
 * effects (most budget phones) drop silently as "ignored_unsupported". This
 * drives the Vibrator directly instead: the system's predefined effects where
 * the motor supports them, short tuned pulses everywhere else.
 */
object AppHapticsChannel {
    private const val CHANNEL = "app.cakezake/haptics"

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        val vibrator = vibratorOf(appContext)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "play") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val type = call.argument<String>("type")
                if (vibrator != null && type != null && touchFeedbackOn(appContext)) {
                    play(vibrator, type)
                }
                result.success(null)
            }
    }

    private fun vibratorOf(context: Context): Vibrator? {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        return vibrator?.takeIf { it.hasVibrator() }
    }

    // Honors the system "Touch feedback" toggle, same as performHapticFeedback.
    private fun touchFeedbackOn(context: Context): Boolean =
        Settings.System.getInt(
            context.contentResolver,
            Settings.System.HAPTIC_FEEDBACK_ENABLED,
            1,
        ) != 0

    private fun play(vibrator: Vibrator, type: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            vibrator.vibrate(fallbackMs(type))
            return
        }
        val effect = predefinedEffect(vibrator, type) ?: pulseEffect(vibrator, type)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(
                effect,
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH),
            )
        } else {
            vibrator.vibrate(effect)
        }
    }

    private fun predefinedEffect(vibrator: Vibrator, type: String): VibrationEffect? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val id = when (type) {
            "tick" -> VibrationEffect.EFFECT_TICK
            "light" -> VibrationEffect.EFFECT_CLICK
            else -> VibrationEffect.EFFECT_HEAVY_CLICK
        }
        val supported = vibrator.areAllEffectsSupported(id) ==
            Vibrator.VIBRATION_EFFECT_SUPPORT_YES
        return if (supported) VibrationEffect.createPredefined(id) else null
    }

    private fun pulseEffect(vibrator: Vibrator, type: String): VibrationEffect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vibrator.hasAmplitudeControl()) {
            val (ms, amplitude) = when (type) {
                "tick" -> 18L to 90
                "light" -> 24L to 150
                "medium" -> 32L to 210
                else -> 42L to 255
            }
            return VibrationEffect.createOneShot(ms, amplitude)
        }
        return VibrationEffect.createOneShot(fallbackMs(type), VibrationEffect.DEFAULT_AMPLITUDE)
    }

    // On-off motors can't vary strength, so weight is carried by length alone;
    // much under ~20ms they barely spin up and the pulse isn't felt at all.
    private fun fallbackMs(type: String): Long = when (type) {
        "tick" -> 30L
        "light" -> 38L
        "medium" -> 48L
        else -> 60L
    }
}
