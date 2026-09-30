import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/ai/model_downloader.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';

/// Serves [data] at `/model`, with switches to misbehave like real servers.
class _TestServer {
  _TestServer._(this._server, this.data) {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final Uint8List data;

  bool honorRange = true;
  int? statusOverride;

  /// Send this many body bytes, then drop the connection.
  int? dropAfter;

  /// Send this many body bytes, then go silent (connection stays open).
  int? stallAfter;

  final rangeHeaders = <String?>[];
  final _stalled = <Socket>[];

  static Future<_TestServer> start(Uint8List data) async => _TestServer._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    data,
  );

  Uri url([String path = '/model']) =>
      Uri.parse('http://127.0.0.1:${_server.port}$path');

  Future<void> close() async {
    for (final socket in _stalled) {
      socket.destroy();
    }
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.uri.path == '/redirect') {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, '/model');
      return response.close();
    }

    rangeHeaders.add(request.headers.value(HttpHeaders.rangeHeader));
    if (statusOverride case final status?) {
      response.statusCode = status;
      return response.close();
    }

    var start = 0;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null && honorRange) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (start >= data.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        return response.close();
      }
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${data.length - 1}/${data.length}',
        );
    }
    final body = data.sublist(start);
    response.contentLength = body.length;

    final cutAt = dropAfter ?? stallAfter;
    if (cutAt == null) {
      response.add(body);
      return response.close();
    }
    final socket = await response.detachSocket();
    socket.add(body.sublist(0, cutAt));
    await socket.flush();
    if (dropAfter != null) {
      socket.destroy();
    } else {
      _stalled.add(socket);
    }
  }
}

void main() {
  final data = Uint8List.fromList(List.generate(64 * 1024, (i) => i % 251));
  late _TestServer server;
  late Directory dir;
  late File part;

  setUp(() async {
    server = await _TestServer.start(data);
    dir = Directory.systemTemp.createTempSync('model_downloader_test');
    part = File('${dir.path}/model.part');
  });

  tearDown(() async {
    await server.close();
    dir.deleteSync(recursive: true);
  });

  Future<bool> download({
    Uri? url,
    DownloadCancelToken? cancel,
    void Function(int)? onProgress,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return HttpModelDownloader(timeout: timeout).download(
      url: url ?? server.url(),
      partFile: part,
      totalBytes: data.length,
      cancel: cancel ?? DownloadCancelToken(),
      onProgress: onProgress,
    );
  }

  Matcher failsWith(ModelErrorKind kind) => throwsA(
    isA<ModelDownloadException>().having((e) => e.kind, 'kind', kind),
  );

  test('downloads the whole file and reports progress', () async {
    final progress = <int>[];

    expect(await download(onProgress: progress.add), isTrue);

    expect(part.readAsBytesSync(), data);
    expect(progress.last, data.length);
    expect(server.rangeHeaders, [null]);
  });

  test('resumes from the bytes already in the part file', () async {
    part.writeAsBytesSync(data.sublist(0, 1000));

    expect(await download(), isTrue);

    expect(server.rangeHeaders, ['bytes=1000-']);
    expect(part.readAsBytesSync(), data);
  });

  test('starts over when the server ignores the range', () async {
    server.honorRange = false;
    part.writeAsBytesSync(data.sublist(0, 1000));

    expect(await download(), isTrue);

    expect(part.readAsBytesSync(), data);
  });

  test('keeps the range header across redirects', () async {
    part.writeAsBytesSync(data.sublist(0, 500));

    expect(await download(url: server.url('/redirect')), isTrue);

    expect(server.rangeHeaders, ['bytes=500-']);
    expect(part.readAsBytesSync(), data);
  });

  test('does nothing when the part file is already complete', () async {
    part.writeAsBytesSync(data);

    expect(await download(), isTrue);

    expect(server.rangeHeaders, isEmpty);
  });

  test('discards a part file larger than the model', () async {
    part.writeAsBytesSync([...data, 1, 2, 3]);

    expect(await download(), isTrue);

    expect(part.readAsBytesSync(), data);
  });

  test('starts over once when the range is not satisfiable', () async {
    // Shorter than the model, but the server's file is shorter still.
    final shortServer = await _TestServer.start(data.sublist(0, 100));
    addTearDown(shortServer.close);
    part.writeAsBytesSync(data.sublist(0, 200));

    await expectLater(
      HttpModelDownloader().download(
        url: shortServer.url(),
        partFile: part,
        totalBytes: data.length,
        cancel: DownloadCancelToken(),
      ),
      // After the restart the server sends only 100 bytes.
      failsWith(ModelErrorKind.network),
    );
    expect(shortServer.rangeHeaders, ['bytes=200-', null]);
  });

  test('HTTP errors are server failures', () async {
    server.statusOverride = HttpStatus.notFound;

    await expectLater(download(), failsWith(ModelErrorKind.server));
  });

  test(
    'a dropped connection is a network failure and keeps the bytes',
    () async {
      server.dropAfter = 10000;

      await expectLater(download(), failsWith(ModelErrorKind.network));

      expect(part.lengthSync(), 10000);
      expect(part.readAsBytesSync(), data.sublist(0, 10000));
    },
  );

  test('a stalled connection times out', () async {
    server.stallAfter = 2000;

    await expectLater(
      download(timeout: const Duration(milliseconds: 300)),
      failsWith(ModelErrorKind.network),
    );
    expect(part.lengthSync(), 2000);
  });

  test('cancelling stops the download and keeps the bytes', () async {
    server.stallAfter = 3000;
    final cancel = DownloadCancelToken();

    final result = download(
      cancel: cancel,
      onProgress: (received) {
        if (received >= 3000) cancel.cancel();
      },
    );

    expect(await result, isFalse);
    expect(part.lengthSync(), 3000);
  });

  test('connection refused is a network failure', () async {
    final url = server.url();
    await server.close();

    await expectLater(download(url: url), failsWith(ModelErrorKind.network));
  });

  test('sha256OfFile hashes the file', () async {
    part.writeAsBytesSync(data);

    expect(await sha256OfFile(part.path), sha256.convert(data).toString());
  });
}
