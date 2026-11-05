import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/storage/storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api.dart';
import '../models/auth_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api, required StorageService storage})
    : _api = api,
      _storage = storage;

  final AuthApi _api;
  final StorageService _storage;

  /// Runs [action], converting Dio errors into typed failures.
  Future<AppResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<AuthTokens>> login({
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _api.login(
      LoginRequestDto(email: email, password: password),
    );
    final tokens = AuthTokens(
      accessToken: response.accessToken,
      user: response.user.toEntity(),
    );
    if (tokens.hasToken) {
      await _storage.saveAccessToken(tokens.accessToken!);
    }
    return tokens;
  });

  @override
  Future<AppResult<AuthTokens>> signup({
    required String name,
    required String email,
    String? password,
    required String role,
    String? city,
    String? phone,
    String? specialty,
    String? gender,
    String? dob,
    String? license,
    int? experience,
    double? fee,
    String? referralCode,
  }) => _guard(() async {
    final response = await _api.signup(
      SignupRequestDto(
        name: name,
        email: email,
        password: password,
        role: role,
        city: city,
        phone: phone,
        specialty: specialty,
        gender: gender,
        dob: dob,
        license: license,
        experience: experience,
        fee: fee,
        referralCode: referralCode,
      ),
    );
    final tokens = AuthTokens(
      accessToken: response.accessToken,
      user: response.user.toEntity(),
    );
    // Therapist signups come back without a token on purpose — the account
    // stays locked until an admin approves it.
    if (tokens.hasToken) {
      await _storage.saveAccessToken(tokens.accessToken!);
    }
    return tokens;
  });

  @override
  Future<AppResult<User>> getCurrentUser() =>
      _guard(() async => (await _api.getMe()).toEntity());

  @override
  Future<AppResult<User>> updateProfile({
    String? name,
    String? city,
    String? phone,
    String? specialty,
  }) => _guard(() async {
    final response = await _api.updateMe(
      UserUpdateDto(name: name, city: city, phone: phone, specialty: specialty),
    );
    return response.toEntity();
  });

  @override
  Future<AppResult<void>> logout() async {
    try {
      await _api.logout();
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    } finally {
      // The local session is dropped whatever the server says — a failed
      // server-side logout must never leave the user apparently signed in.
      await _storage.clearAll();
    }
  }

  @override
  Future<AppResult<int>> sendSignupOtp({
    required String email,
    String name = '',
  }) => _guard(() async {
    final response = await _api.sendOtp(
      SendOtpRequestDto(email: email, name: name),
    );
    return response.resendAfter;
  });

  @override
  Future<AppResult<void>> verifyOtp({
    required String email,
    required String code,
    String purpose = 'signup',
  }) => _guard(() async {
    await _api.verifyOtp(
      VerifyOtpRequestDto(email: email, code: code, purpose: purpose),
    );
  });

  @override
  Future<AppResult<int>> forgotPassword({
    required String email,
    String name = '',
  }) => _guard(() async {
    final response = await _api.forgotPassword(
      ForgotPasswordRequestDto(email: email, name: name),
    );
    return response.resendAfter;
  });

  @override
  Future<AppResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _guard(() async {
    await _api.resetPassword(
      ResetPasswordRequestDto(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
  });

  @override
  Future<AppResult<String?>> getStoredToken() async {
    try {
      return Right(await _storage.getAccessToken());
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> clearTokens() async {
    try {
      await _storage.clearAll();
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
