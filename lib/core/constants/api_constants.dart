import '../config/app_config.dart';

class ApiConstants {
  ApiConstants._();

  /// Delegates to [AppConfig], which resolves --dart-define, then .env, then a
  /// platform-appropriate local default — and always appends the version
  /// prefix. The previous implementation returned a --dart-define value without
  /// `/api/v1`, so an overridden URL produced 404s on every call.
  static String get resolvedBaseUrl => AppConfig.apiRoot;

  // Auth
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  // Therapists
  static const String therapists = '/therapists';
  static String therapistById(String id) => '/therapists/$id';
  static const String therapistMe = '/therapists/me';

  // Sessions
  static const String sessions = '/sessions';
  static String sessionById(String id) => '/sessions/$id';

  // Products
  static const String products = '/products';
  static String productById(String id) => '/products/$id';

  // Cart
  static const String cart = '/cart';
  static String cartItemById(String id) => '/cart/$id';

  // Payments
  static const String payments = '/payments';
  static String paymentById(String id) => '/payments/$id';

  // Reports
  static const String reports = '/reports';
  static String reportById(String id) => '/reports/$id';

  // Health
  static const String health = '/health';
}
