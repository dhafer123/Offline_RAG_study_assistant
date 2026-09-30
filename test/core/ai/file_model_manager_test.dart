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

  FileModelManager createManager() {
    final manager = FileModelManager(
      spec: spec,
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
      expect((manager.state as ModelReady).path, model.path);
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
}
