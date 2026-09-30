import 'package:shared_preferences/shared_preferences.dart';

/// User preferences that survive restarts.
abstract interface class AppSettings {
  /// Only download models on Wi-Fi. On by default (the model is ~600 MB).
  bool get wifiOnlyDownloads;
  Future<void> setWifiOnlyDownloads({required bool value});
}

class SharedPrefsAppSettings implements AppSettings {
  SharedPrefsAppSettings._(this._prefs);

  static const _wifiOnlyKey = 'wifi_only_downloads';

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPrefsAppSettings> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_wifiOnlyKey},
      ),
    );
    return SharedPrefsAppSettings._(prefs);
  }

  @override
  bool get wifiOnlyDownloads => _prefs.getBool(_wifiOnlyKey) ?? true;

  @override
  Future<void> setWifiOnlyDownloads({required bool value}) =>
      _prefs.setBool(_wifiOnlyKey, value);
}
