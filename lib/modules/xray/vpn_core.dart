import '../../core/platform.dart';
import 'config_builder.dart';
import 'desktop_core.dart';
import 'mobile_core.dart';

enum CoreErrorKind { missing, portBusy, startFailed, timeout, permission, unsupported }

class CoreException implements Exception {
  CoreException(this.kind, this.message);

  final CoreErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Platform-independent contract for the tunnel engine.
abstract class VpnCore {
  static VpnCore create() => Plat.isMobile ? MobileVpnCore() : DesktopXrayCore();

  bool get isRunning;

  /// Invoked when the engine stops without being asked to.
  void Function(String reason)? onCrash;

  Future<bool> isInstalled();

  Future<String?> version();

  Future<void> start(
    Map<String, dynamic> config, {
    required TunnelMode mode,
    required Duration timeout,
    required int readyPort,
  });

  Future<void> stop();

  /// Kills engine processes left over from a previous crash.
  Future<void> cleanupOrphans() async {}

  /// Opens the system page where the VPN configuration is approved.
  Future<void> openVpnSettings() async {}
}
