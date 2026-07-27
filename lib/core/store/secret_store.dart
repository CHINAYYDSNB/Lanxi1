import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over secret persistence.
///
/// Decouples [ServerStore] from [FlutterSecureStorage] so it can be unit-tested
/// with an in-memory fake. Only non-structured secret blobs travel through here.
abstract class SecretStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

/// [SecretStore] backed by OS secure storage (Keychain / Keystore / etc.).
class SecureStorageSecretStore implements SecretStore {
  final FlutterSecureStorage _inner;

  SecureStorageSecretStore([FlutterSecureStorage? inner])
      : _inner = inner ?? const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _inner.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _inner.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _inner.delete(key: key);
}
