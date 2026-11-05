/// Session persistence.
///
/// Deliberately has no credential storage: the access token is what keeps a
/// session alive, so persisting the password would add risk and buy nothing.
abstract class StorageService {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> clearAll();
}
