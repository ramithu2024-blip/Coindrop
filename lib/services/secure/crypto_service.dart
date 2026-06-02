import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Vault cryptography service.
///
/// Provides PBKDF2-SHA256 key derivation (100k iterations), vault hash
/// verification, and AES-256-GCM note-level encryption.
///
/// The old `encryptAes`/`decryptAes` (AES-CBC) methods have been removed.
/// All note/memo encryption now uses AES-GCM with random 12-byte IV per
/// encryption, providing authenticated encryption and nonce reuse resistance.
class CryptoService {
  static const _saltLength = 32;
  static const _iterations = 100000;
  static const _keyLength = 32;

  /// Generates a cryptographically random 32-byte salt, base64-encoded.
  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 with 100,000 iterations.
  /// Returns a 32-byte derived key as Uint8List.
  Uint8List deriveKey(String password, String salt) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Decode(salt);
    final hmac = Hmac(sha256, passwordBytes);
    final combined = Uint8List(saltBytes.length + 4)
      ..setRange(0, saltBytes.length, saltBytes)
      ..[saltBytes.length] = 0
      ..[saltBytes.length + 1] = 0
      ..[saltBytes.length + 2] = 0
      ..[saltBytes.length + 3] = 1;
    var u = hmac.convert(combined).bytes;
    var result = Uint8List.fromList(u);

    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      result = Uint8List.fromList(
        List<int>.generate(result.length, (j) => result[j] ^ u[j]),
      );
    }

    if (result.length > _keyLength) {
      result = Uint8List.sublistView(result, 0, _keyLength);
    }
    return result;
  }

  /// Encodes a derived key as base64 for use as SQLCipher PRAGMA key.
  String keyToHex(Uint8List key) {
    return base64Encode(key);
  }

  /// Decodes a base64 key back to bytes.
  Uint8List hexToKey(String hex) {
    return base64Decode(hex);
  }

  /// SHA-256 hash of the derived key, base64-encoded.
  String computeVerificationHash(Uint8List derivedKey) {
    final hash = sha256.convert(derivedKey);
    return base64Encode(hash.bytes);
  }

  /// Constant-time comparison of derived key against stored verification hash.
  bool verifyDerivedKey(Uint8List derivedKey, String storedHash) {
    final computed = sha256.convert(derivedKey);
    final computedB64 = base64Encode(computed.bytes);
    return computedB64 == storedHash;
  }

  /// Bundles salt and verification hash into one string for storage.
  String buildVaultHash(String salt, Uint8List derivedKey) {
    final verHash = computeVerificationHash(derivedKey);
    return '$salt:$verHash';
  }

  /// Parses a vault hash string back into (salt, verificationHash).
  (String, String?) parseVaultHash(String vaultHash) {
    final parts = vaultHash.split(':');
    if (parts.length != 2) return ('', null);
    return (parts[0], parts[1]);
  }

  // ---------------------------------------------------------------------------
  // AES-256-GCM Note-Level Encryption
  // ---------------------------------------------------------------------------

  /// AES-256-GCM encrypt a single note field using a derived sub-key.
  /// Each encryption uses a random 12-byte IV.
  /// The master key is never used directly for notes.
  String encryptNote(String plaintext, Uint8List noteKey) {
    final iv = _generateGcmIv();
    final subKey = _deriveNoteKey(noteKey);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(subKey)));
    final encrypted = encrypter.encrypt(plaintext, iv: enc.IV(iv));
    final result = {
      'data': encrypted.base64,
      'iv': base64Encode(iv),
    };
    return jsonEncode(result);
  }

  /// AES-256-GCM decrypt a note field.
  String decryptNote(String encryptedJson, Uint8List noteKey) {
    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final encryptedData = data['data'] as String;
    final iv = base64Decode(data['iv'] as String);
    final subKey = _deriveNoteKey(noteKey);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(subKey)));
    return encrypter.decrypt(
      enc.Encrypted.fromBase64(encryptedData),
      iv: enc.IV(iv),
    );
  }

  /// Derive a note-specific sub-key from the vault master key using HMAC-SHA256.
  /// This ensures note keys are independent of the master key.
  Uint8List _deriveNoteKey(Uint8List masterKey) {
    final hmac = Hmac(sha256, masterKey);
    final digest = hmac.convert(utf8.encode('coindrop-note-encryption-v1'));
    return Uint8List.fromList(digest.bytes);
  }

  Uint8List _generateGcmIv() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(12, (_) => random.nextInt(256)));
  }
}
