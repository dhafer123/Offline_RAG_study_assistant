import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone is on an unmetered connection (Wi-Fi or Ethernet).
abstract interface class NetworkMonitor {
  Future<bool> isOnWifi();

  /// Emits when the phone moves on or off Wi-Fi.
  Stream<bool> get onWifiChanged;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnWifi() async =>
      _isUnmetered(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onWifiChanged =>
      _connectivity.onConnectivityChanged.map(_isUnmetered).distinct();

  static bool _isUnmetered(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
}
