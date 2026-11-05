import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, non-session preferences.
///
/// Deliberately separate from [StorageService]: that one holds the session,
/// and `clearAll()` wipes it on logout. A preference like the chosen language
/// has to survive a logout — someone who picked Nepali should not be handed
/// English back just for signing out — so it cannot live there.
///
/// Reads and writes are best-effort. A device with an unreadable or full
/// preference store is an ordinary situation, not a crash: the caller keeps
/// its in-memory value and simply loses persistence for that launch.
abstract class PreferencesStorage {
  Future<String?> readString(String key);
  Future<void> writeString(String key, String value);
}

/// Backed by `shared_preferences` — plain, non-secret, survives reinstall-less
/// upgrades. Nothing here is sensitive; secrets belong in `SecureStorage`.
class SharedPreferencesStorage implements PreferencesStorage {
  const SharedPreferencesStorage();

  @override
  Future<String?> readString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // The choice still applies for this session even if it cannot persist.
    }
  }
}

/// In-memory implementation for tests and for platforms without a store.
///
/// Seed it via [seed] to stand in for "the user chose this last launch".
class InMemoryPreferencesStorage implements PreferencesStorage {
  InMemoryPreferencesStorage([Map<String, String>? seed])
    : _store = {...?seed};

  final Map<String, String> _store;

  @override
  Future<String?> readString(String key) async => _store[key];

  @override
  Future<void> writeString(String key, String value) async {
    _store[key] = value;
  }
}

/// Override this in tests with an [InMemoryPreferencesStorage].
final preferencesStorageProvider = Provider<PreferencesStorage>(
  (_) => const SharedPreferencesStorage(),
);

/// Keys written through [PreferencesStorage]. Kept together so a rename is a
/// single edit and a collision is visible.
class PreferenceKeys {
  PreferenceKeys._();

  /// Language tag of the locale the user picked, e.g. `en` or `ne`.
  ///
  /// Same key the pre-l10n language toggle used, so anyone upgrading keeps
  /// the language they already chose instead of being reset to English.
  static const String locale = 'app_language';

  /// Ids of the sessions whose "How was your visit?" prompt the patient
  /// dismissed, comma-separated. Session ids are unique across accounts, so
  /// nothing here needs to be keyed to a user.
  static const String dismissedReviewPrompts = 'dismissed_review_prompts';
}
