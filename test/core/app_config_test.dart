import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/config/app_config.dart';

void main() {
  // These tests run without a --dart-define, so the compile-time override is
  // empty and the .env / fallback branches are the ones under test.

  tearDown(() {
    dotenv.clean();
  });

  group('with no .env loaded', () {
    setUp(() => dotenv.clean());

    test('falls back to a local URL, never to a hosted one', () {
      // A checkout with no .env must still run against a local backend rather
      // than silently pointing at production.
      expect(AppConfig.baseUrl, startsWith('http://'));
      expect(AppConfig.baseUrl, contains(':8000'));
      expect(AppConfig.baseUrlSource, 'built-in default');
    });

    test('the fallback matches the platform', () {
      // The Android emulator reaches the host at 10.0.2.2; everything else
      // uses localhost.
      final expected =
          defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';
      expect(AppConfig.baseUrl, expected);
    });
  });

  group('with a value in .env', () {
    void loadEnv(String contents) {
      dotenv.clean();
      dotenv.testLoad(fileInput: contents);
    }

    test('.env wins over the built-in default', () {
      loadEnv('API_BASE_URL=https://api.example.com');
      expect(AppConfig.baseUrl, 'https://api.example.com');
      expect(AppConfig.baseUrlSource, '.env');
    });

    test('a trailing slash is trimmed so paths do not double up', () {
      loadEnv('API_BASE_URL=https://api.example.com/');
      expect(AppConfig.baseUrl, 'https://api.example.com');
      expect(AppConfig.apiRoot, 'https://api.example.com/api/v1');
    });

    test('a blank value falls through to the default', () {
      loadEnv('API_BASE_URL=');
      expect(AppConfig.baseUrlSource, 'built-in default');
    });

    test('whitespace around the value is ignored', () {
      loadEnv('API_BASE_URL=  https://api.example.com  ');
      expect(AppConfig.baseUrl, 'https://api.example.com');
    });

    test('an unrelated key does not become the base URL', () {
      loadEnv('SOMETHING_ELSE=https://wrong.example.com');
      expect(AppConfig.baseUrlSource, 'built-in default');
    });
  });

  group('apiRoot', () {
    test('appends the version prefix exactly once', () {
      dotenv.clean();
      dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000');
      expect(AppConfig.apiRoot, 'http://localhost:8000/api/v1');
    });
  });

  group('load()', () {
    test('a missing .env is survivable, not fatal', () async {
      // A fresh checkout has no .env. The app must still start.
      await AppConfig.load();
      expect(AppConfig.baseUrl, isNotEmpty);
    });
  });
}
