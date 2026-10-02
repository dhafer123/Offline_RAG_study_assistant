import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/ai/file_model_manager.dart';
import 'package:offline_study_assistant/core/ai/model_downloader.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/core/ai/model_spec.dart';

import '../../helpers/fake_network_monitor.dart';

class _FakeDownloader implements ModelDownloader {
  _FakeDownloader(this.behavior);

  Future<bool> Function(
    File partFile,
    DownloadCancelToken cancel,
    void Function(int)? onProgress,
  )
  behavior;
  int calls = 0;

  @override
  Future<bool> download({
    required Uri url,
    required File partFile,
    required int totalBytes,
    required DownloadCancelToken cancel,
    void Function(int receivedBytes)? onProgress,
  }) {
    calls++;
    return behavior(partFile, cancel, onProgress);
  }
}

void main() {
  final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
  final spec = ModelSpec(
    fileName: 'model.litertlm',
    url: Uri.parse('https://example.com/model.litertlm'),
    sizeBytes: data.length,
    sha256: sha256.convert(data).toString(),
  );

  late Directory dir;
  late File model;
  late File part;
  late File marker;
  late FakeNetworkMonitor network;
  late _FakeDownloader downloader;
  late bool wifiOnly;
  late int hashCalls;
  late List<ModelState> states;

  /// Writes the rest of [data] after what's already in the part file.
  Future<bool> completes(
    File partFile,
    DownloadCancelToken cancel,
    void Function(int)? onProgress,
  ) async {
    final existing = partFile.existsSync() ? partFile.lengthSync() : 0;
    partFile.writeAsBytesSync(data.sublist(existing), mode: FileMode.append);
    onProgress?.call(data.length);
    return true;
  }

  FileModelManager createManager({List<ModelSpec>? specs}) {
    final manager = FileModelManager(
      specs: specs ?? [spec],
      directory: dir.path,
      downloader: downloader,
      network: network,
      wifiOnly: () => wifiOnly,
      hashFile: (path) async {
        hashCalls++;
        return sha256.convert(File(path).readAsBytesSync()).toString();
      },
      progressInterval: Duration.zero,
    );
    manager.states.listen(states.add);
    addTearDown(manager.dispose);
    return manager;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('file_model_manager_test');
    model = File('${dir.path}/model.litertlm');
    part = File('${model.path}.part');
    marker = File('${model.path}.sha256');
    network = FakeNetworkMonitor();
    downloader = _FakeDownloader(completes);
    wifiOnly = true;
    hashCalls = 0;
    states = [];
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('refresh', () {
    test('nothing on disk: not downloaded', () async {
      final manager = createManager();

      await manager.refresh();

      expect(
        manager.state,
        isA<ModelNotDownloaded>()
            .having((s) => s.partialBytes, 'partialBytes', 0)
            .having((s) => s.totalBytes, 'totalBytes', data.length),
      );
    });

    test('an interrupted download is resumable', () async {
      part.writeAsBytesSync(data.sublist(0, 300));
      final manager = createManager();

      await manager.refresh();

      expect(
        manager.state,
        isA<ModelNotDownloaded>().having(
          (s) => s.partialBytes,
          'partialBytes',
          300,
        ),
      );
    });

    test('a verified file is ready without hashing it again', () async {
      model.writeAsBytesSync(data);
      marker.writeAsStringSync(spec.sha256);
      final manager = createManager();

      await manager.refresh();

      expect(manager.state, isA<ModelReady>());
      expect(hashCalls, 0);
    });

    test('an unverified file is hashed once, then marked', () async {
      model.writeAsBytesSync(data);
      final manager = createManager();

      await manager.refresh();
      await pumpEventQueue();

      expect(manager.state, isA<ModelReady>());
      expect(hashCalls, 1);
      expect(marker.readAsStringSync(), spec.sha256);
      expect(
        states,
        contains(
          isA<ModelChecking>().having((s) => s.verifying, 'verifying', true),
        ),
      );
    });

    test('a corrupted file is deleted', () async {
      model.writeAsBytesSync(Uint8List(data.length));
      final manager = createManager();

      await manager.refresh();

      expect(manager.state, isA<ModelNotDownloaded>());
      expect(model.existsSync(), isFalse);
    });

    test('a file of the wrong size is deleted without hashing', () async {
      model.writeAsBytesSync(data.sublist(0, 10));
      marker.writeAsStringSync(spec.sha256);
      final manager = createManager();

      await manager.refresh();

      expect(manager.state, isA<ModelNotDownloaded>());
      expect(model.existsSync(), isFalse);
      expect(marker.existsSync(), isFalse);
      expect(hashCalls, 0);
    });
  });

  group('download', () {
    test('downloads, verifies and marks the model ready', () async {
      final manager = createManager();

      await manager.download();
      await pumpEventQueue();

      expect(manager.state, isA<ModelReady>());
      expect(model.readAsBytesSync(), data);
      expect(part.existsSync(), isFalse);
      expect(marker.readAsStringSync(), spec.sha256);
      expect(states, [
        isA<ModelDownloading>(),
        isA<ModelDownloading>().having(
          (s) => s.receivedBytes,
          'receivedBytes',
          data.length,
        ),
        isA<ModelChecking>().having((s) => s.verifying, 'verifying', true),
        isA<ModelReady>(),
      ]);
    });

    test('resumes from the part file', () async {
      part.writeAsBytesSync(data.sublist(0, 400));
      final manager = createManager();

      await manager.download();
      await pumpEventQueue();

      expect(
        states.first,
        isA<ModelDownloading>().having(
          (s) => s.receivedBytes,
          'receivedBytes',
          400,
        ),
      );
      expect(model.readAsBytesSync(), data);
    });

    test('waits for Wi-Fi when Wi-Fi only is on', () async {
      network.onWifi = false;
      final manager = createManager();

      await manager.download();

      expect(
        manager.state,
        isA<ModelFailed>().having(
          (s) => s.kind,
          'kind',
          ModelErrorKind.wifiRequired,
        ),
      );
      expect(downloader.calls, 0);
    });

    test('uses mobile data when Wi-Fi only is off', () async {
      network.onWifi = false;
      wifiOnly = false;
      final manager = createManager();

      await manager.download();

      expect(manager.state, isA<ModelReady>());
    });

    test('stops when Wi-Fi drops mid-download, keeping the bytes', () async {
      downloader.behavior = (partFile, cancel, onProgress) async {
        partFile.writeAsBytesSync(data.sublist(0, 250));
        network.setWifi(value: false);
        await cancel.whenCancelled;
        return false;
      };
      final manager = createManager();

      await manager.download();

      expect(
        manager.state,
        isA<ModelFailed>()
            .having((s) => s.kind, 'kind', ModelErrorKind.wifiRequired)
            .having((s) => s.partialBytes, 'partialBytes', 250),
      );
    });

    test('a checksum mismatch deletes the file', () async {
      downloader.behavior = (partFile, cancel, onProgress) async {
        partFile.writeAsBytesSync(Uint8List(data.length));
        return true;
      };
      final manager = createManager();

      await manager.download();

      expect(
        manager.state,
        isA<ModelFailed>()
            .having((s) => s.kind, 'kind', ModelErrorKind.checksum)
            .having((s) => s.partialBytes, 'partialBytes', 0),
      );
      expect(part.existsSync(), isFalse);
      expect(model.existsSync(), isFalse);
    });

    test('a network failure keeps the bytes for a resume', () async {
      downloader.behavior = (partFile, cancel, onProgress) async {
        partFile.writeAsBytesSync(data.sublist(0, 600));
        throw const ModelDownloadException(ModelErrorKind.network, 'reset');
      };
      final manager = createManager();

      await manager.download();

      expect(
        manager.state,
        isA<ModelFailed>()
            .having((s) => s.kind, 'kind', ModelErrorKind.network)
            .having((s) => s.partialBytes, 'partialBytes', 600)
            .having((s) => s.detail, 'detail', 'reset'),
      );

      // Retrying resumes and finishes.
      downloader.behavior = completes;
      await manager.download();
      expect(manager.state, isA<ModelReady>());
      expect(model.readAsBytesSync(), data);
    });

    test('pause keeps the bytes and returns to not downloaded', () async {
      final started = Completer<void>();
      downloader.behavior = (partFile, cancel, onProgress) async {
        partFile.writeAsBytesSync(data.sublist(0, 100));
        started.complete();
        await cancel.whenCancelled;
        return false;
      };
      final manager = createManager();

      final running = manager.download();
      await started.future;
      await manager.pause();
      await running;

      expect(
        manager.state,
        isA<ModelNotDownloaded>().having(
          (s) => s.partialBytes,
          'partialBytes',
          100,
        ),
      );
    });

    test('a second call while downloading joins the first', () async {
      final release = Completer<void>();
      downloader.behavior = (partFile, cancel, onProgress) async {
        await release.future;
        return completes(partFile, cancel, onProgress);
      };
      final manager = createManager();

      final first = manager.download();
      final second = manager.download();
      release.complete();
      await Future.wait([first, second]);

      expect(downloader.calls, 1);
      expect(manager.state, isA<ModelReady>());
    });

    test('does nothing when the model is ready', () async {
      model.writeAsBytesSync(data);
      marker.writeAsStringSync(spec.sha256);
      final manager = createManager();
      await manager.refresh();

      await manager.download();

      expect(downloader.calls, 0);
    });
  });

  group('a bundle of files', () {
    // The LLM and the embedder are separate files downloaded one after the
    // other, with one combined progress.
    final second = Uint8List.fromList(List.generate(500, (i) => (i * 7) % 256));
    final secondSpec = ModelSpec(
      fileName: 'embedder.tflite',
      url: Uri.parse('https://example.com/embedder.tflite'),
      sizeBytes: second.length,
      sha256: sha256.convert(second).toString(),
    );
    final total = data.length + second.length;
    late File secondFile;
    late List<String> downloaded;

    /// Completes each file with its own bytes.
    Future<bool> completesEach(
      File partFile,
      DownloadCancelToken cancel,
      void Function(int)? onProgress,
    ) async {
      final bytes = partFile.path.contains('embedder') ? second : data;
      downloaded.add(partFile.uri.pathSegments.last);
      final existing = partFile.existsSync() ? partFile.lengthSync() : 0;
      partFile.writeAsBytesSync(bytes.sublist(existing), mode: FileMode.append);
      onProgress?.call(bytes.length);
      return true;
    }

    setUp(() {
      secondFile = File('${dir.path}/embedder.tflite');
      downloaded = [];
      downloader.behavior = completesEach;
    });

    test('downloads every file in order, with combined progress', () async {
      final manager = createManager(specs: [spec, secondSpec]);
      await manager.refresh();
      expect(
        manager.state,
        isA<ModelNotDownloaded>().having((s) => s.totalBytes, 'total', total),
      );

      await manager.download();

      expect(downloaded, ['model.litertlm.part', 'embedder.tflite.part']);
      expect(manager.state, isA<ModelReady>());
      expect(secondFile.readAsBytesSync(), second);
      expect(File('${secondFile.path}.sha256').existsSync(), isTrue);
      final progress = states
          .whereType<ModelDownloading>()
          .map((s) => s.receivedBytes)
          .toList();
      expect(progress, containsAllInOrder([data.length, total]));
      expect(
        states.whereType<ModelDownloading>().map((s) => s.totalBytes).toSet(),
        {total},
      );
    });

    test('only the missing files are downloaded', () async {
      model.writeAsBytesSync(data);
      marker.writeAsStringSync(spec.sha256);
      final manager = createManager(specs: [spec, secondSpec]);

      await manager.refresh();
      expect(
        manager.state,
        isA<ModelNotDownloaded>().having(
          (s) => s.partialBytes,
          'partialBytes',
          data.length,
        ),
      );
      await manager.download();

      expect(downloaded, ['embedder.tflite.part']);
      expect(manager.state, isA<ModelReady>());
    });

    test('a pause in the second file resumes there', () async {
      final paused = Completer<void>();
      downloader.behavior = (partFile, cancel, onProgress) async {
        if (!partFile.path.contains('embedder')) {
          return completesEach(partFile, cancel, onProgress);
        }
        partFile.writeAsBytesSync(second.sublist(0, 200));
        paused.complete();
        await cancel.whenCancelled;
        return false;
      };
      final manager = createManager(specs: [spec, secondSpec]);
      final running = manager.download();
      await paused.future;

      await manager.pause();
      await running;

      expect(
        manager.state,
        isA<ModelNotDownloaded>().having(
          (s) => s.partialBytes,
          'partialBytes',
          data.length + 200,
        ),
      );

      downloader.behavior = completesEach;
      await manager.download();

      expect(downloaded, ['model.litertlm.part', 'embedder.tflite.part']);
      expect(manager.state, isA<ModelReady>());
      expect(secondFile.readAsBytesSync(), second);
    });

    test('a bad second file fails the checksum and keeps the first', () async {
      downloader.behavior = (partFile, cancel, onProgress) async {
        if (!partFile.path.contains('embedder')) {
          return completesEach(partFile, cancel, onProgress);
        }
        partFile.writeAsBytesSync(Uint8List(second.length));
        return true;
      };
      final manager = createManager(specs: [spec, secondSpec]);

      await manager.download();

      expect(
        manager.state,
        isA<ModelFailed>()
            .having((s) => s.kind, 'kind', ModelErrorKind.checksum)
            .having((s) => s.partialBytes, 'partialBytes', data.length)
            .having((s) => s.detail, 'detail', contains('embedder.tflite')),
      );
      expect(model.existsSync(), isTrue);
      expect(File('${secondFile.path}.part').existsSync(), isFalse);
    });
  });
}
