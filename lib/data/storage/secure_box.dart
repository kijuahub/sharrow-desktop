import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'paths.dart';

/// AES-256-GCM encrypted file. The key lives in the OS keychain
/// (Credential Manager / Keychain / libsecret / Android Keystore); if the
/// keychain is unavailable it falls back to an owner-only key file.
class SecureBox {
  SecureBox._(this._file, this._key, this.keySource);

  static const _keyName = 'sharrow.master_key.v1';
  static final _aes = AesGcm.with256bits();

  final File _file;
  final SecretKey _key;

  /// 'keychain' or 'file'.
  final String keySource;

  static Future<SecureBox> open(String name) async {
    final (key, source) = await _loadKey();
    return SecureBox._(AppPaths.file(name), key, source);
  }

  static Future<(SecretKey, String)> _loadKey() async {
    const storage = FlutterSecureStorage();
    try {
      var encoded = await storage.read(key: _keyName);
      if (encoded == null) {
        encoded = base64Encode(_randomBytes(32));
        await storage.write(key: _keyName, value: encoded);
      }
      return (SecretKey(base64Decode(encoded)), 'keychain');
    } catch (_) {
      final f = AppPaths.file('.keystore');
      if (!f.existsSync()) {
        f.writeAsStringSync(base64Encode(_randomBytes(32)), flush: true);
        if (!Platform.isWindows) {
          await Process.run('chmod', ['600', f.path]);
        }
      }
      return (SecretKey(base64Decode(f.readAsStringSync().trim())), 'file');
    }
  }

  static List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  Future<String?> read() async {
    if (!_file.existsSync()) return null;
    final bytes = await _file.readAsBytes();
    if (bytes.length < 28) return null;
    final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
    final clear = await _aes.decrypt(box, secretKey: _key);
    return utf8.decode(clear);
  }

  Future<void> write(String text) async {
    final box = await _aes.encrypt(utf8.encode(text), secretKey: _key, nonce: _aes.newNonce());
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsBytes(box.concatenation(), flush: true);
    await tmp.rename(_file.path);
  }

  Future<void> delete() async {
    if (_file.existsSync()) await _file.delete();
  }
}
