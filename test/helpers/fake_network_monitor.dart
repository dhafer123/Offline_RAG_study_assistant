import 'dart:async';

import 'package:offline_study_assistant/core/net/network_monitor.dart';

class FakeNetworkMonitor implements NetworkMonitor {
  FakeNetworkMonitor({this.onWifi = true});

  bool onWifi;
  final _changes = StreamController<bool>.broadcast();

  /// Simulates moving on or off Wi-Fi.
  void setWifi({required bool value}) {
    onWifi = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnWifi() async => onWifi;

  @override
  Stream<bool> get onWifiChanged => _changes.stream;
}
