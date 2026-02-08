import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";

/// defines how to respond to matched requests.
sealed class Reply {
  const Reply();

  /// replies with a JSON response.
  ///
  /// will set `content-type: application/json`;
  /// **note** this takes precedence over any `content-type` you set in `headers`.
  ///
  /// ```dart
  /// Reply.json({"id": 1, "name": "John"})
  /// Reply.json({"error": "Not found"}, status: 404)
  /// ```
  const factory Reply.json(
    Object? data, {
    int status,
    Map<String, List<String>> headers,
  }) = JsonReply;

  /// reply with a dynamic JSON response based on the request.
  ///
  /// will set `content-type: application/json`;
  /// **note** this takes precedence over any `content-type` you set in `headers`.
  ///
  /// ```dart
  /// Reply.jsonWith((options, request) {
  ///   final request = jsonDecode(utf8.decode(body ?? []));
  ///   return {"echoed": request};
  /// })
  /// ```
  const factory Reply.jsonWith(
    FutureOr<Object?> Function(RequestOptions options) callback, {
    int status,
    Map<String, List<String>> headers,
  }) = JsonWithReply;

  /// reply with a plain text response.
  ///
  /// will set `content-type: text/plain`;
  /// **note** this takes precedence over any `content-type` you set in `headers`.
  ///
  /// ```dart
  /// Reply.text("OK")
  /// Reply.text("Not Found", status: 404)
  /// ```
  const factory Reply.text(
    String text, {
    int status,
    Map<String, List<String>> headers,
  }) = TextReply;

  /// reply with raw bytes.
  ///
  /// use this for binary responses like images or files.
  ///
  /// `contentType` is required - you must specify what kind of bytes you're returning.
  /// `headers` is optional for additional headers (content-type is set via `contentType`).
  ///
  /// **note** `contentType` takes precedence over any `content-type` you set in `headers`.
  ///
  /// ```dart
  /// Reply.bytes(pngBytes, contentType: "image/png")
  /// Reply.bytes(pdfBytes, contentType: "application/pdf", headers: {"x-custom": ["value"]})
  /// ```
  const factory Reply.bytes(
    Uint8List bytes, {
    required String contentType,
    int status,
    Map<String, List<String>> headers,
  }) = BytesReply;

  /// reply with a fully custom response builder.
  ///
  /// use this escape hatch when other reply types don't fit your needs.
  /// you get full control over the response, including access to the request stream.
  ///
  /// ```dart
  /// Reply.custom((options, requestStream) async {
  ///   final body = await requestStream?.fold<List<int>>(
  ///     [],
  ///     (acc, chunk) => acc..addAll(chunk),
  ///   );
  ///   return ResponseBody.fromBytes(
  ///     Uint8List.fromList(body ?? []),
  ///     200,
  ///     headers: {"content-type": ["application/octet-stream"]},
  ///   );
  /// })
  /// ```
  const factory Reply.custom(
    Future<ResponseBody> Function(
      RequestOptions options,
      Stream<Uint8List>? requestStream,
    ) builder,
  ) = CustomReply;

  /// builds the response body.
  Future<ResponseBody> build(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  );
}

final class JsonReply extends Reply {
  const JsonReply(this.data, {this.status = 200, this.headers = const {}});
  final Object? data;
  final int status;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> build(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    return ResponseBody.fromBytes(
      encodeJson(data),
      status,
      headers: {
        ...headers,
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

final class JsonWithReply extends Reply {
  const JsonWithReply(
    this.callback, {
    this.status = 200,
    this.headers = const {},
  });
  final FutureOr<Object?> Function(RequestOptions options) callback;
  final int status;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> build(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    final data = await callback(options);
    return ResponseBody.fromBytes(
      encodeJson(data),
      status,
      headers: {
        ...headers,
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

final class TextReply extends Reply {
  const TextReply(this.text, {this.status = 200, this.headers = const {}});
  final String text;
  final int status;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> build(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode(text)),
      status,
      headers: {
        ...headers,
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }
}

final class BytesReply extends Reply {
  const BytesReply(
    this.bytes, {
    required this.contentType,
    this.status = 200,
    this.headers = const {},
  });
  final Uint8List bytes;
  final String contentType;
  final int status;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> build(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        ...headers,
        Headers.contentTypeHeader: [contentType],
      },
    );
  }
}

final class CustomReply extends Reply {
  const CustomReply(this.builder);
  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) builder;

  @override
  Future<ResponseBody> build(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) {
    return builder(options, requestStream);
  }
}

Uint8List encodeJson(Object? data) {
  if (data == null) return Uint8List(0);
  return Uint8List.fromList(utf8.encode(jsonEncode(data)));
}
