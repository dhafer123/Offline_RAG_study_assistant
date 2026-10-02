import 'package:shared_preferences/shared_preferences.dart';

/// Light or dark appearance. [system] follows the phone's setting.
enum AppThemeMode { system, light, dark }

/// User preferences that survive restarts.
abstract interface class AppSettings {
  /// Only download models on Wi-Fi. On by default (the model is ~600 MB).
  bool get wifiOnlyDownloads;
  Future<void> setWifiOnlyDownloads({required bool value});

  /// Follows the phone by default.
  AppThemeMode get themeMode;
  Future<void> setThemeMode(AppThemeMode mode);
}

class SharedPrefsAppSettings implements AppSettings {
  SharedPrefsAppSettings._(this._prefs);

  static const _wifiOnlyKey = 'wifi_only_downloads';
  static const _themeModeKey = 'theme_mode';

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPrefsAppSettings> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_wifiOnlyKey, _themeModeKey},
      ),
    );
    return SharedPrefsAppSettings._(prefs);
  }

  @override
  bool get wifiOnlyDownloads => _prefs.getBool(_wifiOnlyKey) ?? true;

  @override
  Future<void> setWifiOnlyDownloads({required bool value}) =>
      _prefs.setBool(_wifiOnlyKey, value);

  @override
  AppThemeMode get themeMode =>
      AppThemeMode.values.asNameMap()[_prefs.getString(_themeModeKey)] ??
      AppThemeMode.system;

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);
}
