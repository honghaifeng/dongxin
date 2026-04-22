package com.example.dongxin_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.bytedance.speech.speechengine.SpeechEngine
import com.bytedance.speech.speechengine.SpeechEngineDefines
import com.bytedance.speech.speechengine.SpeechEngineGenerator
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class DialogPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler, SpeechEngine.SpeechListener {

    companion object {
        private const val TAG = "DialogPlugin"
        private const val METHOD_CHANNEL = "com.dongxin/dialog"
        private const val EVENT_CHANNEL = "com.dongxin/dialog_events"
    }

    private var engine: SpeechEngine? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var environmentPrepared = false
    private var aecModelDir = ""

    fun setupChannels(
        methodChannel: MethodChannel,
        eventChannel: EventChannel
    ) {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initEngine(call, result)
            "start" -> startEngine(call, result)
            "stop" -> stopEngine(result)
            "destroy" -> destroyEngine(result)
            "sayHello" -> sayHello(call, result)
            "sendTextQuery" -> sendTextQuery(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initEngine(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (!environmentPrepared) {
                SpeechEngineGenerator.PrepareEnvironment(
                    context.applicationContext,
                    context.applicationContext as android.app.Application
                )
                environmentPrepared = true
            }

            // 复制AEC模型到files目录
            if (aecModelDir.isEmpty()) {
                aecModelDir = copyAssetToFiles("testdata/aec", "aec.model")
            }

            engine?.destroyEngine()

            engine = SpeechEngineGenerator.getInstance()
            engine?.createEngine()
            // setContext必须在配置参数之前
            engine?.setContext(context.applicationContext)

            val appId = call.argument<String>("appId") ?: ""
            val appKey = call.argument<String>("appKey") ?: ""
            val token = call.argument<String>("token") ?: ""
            val resourceId = call.argument<String>("resourceId") ?: "volc.speech.dialog"
            val uid = call.argument<String>("uid") ?: "pianai_user"

            engine?.apply {
                setOptionString(SpeechEngineDefines.PARAMS_KEY_ENGINE_NAME_STRING, SpeechEngineDefines.DIALOG_ENGINE)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_ID_STRING, appId)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_KEY_STRING, appKey)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_APP_TOKEN_STRING, token)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_RESOURCE_ID_STRING, resourceId)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_UID_STRING, uid)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_DIALOG_ADDRESS_STRING, "wss://openspeech.bytedance.com")
                setOptionString(SpeechEngineDefines.PARAMS_KEY_DIALOG_URI_STRING, "/api/v3/realtime/dialogue")

                // AEC回声消除
                setOptionBoolean(SpeechEngineDefines.PARAMS_KEY_ENABLE_AEC_BOOL, true)
                // AEC模型路径（开启AEC时必填）
                if (aecModelDir.isNotEmpty()) {
                    setOptionString(SpeechEngineDefines.PARAMS_KEY_AEC_MODEL_PATH_STRING, "$aecModelDir/aec.model")
                }

                // 使用设备麦克风
                setOptionString(SpeechEngineDefines.PARAMS_KEY_RECORDER_TYPE_STRING, SpeechEngineDefines.RECORDER_TYPE_RECORDER)

                // 仅做语音转文字，不播放TTS
                setOptionBoolean(SpeechEngineDefines.PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL, false)

                // 日志
                setOptionString(SpeechEngineDefines.PARAMS_KEY_LOG_LEVEL_STRING, SpeechEngineDefines.LOG_LEVEL_TRACE)
                setOptionString(SpeechEngineDefines.PARAMS_KEY_DEBUG_PATH_STRING, "")
            }

            val ret = engine?.initEngine() ?: -1
            if (ret != SpeechEngineDefines.ERR_NO_ERROR) {
                result.error("INIT_FAILED", "引擎初始化失败: $ret", null)
                return
            }

            engine?.setListener(this)

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "init failed", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun copyAssetToFiles(assetDir: String, fileName: String): String {
        val outDir = File(context.filesDir, assetDir)
        if (!outDir.exists()) outDir.mkdirs()
        val outFile = File(outDir, fileName)
        if (!outFile.exists()) {
            try {
                context.assets.open("$assetDir/$fileName").use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "copy asset failed: $assetDir/$fileName", e)
                return ""
            }
        }
        return outDir.absolutePath
    }

    private fun startEngine(call: MethodCall, result: MethodChannel.Result) {
        try {
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_SYNC_STOP_ENGINE, "")

            val botName = call.argument<String>("botName") ?: "AI助手"
            val systemRole = call.argument<String>("systemRole") ?: ""
            val speakingStyle = call.argument<String>("speakingStyle") ?: ""
            val speaker = call.argument<String>("speaker") ?: ""

            val startJson = JSONObject().apply {
                put("dialog", JSONObject().apply {
                    put("bot_name", botName)
                    if (systemRole.isNotEmpty()) put("system_role", systemRole)
                    if (speakingStyle.isNotEmpty()) put("speaking_style", speakingStyle)
                })
                if (speaker.isNotEmpty()) {
                    put("tts", JSONObject().apply {
                        put("speaker", speaker)
                    })
                }
            }.toString()
            Log.i(TAG, "startEngine params: $startJson")

            val ret = engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_START_ENGINE, startJson) ?: -1
            if (ret != SpeechEngineDefines.ERR_NO_ERROR) {
                result.error("START_FAILED", "启动失败: $ret", null)
                return
            }
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun stopEngine(result: MethodChannel.Result) {
        try {
            engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_STOP_ENGINE, "")
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun destroyEngine(result: MethodChannel.Result) {
        try {
            Thread {
                engine?.destroyEngine()
                engine = null
                mainHandler.post { result.success(true) }
            }.start()
        } catch (e: Exception) {
            result.error("DESTROY_ERROR", e.message, null)
        }
    }

    private fun sayHello(call: MethodCall, result: MethodChannel.Result) {
        val content = call.argument<String>("content") ?: "你好，有什么可以帮你的吗？"
        val params = JSONObject().apply {
            put("content", content)
        }
        val ret = engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_EVENT_SAY_HELLO, params.toString()) ?: -1
        if (ret != SpeechEngineDefines.ERR_NO_ERROR) {
            result.error("SAY_HELLO_FAILED", "播报开场白失败: $ret", null)
            return
        }
        result.success(true)
    }

    private fun sendTextQuery(call: MethodCall, result: MethodChannel.Result) {
        val content = call.argument<String>("content") ?: ""
        if (content.isEmpty()) {
            result.error("EMPTY_TEXT", "文本为空", null)
            return
        }
        val params = JSONObject().apply {
            put("content", content)
        }
        val ret = engine?.sendDirective(SpeechEngineDefines.DIRECTIVE_EVENT_CHAT_TEXT_QUERY, params.toString()) ?: -1
        if (ret != SpeechEngineDefines.ERR_NO_ERROR) {
            result.error("TEXT_QUERY_FAILED", "发送文本失败: $ret", null)
            return
        }
        result.success(true)
    }

    // SpeechEngineMessageListener callback
    override fun onSpeechMessage(type: Int, data: ByteArray?, len: Int) {
        val strData = data?.let { String(it) } ?: ""
        val event = mutableMapOf<String, Any>(
            "type" to type,
            "data" to strData
        )

        when (type) {
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_START -> {
                Log.i(TAG, "引擎启动成功")
                event["event"] = "engine_start"
            }
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_STOP -> {
                Log.i(TAG, "引擎关闭")
                event["event"] = "engine_stop"
            }
            SpeechEngineDefines.MESSAGE_TYPE_ENGINE_ERROR -> {
                Log.e(TAG, "错误: $strData")
                event["event"] = "error"
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_INFO -> {
                Log.i(TAG, "ASR开始")
                event["event"] = "asr_start"
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_RESPONSE -> {
                Log.i(TAG, "ASR结果: $strData")
                event["event"] = "asr_result"
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_ASR_ENDED -> {
                Log.i(TAG, "ASR结束")
                event["event"] = "asr_end"
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_CHAT_RESPONSE -> {
                Log.i(TAG, "Chat回复: $strData")
                event["event"] = "chat_response"
            }
            SpeechEngineDefines.MESSAGE_TYPE_DIALOG_CHAT_ENDED -> {
                Log.i(TAG, "Chat结束")
                event["event"] = "chat_end"
            }
            else -> {
                event["event"] = "unknown"
            }
        }

        mainHandler.post {
            eventSink?.success(event)
        }
    }
}
