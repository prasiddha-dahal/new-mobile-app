/// Bridges this branch's feature providers to the app's DI, which lives in
/// `core/network/providers.dart`.
///
/// Re-exported rather than redefined: declaring a second `dioProvider` here
/// would give the app two Dio instances with two interceptor chains, so a token
/// refreshed on one would be invisible to the other.
library;

export '../network/providers.dart'
    show authApiProvider, authRepositoryProvider, dioProvider, secureStorageProvider;
