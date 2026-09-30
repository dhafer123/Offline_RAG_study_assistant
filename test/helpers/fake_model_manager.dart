import 'dart:async';

import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/core/settings/app_settings.dart';

/// [ModelManager] whose state tests set directly.
class FakeModelManager implements ModelManager {
  FakeModelManager([this._state = const ModelReady('/models/model.litertlm')]);

  ModelState _state;
  final _states = StreamController<ModelState>.broadcast();
  int downloadCalls = 0;
  int pauseCalls = 0;

  void emit(ModelState state) {
    _state = state;
    _states.add(state);
  }

  @override
  ModelState get state => _state;

  @override
  Stream<ModelState> get states => _states.stream;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> download() async => downloadCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> dispose() => _states.close();
}

class FakeAppSettings implements AppSettings {
  FakeAppSettings({this.wifiOnlyDownloads = true});

  @override
  bool wifiOnlyDownloads;

  @override
  Future<void> setWifiOnlyDownloads({required bool value}) async =>
      wifiOnlyDownloads = value;
}
