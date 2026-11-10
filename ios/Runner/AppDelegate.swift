import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var vpn: VpnBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SharrowVpn") {
      vpn = VpnBridge(messenger: registrar.messenger())
    }
  }
}

/// Drives the PacketTunnel extension (bundle id `<app id>.PacketTunnel`) and mirrors
/// its state to Dart over `app.sharrow/vpn` and `app.sharrow/vpn/events`.
final class VpnBridge: NSObject, FlutterStreamHandler {
  private let methods: FlutterMethodChannel
  private let events: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var manager: NETunnelProviderManager?
  private var observer: NSObjectProtocol?

  private var extensionId: String { (Bundle.main.bundleIdentifier ?? "app.sharrow.sharrow") + ".PacketTunnel" }

  init(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "app.sharrow/vpn", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "app.sharrow/vpn/events", binaryMessenger: messenger)
    super.init()
    events.setStreamHandler(self)
    methods.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    loadManager { [weak self] m in
      if m?.connection.status == .connected { self?.emit("started") }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func emit(_ state: String, _ message: String? = nil) {
    DispatchQueue.main.async { self.sink?(["type": "state", "value": state, "message": message as Any]) }
  }

  private func loadManager(_ done: @escaping (NETunnelProviderManager?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
      guard let self else { return }
      let m = list?.first ?? NETunnelProviderManager()
      self.manager = m
      self.observe(m)
      done(m)
    }
  }

  private func observe(_ m: NETunnelProviderManager) {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: m.connection, queue: .main) { [weak self] _ in
      switch m.connection.status {
      case .connected: self?.emit("started")
      case .disconnected, .invalid: self?.emit("stopped")
      default: break
      }
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "prepare":
      loadManager { [weak self] m in
        guard let self, let m else { return result(false) }
        let proto = (m.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = self.extensionId
        proto.serverAddress = "Sharrow"
        m.protocolConfiguration = proto
        m.localizedDescription = "Sharrow"
        m.isEnabled = true
        m.saveToPreferences { error in
          if error != nil { return result(false) }
          m.loadFromPreferences { _ in result(true) }
        }
      }
    case "start":
      guard let args = call.arguments as? [String: Any], let config = args["config"] as? String, let m = manager else {
        return result(FlutterError(code: "args", message: "config is required", details: nil))
      }
      do {
        try (m.connection as? NETunnelProviderSession)?.startTunnel(options: [
          "config": config as NSString,
          "mode": (args["mode"] as? String ?? "tun") as NSString,
        ])
        result(nil)
      } catch {
        result(FlutterError(code: "start", message: error.localizedDescription, details: nil))
      }
    case "stop":
      manager?.connection.stopVPNTunnel()
      result(nil)
    case "version":
      result(nil)
    case "isCoreAvailable":
      // The core lives inside the extension; presence of the extension is checked on prepare.
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
