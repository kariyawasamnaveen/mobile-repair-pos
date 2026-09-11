import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupEncryptionServiceProvider = Provider<BackupEncryptionService>((ref) {
  return BackupEncryptionService();
});

class BackupEncryptionService {
  final _storage = const FlutterSecureStorage();
  final _algorithm = AesGcm.with256bits();
  static const _keyStorageKey = 'backup_encryption_key';

  Future<SecretKey> _getOrGenerateKey() async {
    final existingKeyBase64 = await _storage.read(key: _keyStorageKey);
    if (existingKeyBase64 != null) {
      final keyBytes = base64Decode(existingKeyBase64);
      return SecretKey(keyBytes);
    }

    final newKey = await _algorithm.newSecretKey();
    final newKeyBytes = await newKey.extractBytes();
    await _storage.write(key: _keyStorageKey, value: base64Encode(newKeyBytes));
    return newKey;
  }

  Future<String> getRecoveryKey() async {
    final existingKeyBase64 = await _storage.read(key: _keyStorageKey);
    if (existingKeyBase64 != null) {
      return existingKeyBase64;
    }
    final newKey = await _getOrGenerateKey();
    final bytes = await newKey.extractBytes();
    return base64Encode(bytes);
  }

  Future<List<int>> encryptFile(List<int> plainText) async {
    final key = await _getOrGenerateKey();
    final secretBox = await _algorithm.encrypt(
      plainText,
      secretKey: key,
    );
    return secretBox.concatenation();
  }

  Future<List<int>> decryptFile(List<int> cipherText) async {
    final key = await _getOrGenerateKey();
    final secretBox = SecretBox.fromConcatenation(
      cipherText,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    final plainText = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );
    return plainText;
  }
}
