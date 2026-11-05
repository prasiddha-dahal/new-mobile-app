import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration.
///
/// The API base URL is resolved from three sources, highest priority first:
///
/// 1. `--dart-define=API_BASE_URL=...` — compile-time, wins over everything.
///    Useful for CI and release builds where a `.env` may not be present.
/// 2. `API_BASE_URL` in the bundled `.env` — runtime, so it can change without
///    a rebuild. This is the normal way to point at a deployed API.
/// 3. A built-in local default, so a checkout with no `.env` still runs against
///    a backend on the developer's own machine.
///
/// The local default differs per target, because "localhost" means something
/// different on each: on the Android emulator the host machine is `10.0.2.2`
/// (`localhost` is the emulated device itself), while web, desktop and the iOS
/// simulator reach the host as `localhost`. A physical Android device also uses
/// `localhost`, tunnelled by `adb reverse tcp:8000 tcp:8000`.
class AppConfig {
  AppConfig._();

  /// Compile-time override: `flutter run --dart-define=API_BASE_URL=...`
  static const String _compileTimeOverride =
      String.fromEnvironment('API_BASE_URL');

  static const String _localAndroid = 'http://201.18.206.58:8000';
  static const String _localOther = 'http://localhost:8000';

  /// Loads `.env`. Call once from `main()` before the first [baseUrl] read.
  ///
  /// Never throws: a missing `.env` is an ordinary state for a fresh checkout,
  /// and the local fallback covers it.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          '[config] no .env found — falling back to $_localDefault. '
          'Copy .env.example to .env to point somewhere else.',
        );
      }
    }
  }

  /// The value from `.env`, or null when absent, blank, or not yet loaded.
  ///
  /// Asks dotenv whether it holds anything rather than tracking a separate
  /// "did load succeed" flag — one source of truth, and it means a test can
  /// seed values with `dotenv.testLoad` without going through [load].
  static String? get _fromEnvFile {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.maybeGet('API_BASE_URL')?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String get _localDefault {
    if (kIsWeb) return _localOther;
    return defaultTargetPlatform == TargetPlatform.android
        ? _localAndroid
        : _localOther;
  }

  static String get baseUrl {
    if (_compileTimeOverride.isNotEmpty) {
      return _stripTrailingSlash(_compileTimeOverride);
    }
    final fromFile = _fromEnvFile;
    if (fromFile != null) return _stripTrailingSlash(fromFile);
    return _localDefault;
  }

  /// Which of the three sources [baseUrl] came from. Debug display only.
  static String get baseUrlSource {
    if (_compileTimeOverride.isNotEmpty) return '--dart-define';
    if (_fromEnvFile != null) return '.env';
    return 'built-in default';
  }

  /// Turns a media path the API handed back into a URL that can be fetched.
  ///
  /// Uploaded files are returned as server-relative paths --
  /// `/api/v1/uploads/patients/<id>/photo-<hex>.jpg?name=...` -- which are
  /// meaningless to the HTTP client without the host. Anything already
  /// absolute is returned as it is.
  static String resolveMediaUrl(String path) {
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$baseUrl${value.startsWith('/') ? '' : '/'}$value';
  }

  /// All endpoints live under this prefix.
  static const String apiPrefix = '/api/v1';

  static String get apiRoot => '$baseUrl$apiPrefix';

  /// Generous enough for a slow mobile connection in Nepal, without leaving a
  /// genuinely dead server spinning for a minute.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 20);

  /// A request slower than this is assumed to be a cold start, so the UI can say
  /// "waking the server up" instead of showing a bare spinner.
  static const Duration coldStartHint = Duration(seconds: 6);

  static String _stripTrailingSlash(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;
}
