/// App-wide constants.
class AppConstants {
  AppConstants._();

  // Pagination
  static const int defaultPageSize = 100;
  static const int defaultSkip = 0;

  // Currency
  static const String currencySymbol = 'Rs ';
  static const String locale = 'en-IN';

  // Date formats
  static const String dateFormat = 'EEE, d MMM';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'EEE, d MMM · HH:mm';

  // Secure storage
  static const String storageKeyAccessToken = 'access_token';
  static const String storageKeyRefreshToken = 'refresh_token';
  static const String storageKeyEmail = 'email';
  static const String storageKeyPassword = 'password';
}
