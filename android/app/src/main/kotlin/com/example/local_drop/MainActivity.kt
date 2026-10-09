package com.example.local_drop

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /**
     * Motor süreç boyunca tek: uygulama son uygulamalardan kaydırılıp Activity
     * yok edilse de Dart isolate'i (ve içindeki HTTP sunucusu) yaşar; süreci ön
     * plan servisi ayakta tutar. Activity'den gelen motor yok edilmez.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        EngineHolder.engine?.let { return it }
        val app = context.applicationContext
        // Eklentiler otomatik kaydedilir (automaticallyRegisterPlugins).
        val engine = FlutterEngine(app)
        MethodChannel(engine.dartExecutor.binaryMessenger, DeviceChannel.NAME)
            .setMethodCallHandler(DeviceChannel(app))
        EngineHolder.engine = engine
        return engine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false
}

private object EngineHolder {
    var engine: FlutterEngine? = null
}
