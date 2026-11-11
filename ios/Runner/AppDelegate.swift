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
    case "prepare", "openSettings":
      // saveToPreferences is what presents the system "Add VPN Configurations" alert.
      installProfile(result)
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
    case "icmp":
      let args = call.arguments as? [String: Any]
      let host = args?["host"] as? String ?? ""
      let timeout = args?["timeout"] as? Int ?? 3000
      DispatchQueue.global(qos: .userInitiated).async {
        let ms = IcmpPing.ping(host: host, timeoutMs: timeout)
        DispatchQueue.main.async { result(ms) }
      }
    case "version":
      result(nil)
    case "isCoreAvailable":
      // The core lives inside the extension; presence of the extension is checked on prepare.
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Presents the system VPN alert. The completion runs only after Allow or Don't Allow.
  private func installProfile(_ result: @escaping FlutterResult) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
      DispatchQueue.main.async {
        guard let self else { return result(false) }
        let manager = list?.first ?? NETunnelProviderManager()
        manager.loadFromPreferences { _ in
          DispatchQueue.main.async {
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = self.extensionId
            proto.serverAddress = "Sharrow"
            manager.protocolConfiguration = proto
            manager.localizedDescription = "Sharrow"
            manager.isEnabled = true
            self.manager = manager
            self.observe(manager)
            manager.saveToPreferences { error in
              DispatchQueue.main.async {
                if error != nil { return result(false) }
                manager.loadFromPreferences { _ in result(true) }
              }
            }
          }
        }
      }
    }
  }
}

/// ICMP echo for UDP servers. iOS has no `ping` binary in the app sandbox.
enum IcmpPing {
  static func ping(host: String, timeoutMs: Int) -> Int {
    guard !host.isEmpty else { return -1 }
    var hints = addrinfo()
    hints.ai_family = AF_INET
    hints.ai_socktype = SOCK_DGRAM
    var info: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, nil, &hints, &info) == 0, let first = info?.pointee else { return -1 }
    defer { freeaddrinfo(info) }
    let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
    if fd < 0 { return -2 }
    defer { close(fd) }
    var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: Int32((timeoutMs % 1000) * 1000))
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

    var packet = [UInt8](repeating: 0, count: 16)
    packet[0] = 8
    packet[5] = 1
    packet[7] = 1
    let sum = checksum(packet)
    packet[2] = UInt8(sum >> 8)
    packet[3] = UInt8(sum & 0xff)

    let start = Date()
    let sent = packet.withUnsafeBytes { raw -> Int in
      guard let base = raw.baseAddress else { return -1 }
      return sendto(fd, base, raw.count, 0, first.ai_addr, first.ai_addrlen)
    }
    if sent < 0 { return -1 }
    var buf = [UInt8](repeating: 0, count: 128)
    let got = buf.withUnsafeMutableBytes { raw -> Int in
      guard let base = raw.baseAddress else { return -1 }
      return recvfrom(fd, base, raw.count, 0, nil, nil)
    }
    if got <= 0 { return -1 }
    return max(1, Int(Date().timeIntervalSince(start) * 1000))
  }

  private static func checksum(_ bytes: [UInt8]) -> UInt16 {
    var sum = 0
    var i = 0
    while i + 1 < bytes.count {
      sum += (Int(bytes[i]) << 8) | Int(bytes[i + 1])
      i += 2
    }
    while sum > 0xffff { sum = (sum & 0xffff) + (sum >> 16) }
    return UInt16(truncatingIfNeeded: ~sum)
  }
}
