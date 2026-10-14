import 'package:shared_preferences/shared_preferences.dart';

/// Dove le preferenze sopravvivono a un riavvio. Si legge subito, si scrive
/// senza aspettare: chi cambia un'impostazione non deve vedere attese.
abstract interface class SettingsStore {
  String? getString(String key);
  bool? getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

/// Il cassetto dei test: tiene tutto in memoria, e si perde a fine prova.
class MemorySettingsStore implements SettingsStore {
  final Map<String, Object> values;

  MemorySettingsStore([Map<String, Object>? values]) : values = values ?? {};

  @override
  String? getString(String key) => values[key] as String?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Il cassetto del telefono, con `shared_preferences`: su iOS sono le
/// `NSUserDefaults` dell'app.
class DeviceSettingsStore implements SettingsStore {
  final SharedPreferencesWithCache _prefs;

  DeviceSettingsStore._(this._prefs);

  /// Apre il cassetto e ne legge le chiavi una volta sola, all'avvio.
  static Future<DeviceSettingsStore> open(Set<String> keys) async => DeviceSettingsStore._(
        await SharedPreferencesWithCache.create(
          cacheOptions: SharedPreferencesWithCacheOptions(allowList: keys),
        ),
      );

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
