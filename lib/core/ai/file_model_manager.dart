import 'dart:async';
import 'dart:io';

import 'package:offline_study_assistant/core/ai/model_downloader.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/core/ai/model_spec.dart';
import 'package:offline_study_assistant/core/net/network_monitor.dart';

/// [ModelManager] that keeps a bundle of model files in one directory and
/// downloads them one after the other, reporting their combined progress.
///
/// Per file: `<name>` once verified, `<name>.part` while downloading, and
/// `<name>.sha256`, a marker saying the file was verified (so startup doesn't
/// hash 700 MB every time).
class FileModelManager implements ModelManager {
  FileModelManager({
    required List<ModelSpec> specs,
    required String directory,
    required ModelDownloader downloader,
    required NetworkMonitor network,
    required bool Function() wifiOnly,
    Future<String> Function(String path) hashFile = sha256OfFile,
    this.progressInterval = const Duration(milliseconds: 200),
  }) : assert(specs.isNotEmpty, 'nothing to download'),
       specs = List.unmodifiable(specs),
       _directory = directory,
       _downloader = downloader,
       _network = network,
       _wifiOnly = wifiOnly,
       _hashFile = hashFile;

  final List<ModelSpec> specs;
  final String _directory;
  final ModelDownloader _downloader;
  final NetworkMonitor _network;
  final bool Function() _wifiOnly;
  final Future<String> Function(String path) _hashFile;

  /// Minimum time between two progress states.
  final Duration progressInterval;

  final _states = StreamController<ModelState>.broadcast();
  ModelState _state = const ModelChecking();
  DownloadCancelToken? _cancel;
  Future<void>? _running;

  int get _totalBytes => specs.fold(0, (sum, s) => sum + s.sizeBytes);

  File _file(ModelSpec spec) => File('$_directory/${spec.fileName}');
  File _part(ModelSpec spec) => File('${_file(spec).path}.part');
  File _marker(ModelSpec spec) => File('${_file(spec).path}.sha256');

  @override
  ModelState get state => _state;

  @override
  Stream<ModelState> get states => _states.stream;

  void _emit(ModelState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  @override
  Future<void> refresh() async {
    if (_running != null) return;
    _emit(const ModelChecking());
    try {
      var allReady = true;
      for (final spec in specs) {
        if (!await _checkOnDisk(spec)) allReady = false;
      }
      if (allReady) return _emit(const ModelReady());
      _emit(
        ModelNotDownloaded(
          partialBytes: _bytesOnDisk(),
          totalBytes: _totalBytes,
        ),
      );
    } on FileSystemException catch (e) {
      _fail(ModelErrorKind.storage, '$e');
    }
  }

  /// Whether [spec]'s file is complete and verified. A wrong file is
  /// deleted; a right one without a marker (copied by hand) is hashed once.
  Future<bool> _checkOnDisk(ModelSpec spec) async {
    final file = _file(spec);
    final marker = _marker(spec);
    if (!file.existsSync()) return false;
    if (file.lengthSync() == spec.sizeBytes) {
      if (_isMarkedVerified(spec)) return true;
      _emit(const ModelChecking(verifying: true));
      if (await _hashFile(file.path) == spec.sha256) {
        marker.writeAsStringSync(spec.sha256);
        return true;
      }
    }
    file.deleteSync();
    if (marker.existsSync()) marker.deleteSync();
    return false;
  }

  @override
  Future<void> download() {
    if (_state is ModelReady) return Future.value();
    return _running ??= _download().whenComplete(() => _running = null);
  }

  Future<void> _download() async {
    final wifiOnly = _wifiOnly();
    if (wifiOnly && !await _network.isOnWifi()) {
      return _fail(ModelErrorKind.wifiRequired);
    }

    final cancel = _cancel = DownloadCancelToken();
    var lostWifi = false;
    final wifiChanges = wifiOnly
        ? _network.onWifiChanged.listen((onWifi) {
            if (onWifi) return;
            lostWifi = true;
            cancel.cancel();
          })
        : null;

    try {
      Directory(_directory).createSync(recursive: true);
      for (final spec in specs) {
        if (_isComplete(spec)) continue;
        final done = await _downloadOne(spec, cancel);
        if (done) continue;
        // Cancelled: paused by the user, or Wi-Fi was lost.
        if (lostWifi) return _fail(ModelErrorKind.wifiRequired);
        return _emit(
          ModelNotDownloaded(
            partialBytes: _bytesOnDisk(),
            totalBytes: _totalBytes,
          ),
        );
      }
      _emit(const ModelReady());
    } on ModelDownloadException catch (e) {
      _fail(e.kind, e.message);
    } on FileSystemException catch (e) {
      _fail(ModelErrorKind.storage, '$e');
    } finally {
      await wifiChanges?.cancel();
      _cancel = null;
    }
  }

  /// Downloads and verifies one file. False if cancelled.
  Future<bool> _downloadOne(ModelSpec spec, DownloadCancelToken cancel) async {
    // Bytes of the files before this one, already complete.
    final before = _bytesOnDisk() - _partBytes(spec);
    final part = _part(spec);
    _emit(
      ModelDownloading(
        receivedBytes: _bytesOnDisk(),
        totalBytes: _totalBytes,
      ),
    );
    final sinceProgress = Stopwatch()..start();
    final completed = await _downloader.download(
      url: spec.url,
      partFile: part,
      totalBytes: spec.sizeBytes,
      cancel: cancel,
      onProgress: (received) {
        if (sinceProgress.elapsed < progressInterval) return;
        sinceProgress.reset();
        _emit(
          ModelDownloading(
            receivedBytes: before + received,
            totalBytes: _totalBytes,
          ),
        );
      },
    );
    if (!completed) return false;

    _emit(const ModelChecking(verifying: true));
    final hash = await _hashFile(part.path);
    if (hash != spec.sha256) {
      part.deleteSync();
      throw ModelDownloadException(
        ModelErrorKind.checksum,
        '${spec.fileName}: expected ${spec.sha256}, got $hash',
      );
    }
    part.renameSync(_file(spec).path);
    _marker(spec).writeAsStringSync(spec.sha256);
    return true;
  }

  void _fail(ModelErrorKind kind, [String? detail]) {
    _emit(
      ModelFailed(
        kind,
        partialBytes: _bytesOnDisk(),
        totalBytes: _totalBytes,
        detail: detail,
      ),
    );
  }

  bool _isMarkedVerified(ModelSpec spec) {
    final marker = _marker(spec);
    return marker.existsSync() &&
        marker.readAsStringSync().trim() == spec.sha256;
  }

  bool _isComplete(ModelSpec spec) =>
      _file(spec).existsSync() && _isMarkedVerified(spec);

  /// Complete files plus the parts of interrupted ones: where a download
  /// resumes from.
  int _bytesOnDisk() {
    var bytes = 0;
    for (final spec in specs) {
      bytes += _isComplete(spec) ? spec.sizeBytes : _partBytes(spec);
    }
    return bytes;
  }

  int _partBytes(ModelSpec spec) {
    try {
      final part = _part(spec);
      return part.existsSync() ? part.lengthSync() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<void> pause() async {
    _cancel?.cancel();
    await _running;
  }

  @override
  Future<void> dispose() async {
    await pause();
    await _states.close();
  }
}
