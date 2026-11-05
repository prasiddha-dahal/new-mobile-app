import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/providers.dart';

/// Current authenticated user state.
final authProvider = StateProvider<User?>((_) => null);

/// Convenience view of the signed-in user, for widgets that only need that.
final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider));

/// Auth actions provider.
final authActionsProvider = Provider<AuthActions>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return AuthActions(ref, repository);
});

class AuthActions {
  AuthActions(this._ref, AuthRepository repository)
    : _loginUseCase = LoginUseCase(repository),
      _signupUseCase = SignupUseCase(repository),
      _logoutUseCase = LogoutUseCase(repository),
      _getCurrentUserUseCase = GetCurrentUserUseCase(repository),
      _repository = repository;

  final Ref _ref;
  final LoginUseCase _loginUseCase;
  final SignupUseCase _signupUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final AuthRepository _repository;

  /// Sends a password-reset code. Returns the resend cooldown in seconds.
  Future<AppResult<int>> forgotPassword({required String email}) =>
      _repository.forgotPassword(email: email);

  /// Verifies an emailed code. [purpose] is `signup` or `password_reset`.
  Future<AppResult<void>> verifyOtp({
    required String email,
    required String code,
    String purpose = 'signup',
  }) => _repository.verifyOtp(email: email, code: code, purpose: purpose);

  Future<AppResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _repository.resetPassword(
    email: email,
    code: code,
    newPassword: newPassword,
  );

  Future<AppResult<int>> sendSignupOtp({
    required String email,
    String name = '',
  }) => _repository.sendSignupOtp(email: email, name: name);

  Future<AppResult<User>> updateProfile({
    String? name,
    String? city,
    String? phone,
    String? specialty,
  }) => _repository.updateProfile(
    name: name,
    city: city,
    phone: phone,
    specialty: specialty,
  );

  /// Writes a profile update straight into the cached user, so the account
  /// header reflects an edit without a refetch.
  void applyUser(User user) {
    _ref.read(authProvider.notifier).state = user;
  }

  Future<AppResult<AuthTokens>> login(String email, String password) async {
    final result = await _loginUseCase.call(email: email, password: password);
    result.fold(
      (l) => _ref.read(authProvider.notifier).state = null,
      (r) => _ref.read(authProvider.notifier).state = r.user,
    );
    return result;
  }

  Future<AppResult<AuthTokens>> signup({
    required String name,
    required String email,
    required String password,
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
  }) async {
    final result = await _signupUseCase.call(
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
    result.fold(
      (l) => _ref.read(authProvider.notifier).state = null,
      (r) => _ref.read(authProvider.notifier).state = r.user,
    );
    return result;
  }

  Future<AppResult<void>> logout() async {
    final result = await _logoutUseCase.call();
    _ref.read(authProvider.notifier).state = null;
    return result;
  }

  Future<AppResult<User>> getCurrentUser() async {
    final result = await _getCurrentUserUseCase.call();
    result.fold((l) => null, (r) => _ref.read(authProvider.notifier).state = r);
    return result;
  }

  Future<AppResult<String?>> getStoredToken() async {
    return _repository.getStoredToken();
  }
}
