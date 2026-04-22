package com.example.dongxin_flutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val dialogPlugin = DialogPlugin(this)
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.dongxin/dialog"
        )
        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.dongxin/dialog_events"
        )
        dialogPlugin.setupChannels(methodChannel, eventChannel)
    }
}
