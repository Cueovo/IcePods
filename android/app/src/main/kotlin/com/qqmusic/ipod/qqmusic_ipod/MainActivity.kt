package com.qqmusic.ipod.qqmusic_ipod

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var insetsController: WindowInsetsControllerCompat? = null
    private var audioOutputChannel: MethodChannel? = null
    private var systemFeedbackChannel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private var clickSoundId = 0
    private var clickSoundReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioOutputChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qqmusic_ipod/audio_output",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getCurrentOutputName") {
                    result.success(currentOutputName())
                } else {
                    result.notImplemented()
                }
            }
        }
        initializeClickSound()
        systemFeedbackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qqmusic_ipod/system_feedback",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "playClick") {
                    playClick()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeClickSound() {
        releaseClickSound()
        val pool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
        pool.setOnLoadCompleteListener { _, _, status ->
            clickSoundReady = status == 0
        }
        clickSoundId = assets.openFd("flutter_assets/assets/sounds/click_tick.wav").use {
            pool.load(it, 1)
        }
        soundPool = pool
    }

    private fun playClick() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL || !clickSoundReady) {
            return
        }
        soundPool?.play(clickSoundId, 0.42f, 0.42f, 1, 0, 1f)
    }

    private fun currentOutputName(): String {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val output = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull {
            when (it.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLE_HEADSET,
                AudioDeviceInfo.TYPE_BLE_SPEAKER,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> true
                else -> false
            }
        }
        if (output != null) {
            return output.productName?.toString()?.takeIf { it.isNotBlank() } ?: "蓝牙设备"
        }
        val wired = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any {
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_USB_DEVICE
        }
        return if (wired) "有线音频设备" else "本机扬声器"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyImmersiveWindow()
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemStatusBar()
        }
    }

    override fun onResume() {
        super.onResume()
        hideSystemStatusBar()
    }

    private fun applyImmersiveWindow() {
        // Content must draw under the status-bar / cutout band.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }

        val decor = window.decorView
        insetsController = WindowCompat.getInsetsController(window, decor).also { controller ->
            // Transient bars: swipe reveals them briefly, then they auto-hide again.
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.isAppearanceLightStatusBars = false
            controller.isAppearanceLightNavigationBars = false
        }

        // When Flyme / gesture shows the system bar, re-hide after the transient reveal.
        ViewCompat.setOnApplyWindowInsetsListener(decor) { view, insets ->
            val statusVisible = insets.isVisible(WindowInsetsCompat.Type.statusBars())
            if (statusVisible) {
                view.post { hideSystemStatusBar() }
            }
            ViewCompat.onApplyWindowInsets(view, insets)
        }

        // Legacy fallback for OEM skins that still honor systemUiVisibility.
        @Suppress("DEPRECATION")
        decor.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )

        hideSystemStatusBar()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioOutputChannel?.setMethodCallHandler(null)
        systemFeedbackChannel?.setMethodCallHandler(null)
        audioOutputChannel = null
        systemFeedbackChannel = null
        releaseClickSound()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        releaseClickSound()
        super.onDestroy()
    }

    private fun releaseClickSound() {
        clickSoundReady = false
        soundPool?.setOnLoadCompleteListener(null)
        soundPool?.release()
        soundPool = null
        clickSoundId = 0
    }

    private fun hideSystemStatusBar() {
        insetsController?.hide(WindowInsetsCompat.Type.statusBars())
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
    }
}
