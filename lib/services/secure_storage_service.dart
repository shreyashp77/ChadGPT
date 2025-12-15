import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  late final FlutterSecureStorage _storage;

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
      // Linux uses libsecret by default which is good
    );
  }

  Future<void> writeProtected(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> readProtected(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deleteProtected(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
