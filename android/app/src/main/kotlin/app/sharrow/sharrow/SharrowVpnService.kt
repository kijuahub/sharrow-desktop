package app.sharrow.sharrow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.system.Os
import java.util.concurrent.Executors

class SharrowVpnService : VpnService() {
    companion object {
        const val ACTION_START = "app.sharrow.START"
        const val ACTION_STOP = "app.sharrow.STOP"
        private const val CHANNEL = "vpn"
        private const val NOTIFICATION_ID = 1

        @Volatile var running = false
        @Volatile private var pendingConfig: String? = null
        var listener: ((Map<String, Any?>) -> Unit)? = null

        private val main = Handler(Looper.getMainLooper())

        fun emit(event: Map<String, Any?>) = main.post { listener?.invoke(event) }

        fun start(ctx: Context, config: String, mode: String, name: String) {
            pendingConfig = config
            val i = Intent(ctx, SharrowVpnService::class.java)
                .setAction(ACTION_START)
                .putExtra("mode", mode)
                .putExtra("name", name)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.startService(Intent(ctx, SharrowVpnService::class.java).setAction(ACTION_STOP))
        }
    }

    private val worker = Executors.newSingleThreadExecutor()
    private var tun: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> worker.execute { shutdown("stopped", null) }
            ACTION_START -> {
                val config = pendingConfig
                pendingConfig = null
                val mode = intent.getStringExtra("mode") ?: "tun"
                val name = intent.getStringExtra("name") ?: "Sharrow"
                foreground(name)
                if (config == null) {
                    shutdown("error", "No configuration")
                } else {
                    worker.execute { launch(config, mode, name) }
                }
            }
            // Always-on VPN restart without UI: nothing to resume from.
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun launch(config: String, mode: String, name: String) {
        try {
            if (running) {
                XrayBridge.stop()
                closeTun()
            }
            if (mode == "tun") {
                val fd = establish(name) ?: throw IllegalStateException("VPN permission revoked")
                tun = fd
                Os.dup2(fd.fileDescriptor, XrayBridge.TUN_FD)
            }
            XrayBridge.start(this, config)
            running = true
            emit(mapOf("type" to "state", "value" to "started"))
        } catch (t: Throwable) {
            shutdown("error", t.message ?: t.toString())
        }
    }

    private fun establish(name: String): ParcelFileDescriptor? {
        val b = Builder()
            .setSession(name)
            .setMtu(1500)
            .addAddress("172.19.0.1", 30)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("172.19.0.2")
        try {
            b.addAddress("fdfe:dcba:9876::1", 126)
            b.addRoute("::", 0)
        } catch (_: Throwable) {
        }
        // Xray's own sockets must not loop back into the tunnel.
        try {
            b.addDisallowedApplication(packageName)
        } catch (_: Throwable) {
        }
        if (Build.VERSION.SDK_INT >= 29) b.setMetered(false)
        b.setConfigureIntent(
            PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        )
        return b.establish()
    }

    private fun closeTun() {
        try {
            tun?.close()
        } catch (_: Throwable) {
        }
        tun = null
    }

    private fun shutdown(state: String, message: String?) {
        XrayBridge.stop()
        closeTun()
        running = false
        emit(mapOf("type" to "state", "value" to state, "message" to message))
        main.post {
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
            stopSelf()
        }
    }

    override fun onRevoke() {
        worker.execute { shutdown("stopped", "revoked") }
    }

    override fun onDestroy() {
        if (running) {
            XrayBridge.stop()
            closeTun()
            running = false
            emit(mapOf("type" to "state", "value" to "stopped"))
        }
        worker.shutdown()
        super.onDestroy()
    }

    private fun foreground(name: String) {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "VPN", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, SharrowVpnService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        val n = builder
            .setSmallIcon(R.drawable.ic_stat_sharrow)
            .setContentTitle(name)
            .setContentText("VPN")
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }
}
