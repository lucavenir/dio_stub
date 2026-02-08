import "dart:typed_data";

import "package:dio/dio.dart";

import "matcher.dart";
import "reply.dart";

/// a HTTP client adapter meant to be used for testing Dio requests.
///
/// Example:
/// ```dart
/// final adapter = DioStub()
///   ..on(
///     matcher: Matcher.path("/login", method: "POST"),
///     reply: Reply.json({"token": "abc"}, status: 201),
///   )
///   ..on(
///     matcher: Matcher.path("/users"),
///     reply: Reply.json([{"id": 1}, {"id": 2}]),
///   )
///   ..on(
///     matcher: Matcher.custom((o) => o.path.startsWith("/v2/")),
///     reply: Reply.json({"version": 2}),
///   );
///
/// final dio = Dio()..httpClientAdapter = adapter;
/// ```
///
/// matching is LIFO (last registered wins), so tests can override setUp stubs:
/// ```dart
/// late DioStub adapter;
///
/// setUp(() {
///   adapter = DioStub()
///     ..on(
///       matcher: Matcher.path("/user"),
///       reply: Reply.json({"role": "user"}),
///     );
/// });
///
/// test("admin user", () {
///   adapter.on(
///     matcher: Matcher.path("/user"),
///     reply: Reply.json({"role": "admin"}), // wins
///   );
/// });
/// ```
class DioStub implements HttpClientAdapter {
  final List<_StubEntry> _stubs = [];

  /// register a stub with a matcher and reply.
  void on({required Matcher matcher, required Reply reply}) {
    _stubs.add(_StubEntry(matcher, reply));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final stub in _stubs.reversed) {
      if (stub.matcher.matches(options)) {
        return stub.reply.build(options, requestStream);
      }
    }

    throw StateError(
      "DioStub: no stub matched request.\n\n"
      "Request: ${options.method} ${options.path}\n"
      "Did you forget to register a stub?\n\n"
      "Current stubs:\n"
      "${_printStubs()}",
    );
  }

  String _printStubs() {
    return _stubs.map((s) => "- ${s.matcher}").join("\n");
  }

  @override
  void close({bool force = false}) {}
}

class _StubEntry {
  _StubEntry(this.matcher, this.reply);
  final Matcher matcher;
  final Reply reply;
}
