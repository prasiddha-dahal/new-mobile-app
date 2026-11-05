import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import '../storage/storage_service.dart';
import '../../features/auth/data/datasources/auth_api.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

final secureStorageProvider = Provider<StorageService>((ref) {
  const isWeb = bool.fromEnvironment('dart.library.js_util', defaultValue: false);
  final fss = isWeb ? null : const FlutterSecureStorage();
  return SecureStorage(fss);
});

/// Marks a request that went out carrying a bearer token, so a 401 can be
/// told apart from "this endpoint needed auth and we sent none".
const _sentTokenKey = 'sentToken';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);

  final baseUrl = ApiConstants.resolvedBaseUrl;
  debugPrint('[DIO] baseUrl: $baseUrl');
  final d = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  d.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Only the credential exchanges go out unauthenticated. Public reads
        // are happy to receive a token and ignore it, whereas guessing which
        // paths are public gets it wrong: `/therapists/{id}/slots` looks
        // public by prefix but the API requires auth, so a prefix rule
        // silently broke the whole booking calendar.
        final isCredentialExchange =
            options.path.contains(ApiConstants.login) ||
                options.path.contains(ApiConstants.signup) ||
                options.path.contains(ApiConstants.health);

        if (!isCredentialExchange) {
          final token = await storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            options.extra[_sentTokenKey] = true;
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Clear the session only when a token we actually sent was rejected.
        // Clearing on every 401 meant one unauthenticated request — to an
        // endpoint that merely needed auth — silently signed the user out.
        final sentToken =
            error.requestOptions.extra[_sentTokenKey] == true;
        if (error.response?.statusCode == 401 && sentToken) {
          await storage.clearAll();
        }
        handler.next(error);
      },
    ),
  );

  if (kDebugMode) {
    d.interceptors.add(
      LogInterceptor(
        // Bodies stay off: a fortnight of slots is a few hundred entries, and
        // formatting that on the UI isolate is enough to trigger an ANR.
        requestBody: false,
        responseBody: false,
        logPrint: (o) => debugPrint('[DIO] $o'),
      ),
    );
  }

  return d;
});

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.read(dioProvider);
  return AuthApi(dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.read(authApiProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthRepositoryImpl(api: api, storage: storage);
});
