package app.sharrow.sharrow

import android.content.Intent
import android.net.VpnService
import android.provider.Settings
import android.system.Os
import android.system.OsConstants
import android.system.StructTimeval
import io.flutter.embedding.android.FlutterActivity
import java.net.InetAddress
import java.net.InetSocketAddress
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
                    val consent = VpnService.prepare(this)
                    if (consent != null) {
                        startActivity(consent)
                    } else {
                        startActivity(Intent(Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                    result.success(true)
                }
                "icmp" -> {
                    val host = call.argument<String>("host") ?: ""
                    val timeout = call.argument<Int>("timeout") ?: 3000
                    Thread {
                        val ms = icmpPing(host, timeout)
                        runOnUiThread { result.success(ms) }
                    }.start()
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

/** ICMP echo. -2 when this device has no ICMP socket, so Dart can try /system/bin/ping. */
private fun icmpPing(host: String, timeoutMs: Int): Int {
    if (host.isEmpty()) return -1
    val fd = try {
        Os.socket(OsConstants.AF_INET, OsConstants.SOCK_DGRAM, OsConstants.IPPROTO_ICMP)
    } catch (_: Exception) {
        return -2
    }
    return try {
        val address = InetAddress.getByName(host)
        Os.setsockoptTimeval(fd, OsConstants.SOL_SOCKET, OsConstants.SO_RCVTIMEO, StructTimeval.fromMillis(timeoutMs.toLong()))
        val packet = ByteArray(16)
        packet[0] = 8
        packet[5] = 1
        packet[7] = 1
        val sum = icmpChecksum(packet)
        packet[2] = (sum.toInt() shr 8).toByte()
        packet[3] = (sum.toInt() and 0xff).toByte()
        val start = System.nanoTime()
        try {
            Os.sendto(fd, packet, 0, packet.size, 0, address, 0)
        } catch (_: Exception) {
            return -2
        }
        Os.recvfrom(fd, ByteArray(128), 0, 128, 0, InetSocketAddress(0))
        ((System.nanoTime() - start) / 1_000_000L).toInt().coerceAtLeast(1)
    } catch (_: Exception) {
        -1
    } finally {
        Os.close(fd)
    }
}

private fun icmpChecksum(bytes: ByteArray): UShort {
    var sum = 0
    var i = 0
    while (i + 1 < bytes.size) {
        sum += ((bytes[i].toInt() and 0xff) shl 8) or (bytes[i + 1].toInt() and 0xff)
        i += 2
    }
    while (sum > 0xffff) sum = (sum and 0xffff) + (sum shr 16)
    return (sum.inv() and 0xffff).toUShort()
}
