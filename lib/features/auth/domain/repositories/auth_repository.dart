import '../../../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<AppResult<AuthTokens>> login({
    required String email,
    required String password,
  });

  /// Creates an account. [password] is optional because therapists apply
  /// without one; the backend issues a temporary password on approval.
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
  });

  Future<AppResult<User>> getCurrentUser();

  Future<AppResult<User>> updateProfile({
    String? name,
    String? city,
    String? phone,
    String? specialty,
  });

  Future<AppResult<void>> logout();

  /// Sends a signup verification code. Returns the seconds to wait before a
  /// resend is allowed.
  Future<AppResult<int>> sendSignupOtp({required String email, String name});

  /// Verifies a code. [purpose] is `signup` or `password_reset`.
  Future<AppResult<void>> verifyOtp({
    required String email,
    required String code,
    String purpose,
  });

  Future<AppResult<int>> forgotPassword({required String email, String name});

  /// Sets a new password. The code must already have been verified through
  /// [verifyOtp] with purpose `password_reset`.
  Future<AppResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<AppResult<String?>> getStoredToken();

  Future<AppResult<void>> clearTokens();
}
