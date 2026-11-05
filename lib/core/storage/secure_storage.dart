import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_service.dart';

/// Wrapper around FlutterSecureStorage for token persistence.
///
/// On web (where FlutterSecureStorage is unsupported), falls back to
/// an in-memory map so the app can function during development/testing.
class SecureStorage implements StorageService {
  SecureStorage(this._storage);

  final FlutterSecureStorage? _storage;
  final _memory = <String, String>{};

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  @override
  Future<void> saveAccessToken(String token) async {
    await _write(_accessTokenKey, token);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _read(_accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _write(_refreshTokenKey, token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }




  @override
  Future<void> clearAll() async {
    if (_storage != null) {
      await _storage.deleteAll();
    }
    _memory.clear();
  }

  Future<void> _write(String key, String value) async {
    if (_storage != null) {
      await _storage.write(key: key, value: value);
    } else {
      _memory[key] = value;
    }
  }

  Future<String?> _read(String key) async {
    if (_storage != null) {
      return await _storage.read(key: key);
    }
    return _memory[key];
  }
}
