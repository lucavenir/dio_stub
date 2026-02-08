import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:dio_stub/dio_stub.dart";
import "package:test/test.dart" hide Matcher;

void main() {
  final defaultOptions = RequestOptions(path: "/test");

  group("Reply.json", () {
    test("encodes map as JSON bytes", () async {
      const reply = Reply.json({"id": 1, "name": "Alice"});
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(jsonDecode(body), {"id": 1, "name": "Alice"});
    });

    test("encodes list as JSON bytes", () async {
      const reply = Reply.json([1, 2, 3]);
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(jsonDecode(body), [1, 2, 3]);
    });

    test("encodes null as empty bytes", () async {
      const reply = Reply.json(null);
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(body, isEmpty);
    });

    test("defaults to status 200", () async {
      const reply = Reply.json({"ok": true});
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 200);
    });

    test("uses custom status code", () async {
      const reply = Reply.json({"created": true}, status: 201);
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 201);
    });

    test("sets content-type to application/json", () async {
      const reply = Reply.json({"ok": true});
      final response = await reply.build(defaultOptions, null);

      expect(
        response.headers[Headers.contentTypeHeader],
        [Headers.jsonContentType],
      );
    });

    test("content-type overrides custom headers", () async {
      const reply = Reply.json(
        {"ok": true},
        headers: {
          Headers.contentTypeHeader: ["text/plain"],
        },
      );
      final response = await reply.build(defaultOptions, null);

      expect(
        response.headers[Headers.contentTypeHeader],
        [Headers.jsonContentType],
      );
    });

    test("preserves additional custom headers", () async {
      const reply = Reply.json(
        {"ok": true},
        headers: {
          "x-request-id": ["abc-123"],
        },
      );
      final response = await reply.build(defaultOptions, null);

      expect(response.headers["x-request-id"], ["abc-123"]);
    });
  });

  group("Reply.jsonWith", () {
    test("builds response from callback", () async {
      final reply = Reply.jsonWith((options) => {"path": options.path});
      final options = RequestOptions(path: "/hello");
      final response = await reply.build(options, null);
      final body = await _readBody(response);

      expect(jsonDecode(body), {"path": "/hello"});
    });

    test("supports async callback", () async {
      final reply = Reply.jsonWith((options) async {
        return {"async": true};
      });
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(jsonDecode(body), {"async": true});
    });

    test("uses custom status code", () async {
      final reply = Reply.jsonWith((_) => null, status: 204);
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 204);
    });

    test("sets content-type to application/json", () async {
      final reply = Reply.jsonWith((_) => {"ok": true});
      final response = await reply.build(defaultOptions, null);

      expect(
        response.headers[Headers.contentTypeHeader],
        [Headers.jsonContentType],
      );
    });
  });

  group("Reply.text", () {
    test("encodes string as UTF-8 bytes", () async {
      const reply = Reply.text("Hello, world!");
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(body, "Hello, world!");
    });

    test("handles unicode text", () async {
      const reply = Reply.text("Hej verden! \u{1F44B}");
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(body, "Hej verden! \u{1F44B}");
    });

    test("handles empty string", () async {
      const reply = Reply.text("");
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(body, isEmpty);
    });

    test("defaults to status 200", () async {
      const reply = Reply.text("OK");
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 200);
    });

    test("uses custom status code", () async {
      const reply = Reply.text("Not Found", status: 404);
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 404);
    });

    test("sets content-type to text/plain", () async {
      const reply = Reply.text("OK");
      final response = await reply.build(defaultOptions, null);

      expect(
        response.headers[Headers.contentTypeHeader],
        [Headers.textPlainContentType],
      );
    });
  });

  group("Reply.bytes", () {
    test("returns raw bytes", () async {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final reply = Reply.bytes(bytes, contentType: "image/png");
      final response = await reply.build(defaultOptions, null);
      final chunks = await response.stream.toList();
      final result = chunks.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );

      expect(result, [0x89, 0x50, 0x4E, 0x47]);
    });

    test("sets content-type from parameter", () async {
      final reply = Reply.bytes(
        Uint8List(0),
        contentType: "application/pdf",
      );
      final response = await reply.build(defaultOptions, null);

      expect(
        response.headers[Headers.contentTypeHeader],
        ["application/pdf"],
      );
    });

    test("defaults to status 200", () async {
      final reply = Reply.bytes(Uint8List(0), contentType: "image/png");
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 200);
    });

    test("uses custom status code", () async {
      final reply = Reply.bytes(
        Uint8List(0),
        contentType: "image/png",
        status: 206,
      );
      final response = await reply.build(defaultOptions, null);

      expect(response.statusCode, 206);
    });
  });

  group("Reply.custom", () {
    test("returns builder result directly", () async {
      final reply = Reply.custom((options, requestStream) async {
        return ResponseBody.fromString("custom", 200);
      });
      final response = await reply.build(defaultOptions, null);
      final body = await _readBody(response);

      expect(body, "custom");
      expect(response.statusCode, 200);
    });

    test("receives request options", () async {
      final reply = Reply.custom((options, requestStream) async {
        return ResponseBody.fromString(
          options.method,
          200,
        );
      });
      final options = RequestOptions(path: "/test", method: "DELETE");
      final response = await reply.build(options, null);
      final body = await _readBody(response);

      expect(body, "DELETE");
    });

    test("receives request stream", () async {
      final requestStream = Stream.value(
        Uint8List.fromList(utf8.encode("request body")),
      );
      final reply = Reply.custom((options, stream) async {
        final chunks = await stream!.toList();
        final body = chunks.fold<List<int>>(
          [],
          (acc, chunk) => acc..addAll(chunk),
        );
        return ResponseBody.fromString(
          "echo: ${utf8.decode(body)}",
          200,
        );
      });
      final response = await reply.build(defaultOptions, requestStream);
      final body = await _readBody(response);

      expect(body, "echo: request body");
    });
  });
}

Future<String> _readBody(ResponseBody response) async {
  final chunks = await response.stream.toList();
  final bytes = chunks.fold<List<int>>(
    [],
    (acc, chunk) => acc..addAll(chunk),
  );
  return utf8.decode(bytes);
}
