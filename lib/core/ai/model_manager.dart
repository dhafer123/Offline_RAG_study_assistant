import 'package:flutter/foundation.dart';

/// Where a model file stands on this device.
@immutable
sealed class ModelState {
  const ModelState();
}

/// Checking the file on disk (at startup, or the checksum after a download).
final class ModelChecking extends ModelState {
  const ModelChecking({this.verifying = false});

  /// True while hashing the whole file, which takes a few seconds.
  final bool verifying;
}

final class ModelNotDownloaded extends ModelState {
  const ModelNotDownloaded({required this.totalBytes, this.partialBytes = 0});

  /// Bytes kept from an interrupted download; the next download resumes here.
  final int partialBytes;
  final int totalBytes;
}

final class ModelDownloading extends ModelState {
  const ModelDownloading({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
}

final class ModelReady extends ModelState {
  const ModelReady(this.path);

  final String path;
}

enum ModelErrorKind {
  /// Wi-Fi only is on and the phone isn't on Wi-Fi.
  wifiRequired,

  /// No connection, timeout, or the connection dropped.
  network,

  /// The server answered with an unexpected HTTP status.
  server,

  /// The downloaded file doesn't match the expected checksum.
  checksum,

  /// Couldn't write the file (e.g. the phone is out of storage).
  storage,
}

final class ModelFailed extends ModelState {
  const ModelFailed(
    this.kind, {
    required this.totalBytes,
    this.partialBytes = 0,
    this.detail,
  });

  final ModelErrorKind kind;

  /// Bytes kept for a resume, as in [ModelNotDownloaded].
  final int partialBytes;
  final int totalBytes;

  /// Technical detail for logs, not for the UI.
  final String? detail;
}

/// Downloads a model file once, verifies it, and reports where it stands.
///
/// The only component allowed to use the network at runtime.
abstract interface class ModelManager {
  ModelState get state;

  /// Emits every state change.
  Stream<ModelState> get states;

  /// Looks at the file on disk and updates [state]. Call once at startup.
  Future<void> refresh();

  /// Starts the download, or resumes an interrupted one. Completes when the
  /// download is ready, failed, or was paused. Does nothing if the model is
  /// ready or already downloading.
  Future<void> download();

  /// Stops the download and keeps the bytes received so far.
  Future<void> pause();

  Future<void> dispose();
}
