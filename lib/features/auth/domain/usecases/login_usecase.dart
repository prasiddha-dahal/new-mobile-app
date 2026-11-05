import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<AuthTokens>> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }
}

class SignupUseCase {
  const SignupUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<AuthTokens>> call({
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
  }) {
    return _repository.signup(
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
    );
  }
}

class LogoutUseCase {
  const LogoutUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<void>> call() => _repository.logout();
}

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<User>> call() => _repository.getCurrentUser();
}

/// Sends a signup verification code, returning the resend cooldown in seconds.
class SendSignupOtpUseCase {
  const SendSignupOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<int>> call({required String email, String name = ''}) =>
      _repository.sendSignupOtp(email: email, name: name);
}

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<void>> call({
    required String email,
    required String code,
    String purpose = 'signup',
  }) => _repository.verifyOtp(email: email, code: code, purpose: purpose);
}

class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<int>> call({required String email, String name = ''}) =>
      _repository.forgotPassword(email: email, name: name);
}

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppResult<void>> call({
    required String email,
    required String code,
    required String newPassword,
  }) => _repository.resetPassword(
    email: email,
    code: code,
    newPassword: newPassword,
  );
}
