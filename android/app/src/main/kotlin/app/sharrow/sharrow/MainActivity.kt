package app.sharrow.sharrow

import android.content.Intent
import android.net.VpnService
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val vpnRequest = 0x5348
    private var pendingPrepare: MethodChannel.Result? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger

        EventChannel(messenger, "app.sharrow/vpn/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                SharrowVpnService.listener = { sink.success(it) }
                if (SharrowVpnService.running) sink.success(mapOf("type" to "state", "value" to "started"))
            }

            override fun onCancel(args: Any?) {
                SharrowVpnService.listener = null
            }
        })

        MethodChannel(messenger, "app.sharrow/vpn").setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> {
                    val intent = VpnService.prepare(this)
                    if (intent == null) {
                        result.success(true)
                    } else {
                        pendingPrepare?.success(false)
                        pendingPrepare = result
                        startActivityForResult(intent, vpnRequest)
                    }
                }
                "start" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("args", "config is required", null)
                    } else {
                        SharrowVpnService.start(this, config, call.argument<String>("mode") ?: "tun", call.argument<String>("name") ?: "Sharrow")
                        result.success(null)
                    }
                }
                "stop" -> {
                    SharrowVpnService.stop(this)
                    result.success(null)
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                "version" -> result.success(XrayBridge.version())
                "isCoreAvailable" -> result.success(XrayBridge.isAvailable)
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnRequest) {
            pendingPrepare?.success(resultCode == RESULT_OK)
            pendingPrepare = null
        }
    }
}
