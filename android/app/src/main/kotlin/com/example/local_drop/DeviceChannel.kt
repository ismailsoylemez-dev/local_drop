package com.example.local_drop

import android.content.ContentValues
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import kotlin.concurrent.thread

/**
 * Dart `DeviceChannel` karşılığı:
 * - acquireLocks/releaseLocks: transfer sürerken CPU (PARTIAL) + Wi-Fi kilidi.
 * - downloadsSupported/saveToDownloads: MediaStore ile Download/<klasör>.
 * - downloadsDir: Download/<klasör> yolu (Android 11+; uygulamanın kendi
 *   kaydettiği dosyalar izinsiz okunur/silinir), altında null.
 */
class DeviceChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "local_drop/device"
        private const val LOCK_TAG = "LocalDrop:transfer"
        private const val COPY_BUFFER = 256 * 1024
    }

    private val main = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "acquireLocks" -> {
                acquireLocks()
                result.success(null)
            }
            "releaseLocks" -> {
                releaseLocks()
                result.success(null)
            }
            "downloadsDir" -> {
                val folder = call.argument<String>("folder")
                if (folder == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                    result.success(null)
                } else {
                    @Suppress("DEPRECATION")
                    val base = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                    result.success(File(base, folder).absolutePath)
                }
            }
            "downloadsSupported" ->
                result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            "saveToDownloads" -> {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val folder = call.argument<String>("folder")
                if (path == null || name == null || folder == null) {
                    result.error("BAD_ARGS", "path/name/folder gerekli", null)
                    return
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("UNSUPPORTED", "Android 10+ gerekir", null)
                    return
                }
                // Büyük dosya kopyası ana thread'i kilitlemesin.
                thread(name = "LocalDrop-MediaStore") {
                    try {
                        val uri = saveToDownloads(File(path), name, folder)
                        main.post { result.success(uri) }
                    } catch (e: Exception) {
                        main.post { result.error("SAVE_FAILED", e.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun acquireLocks() {
        if (wakeLock?.isHeld != true) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, LOCK_TAG).apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        // Android 14+'ta HIGH_PERF etkisiz; ön plan servisi + CPU kilidi yeterli.
        if (wifiLock?.isHeld != true && Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, LOCK_TAG).apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    private fun releaseLocks() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wifiLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        wifiLock = null
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveToDownloads(source: File, name: String, folder: String): String {
        val resolver = context.contentResolver
        val extension = name.substringAfterLast('.', "").lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$folder")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("MediaStore kaydı oluşturulamadı")
        try {
            val out = resolver.openOutputStream(uri) ?: throw IOException("Çıkış akışı açılamadı")
            out.use { o -> source.inputStream().use { it.copyTo(o, COPY_BUFFER) } }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        return uri.toString()
    }
}
