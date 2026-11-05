import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/auth_models.dart';

part 'auth_api.g.dart';

/// Auth endpoints, mirroring pv-core-api/app/routers/auth.py on `main`.
///
/// Endpoints that exist only on `origin/development` (passwordless login,
/// Google OAuth, email pre-check) are deliberately absent — see the API-TODO
/// list in docs/TODO_REGISTER.md.
@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String baseUrl}) = _AuthApi;

  @POST('/auth/login')
  Future<TokenResponseDto> login(@Body() LoginRequestDto body);

  @POST('/auth/signup')
  Future<TokenResponseDto> signup(@Body() SignupRequestDto body);

  @GET('/auth/me')
  Future<UserResponseDto> getMe();

  @PUT('/auth/me')
  Future<UserResponseDto> updateMe(@Body() UserUpdateDto body);

  @POST('/auth/logout')
  Future<void> logout();

  @POST('/auth/send-otp')
  Future<OtpSentResponseDto> sendOtp(@Body() SendOtpRequestDto body);

  /// Returns `{"verified": true}`; a bad or expired code raises 400, so the
  /// body carries nothing the caller needs.
  @POST('/auth/verify-otp')
  Future<void> verifyOtp(@Body() VerifyOtpRequestDto body);

  @POST('/auth/forgot-password')
  Future<OtpSentResponseDto> forgotPassword(
    @Body() ForgotPasswordRequestDto body,
  );

  @POST('/auth/reset-password')
  Future<void> resetPassword(@Body() ResetPasswordRequestDto body);
}
