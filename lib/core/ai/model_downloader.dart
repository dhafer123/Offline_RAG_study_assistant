import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.kind, this.message);

  final ModelErrorKind kind;
  final String message;

  @override
  String toString() => 'ModelDownloadException(${kind.name}): $message';
}

/// Lets the caller stop a running download.
class DownloadCancelToken {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

// An interface (not a function type) so the manager can be tested with fakes.
// ignore: one_member_abstracts
abstract interface class ModelDownloader {
  /// Downloads [url] into [partFile], resuming from the bytes already in it.
  ///
  /// Returns true when the file holds all [totalBytes], false when [cancel]
  /// stopped it (the bytes so far stay in [partFile]). Throws
  /// [ModelDownloadException] on failure.
  Future<bool> download({
    required Uri url,
    required File partFile,
    required int totalBytes,
    required DownloadCancelToken cancel,
    void Function(int receivedBytes)? onProgress,
  });
}

/// [ModelDownloader] over `dart:io` HTTP, resuming with `Range` requests.
class HttpModelDownloader implements ModelDownloader {
  HttpModelDownloader({
    HttpClient Function()? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? HttpClient.new;

  final HttpClient Function() _httpClient;

  /// For connecting, and for each wait on data once connected.
  final Duration timeout;

  static const _maxRedirects = 5;

  @override
  Future<bool> download({
    required Uri url,
    required File partFile,
    required int totalBytes,
    required DownloadCancelToken cancel,
    void Function(int receivedBytes)? onProgress,
  }) async {
    final client = _httpClient()
      ..connectionTimeout = timeout
      ..autoUncompress = false;
    // Aborts a pending connect or read as soon as the caller cancels.
    unawaited(cancel.whenCancelled.then((_) => client.close(force: true)));

    try {
      return await _download(
        client,
        url,
        partFile,
        totalBytes,
        cancel,
        onProgress ?? (_) {},
      );
    } on ModelDownloadException {
      rethrow;
    } on FileSystemException catch (e) {
      if (cancel.isCancelled) return false;
      throw ModelDownloadException(ModelErrorKind.storage, '$e');
    } on TimeoutException catch (e) {
      if (cancel.isCancelled) return false;
      throw ModelDownloadException(ModelErrorKind.network, '$e');
    } on IOException catch (e) {
      // Socket, HTTP and TLS errors, including the ones caused by cancelling.
      if (cancel.isCancelled) return false;
      throw ModelDownloadException(ModelErrorKind.network, '$e');
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _download(
    HttpClient client,
    Uri url,
    File partFile,
    int totalBytes,
    DownloadCancelToken cancel,
    void Function(int received) onProgress, {
    bool retried = false,
  }) async {
    var offset = partFile.existsSync() ? partFile.lengthSync() : 0;
    if (offset > totalBytes) {
      partFile.deleteSync();
      offset = 0;
    }
    if (offset == totalBytes) return true;

    final response = await _get(client, url, offset);
    switch (response.statusCode) {
      case HttpStatus.partialContent:
        final start = _rangeStart(
          response.headers[HttpHeaders.contentRangeHeader],
        );
        if (start != offset) {
          await response.drain<void>();
          throw ModelDownloadException(
            ModelErrorKind.server,
            'Asked for bytes from $offset, got a range starting at $start',
          );
        }
      case HttpStatus.ok:
        offset = 0; // The server ignored the range: start over.
      case HttpStatus.requestedRangeNotSatisfiable when !retried:
        // The partial file doesn't fit the server's file: start over once.
        await response.drain<void>();
        partFile.deleteSync();
        return _download(
          client,
          url,
          partFile,
          totalBytes,
          cancel,
          onProgress,
          retried: true,
        );
      default:
        await response.drain<void>();
        throw ModelDownloadException(
          ModelErrorKind.server,
          'HTTP ${response.statusCode} from ${url.host}',
        );
    }

    final sink = partFile.openWrite(
      mode: offset == 0 ? FileMode.write : FileMode.append,
    );
    var received = offset;
    try {
      await for (final chunk in response.timeout(timeout)) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (cancel.isCancelled) return false;
    if (received != totalBytes) {
      throw ModelDownloadException(
        ModelErrorKind.network,
        'Connection closed at $received of $totalBytes bytes',
      );
    }
    return true;
  }

  /// GET that follows redirects itself, so every hop keeps the Range header.
  Future<HttpClientResponse> _get(
    HttpClient client,
    Uri url,
    int offset,
  ) async {
    var uri = url;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final request = await client.getUrl(uri);
      request
        ..followRedirects = false
        ..headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final response = await request.close();
      if (!response.isRedirect) return response;

      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) break;
      uri = uri.resolve(location);
    }
    throw ModelDownloadException(
      ModelErrorKind.server,
      'Too many or invalid redirects from ${url.host}',
    );
  }

  /// Start offset from a `Content-Range: bytes <start>-<end>/<total>` header.
  static int? _rangeStart(List<String>? header) {
    final match = RegExp(r'bytes (\d+)-').firstMatch(header?.first ?? '');
    return match == null ? null : int.parse(match.group(1)!);
  }
}

/// Lower-case hex SHA-256 of the file at [path], computed off the UI isolate.
Future<String> sha256OfFile(String path) {
  return Isolate.run(() async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  });
}
