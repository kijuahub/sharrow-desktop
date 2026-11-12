package app.sharrow.sharrow

import android.content.Context
import android.system.Os
import android.util.Base64
import org.json.JSONObject
import java.io.File

/**
 * Thin reflection wrapper over the gomobile libXray AAR (android/app/libs/libXray.aar,
 * fetched by tool/fetch_core). Reflection keeps the project buildable without the AAR.
 */
object XrayBridge {
    /** Fixed descriptor number the TUN fd is duplicated onto before every start. */
    const val TUN_FD = 801

    private var cls: Class<*>? = null

    val isAvailable: Boolean
        get() = load() != null

    private fun load(): Class<*>? {
        cls?.let { return it }
        // Go snapshots the environment when its runtime starts, so this must run
        // before the first call into the library.
        try {
            Os.setenv("XRAY_TUN_FD", TUN_FD.toString(), true)
        } catch (_: Throwable) {
        }
        cls = try {
            Class.forName("libXray.LibXray")
        } catch (_: Throwable) {
            null
        }
        return cls
    }

    private fun call(name: String, vararg args: Any): Any? {
        val c = load() ?: throw IllegalStateException("Xray core library is not bundled")
        val m = c.methods.firstOrNull { it.name == name && it.parameterTypes.size == args.size }
            ?: throw IllegalStateException("libXray.$name is missing")
        return m.invoke(null, *args)
    }

    private fun decode(resp: Any?): JSONObject {
        val text = resp as? String ?: return JSONObject().put("success", true)
        return try {
            JSONObject(String(Base64.decode(text, Base64.DEFAULT)))
        } catch (_: Throwable) {
            JSONObject().put("success", text.isEmpty()).put("error", text)
        }
    }

    fun version(): String? = try {
        if (has("invoke")) {
            val data = invoke("xrayVersion", JSONObject()).optJSONObject("data")
            data?.optString("version")?.ifEmpty { null }
        } else {
            val r = decode(call("xrayVersion"))
            r.optString("data").ifEmpty { null }
        }
    } catch (_: Throwable) {
        null
    }

    fun assetDir(ctx: Context): File {
        val dir = File(ctx.filesDir, "core")
        dir.mkdirs()
        for (name in listOf("geoip.dat", "geosite.dat")) {
            val out = File(dir, name)
            if (out.exists()) continue
            try {
                ctx.assets.open("core/$name").use { input -> out.outputStream().use { input.copyTo(it) } }
            } catch (_: Throwable) {
            }
        }
        return dir
    }

    private fun encode(req: JSONObject) = Base64.encodeToString(req.toString().toByteArray(), Base64.NO_WRAP)

    private fun has(name: String) = load()?.methods?.any { it.name == name } == true

    /** libXray API v3. The response is plain JSON, not the old base64 envelope. */
    private fun invoke(method: String, payload: JSONObject): JSONObject {
        val req = JSONObject().put("apiVersion", 3).put("method", method).put("payload", payload)
        val raw = call("invoke", req.toString()) as? String ?: return JSONObject().put("success", false).put("error", "empty response")
        return try {
            JSONObject(raw)
        } catch (_: Throwable) {
            decode(raw)
        }
    }

    private fun withRuntime(config: String, assetDir: String): String {
        val root = try {
            JSONObject(config)
        } catch (_: Throwable) {
            JSONObject()
        }
        val env = root.optJSONObject("env") ?: JSONObject()
        env.put("xray.tun.fd", TUN_FD.toString())
        env.put("xray.location.asset", assetDir)
        root.put("env", env)
        return root.toString()
    }

    fun start(ctx: Context, config: String) {
        val dir = assetDir(ctx)
        Os.setenv("XRAY_LOCATION_ASSET", dir.absolutePath, true)
        val r = if (has("invoke")) {
            invoke("runXray", JSONObject().put("xrayJson", withRuntime(config, dir.absolutePath)))
        } else if (has("runXrayFromJSON")) {
            decode(call("runXrayFromJSON", encode(JSONObject().put("datDir", dir.absolutePath).put("configJSON", config))))
        } else if (has("runXray")) {
            val cfg = File(ctx.noBackupFilesDir, "run.json")
            try {
                cfg.writeText(config)
                decode(call("runXray", encode(JSONObject().put("datDir", dir.absolutePath).put("configPath", cfg.absolutePath))))
            } finally {
                cfg.delete()
            }
        } else {
            throw IllegalStateException("libXray.invoke is missing")
        }
        if (!r.optBoolean("success", false)) throw IllegalStateException(r.optString("error", "Xray failed to start"))
    }

    fun stop() {
        try {
            if (has("invoke")) invoke("stopXray", JSONObject()) else call("stopXray")
        } catch (_: Throwable) {
        }
    }
}
