import "dart:convert";

import "package:dio/dio.dart";
import "package:dio_stub/dio_stub.dart";
import "package:test/test.dart";

void main() {
  late DioStub adapter;
  late Dio dio;

  setUp(() {
    adapter = DioStub();
    dio = Dio()..httpClientAdapter = adapter;
  });

  group("stub matching", () {
    test("returns response for matched stub", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/users"),
        reply: const DioStubReply.json([
          {"id": 1},
        ]),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/users",
      );

      expect(response.statusCode, 200);
      expect(response.data, [
        {"id": 1},
      ]);
    });

    test("throws StateError when no stub matches", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/users"),
        reply: const DioStubReply.json([]),
      );

      expect(
        () => dio.get<dynamic>("https://api.example.com/posts"),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            "error",
            isA<StateError>(),
          ),
        ),
      );
    });

    test("error message includes request details", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/users"),
        reply: const DioStubReply.json([]),
      );

      try {
        await dio.get<dynamic>("https://api.example.com/posts");
        fail("Should have thrown");
      } on DioException catch (e) {
        final error = e.error! as StateError;
        expect(error.message, contains("GET"));
        expect(error.message, contains("/posts"));
        expect(error.message, contains("no stub matched"));
      }
    });

    test("error message lists registered stubs", () async {
      adapter
        ..on(
          matcher: const DioStubMatcher.path("/users"),
          reply: const DioStubReply.json([]),
        )
        ..on(
          matcher: const DioStubMatcher.path("/posts", method: "POST"),
          reply: const DioStubReply.json(null),
        );

      try {
        await dio.get<dynamic>("https://api.example.com/unknown");
        fail("Should have thrown");
      } on DioException catch (e) {
        final error = e.error! as StateError;
        expect(error.message, contains('DioStubMatcher.path("/users")'));
        expect(
          error.message,
          contains('DioStubMatcher.path("/posts", method: "POST")'),
        );
      }
    });
  });

  group("LIFO ordering", () {
    test("last registered stub wins", () async {
      adapter
        ..on(
          matcher: const DioStubMatcher.path("/users"),
          reply: const DioStubReply.json({"source": "first"}),
        )
        ..on(
          matcher: const DioStubMatcher.path("/users"),
          reply: const DioStubReply.json({"source": "second"}),
        );

      final response = await dio.get<dynamic>(
        "https://api.example.com/users",
      );

      expect(response.data, {"source": "second"});
    });

    test("test can override setUp stubs", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/user"),
        reply: const DioStubReply.json({"role": "user"}),
      );

      adapter.on(
        matcher: const DioStubMatcher.path("/user"),
        reply: const DioStubReply.json({"role": "admin"}),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/user",
      );

      expect(response.data, {"role": "admin"});
    });

    test("earlier stubs still match if later ones do not", () async {
      adapter
        ..on(
          matcher: const DioStubMatcher.path("/users"),
          reply: const DioStubReply.json({"type": "list"}),
        )
        ..on(
          matcher: const DioStubMatcher.path("/posts"),
          reply: const DioStubReply.json({"type": "posts"}),
        );

      final response = await dio.get<dynamic>(
        "https://api.example.com/users",
      );

      expect(response.data, {"type": "list"});
    });
  });

  group("HTTP methods", () {
    test("GET request", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/data", method: "GET"),
        reply: const DioStubReply.json({"method": "GET"}),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/data",
      );

      expect(response.data, {"method": "GET"});
    });

    test("POST request", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/data", method: "POST"),
        reply: const DioStubReply.json({"method": "POST"}, status: 201),
      );

      final response = await dio.post<dynamic>(
        "https://api.example.com/data",
      );

      expect(response.statusCode, 201);
      expect(response.data, {"method": "POST"});
    });

    test("PUT request", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/data/1", method: "PUT"),
        reply: const DioStubReply.json({"method": "PUT"}),
      );

      final response = await dio.put<dynamic>(
        "https://api.example.com/data/1",
      );

      expect(response.data, {"method": "PUT"});
    });

    test("DELETE request", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/data/1", method: "DELETE"),
        reply: const DioStubReply.json(null, status: 204),
      );

      final response = await dio.delete<dynamic>(
        "https://api.example.com/data/1",
      );

      expect(response.statusCode, 204);
    });

    test("PATCH request", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/data/1", method: "PATCH"),
        reply: const DioStubReply.json({"patched": true}),
      );

      final response = await dio.patch<dynamic>(
        "https://api.example.com/data/1",
      );

      expect(response.data, {"patched": true});
    });
  });

  group("response types", () {
    test("JSON response", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/json"),
        reply: const DioStubReply.json({"key": "value"}),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/json",
      );

      expect(response.data, {"key": "value"});
    });

    test("text response", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/text"),
        reply: const DioStubReply.text("Hello, world!"),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/text",
        options: Options(responseType: ResponseType.plain),
      );

      expect(response.data, "Hello, world!");
    });

    test("dynamic JSON response", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/echo", method: "POST"),
        reply: DioStubReply.jsonWith((options) => {"echoed": options.data}),
      );

      final response = await dio.post<dynamic>(
        "https://api.example.com/echo",
        data: "hello",
      );

      expect(response.data, {"echoed": "hello"});
    });
  });

  group("query parameters", () {
    test("matches with query parameters", () async {
      adapter.on(
        matcher: const DioStubMatcher.path(
          "/search",
          queryParameters: {"q": "dart"},
        ),
        reply: const DioStubReply.json({"results": <dynamic>[]}),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/search",
        queryParameters: {"q": "dart"},
      );

      expect(response.data, {"results": <dynamic>[]});
    });
  });

  group("data matching", () {
    test("matches POST body", () async {
      adapter.on(
        matcher: const DioStubMatcher.path(
          "/login",
          method: "POST",
          data: {"username": "alice", "password": "secret"},
        ),
        reply: const DioStubReply.json({"token": "abc"}),
      );

      final response = await dio.post<dynamic>(
        "https://api.example.com/login",
        data: {"username": "alice", "password": "secret"},
      );

      expect(response.data, {"token": "abc"});
    });
  });

  group("close", () {
    test("close does not throw", () {
      adapter.close();
      adapter.close(force: true);
    });
  });

  group("integration: realistic usage", () {
    test("CRUD flow", () async {
      adapter
        ..on(
          matcher: const DioStubMatcher.path("/items"),
          reply: const DioStubReply.json([
            {"id": 1, "name": "Item 1"},
          ]),
        )
        ..on(
          matcher: const DioStubMatcher.path("/items", method: "POST"),
          reply: const DioStubReply.json(
            {"id": 2, "name": "Item 2"},
            status: 201,
          ),
        )
        ..on(
          matcher: const DioStubMatcher.path("/items/2", method: "PUT"),
          reply: const DioStubReply.json({"id": 2, "name": "Updated"}),
        )
        ..on(
          matcher: const DioStubMatcher.path("/items/2", method: "DELETE"),
          reply: const DioStubReply.json(null, status: 204),
        );

      final list = await dio.get<dynamic>("https://api.example.com/items");
      expect((list.data as List<dynamic>).length, 1);

      final created = await dio.post<dynamic>(
        "https://api.example.com/items",
        data: {"name": "Item 2"},
      );
      expect(created.statusCode, 201);

      final updated = await dio.put<dynamic>(
        "https://api.example.com/items/2",
        data: {"name": "Updated"},
      );
      expect(
        (updated.data as Map<String, dynamic>)["name"],
        "Updated",
      );

      final deleted = await dio.delete<dynamic>(
        "https://api.example.com/items/2",
      );
      expect(deleted.statusCode, 204);
    });

    test("custom matcher with jsonWith reply", () async {
      adapter.on(
        matcher: DioStubMatcher.custom(
          (o) => o.uri.path.startsWith("/api/v2/"),
        ),
        reply: DioStubReply.jsonWith((options) {
          final segment = options.uri.pathSegments.last;
          return {"resource": segment, "version": 2};
        }),
      );

      final response = await dio.get<dynamic>(
        "https://api.example.com/api/v2/users",
      );

      expect(response.data, {"resource": "users", "version": 2});
    });

    test("custom reply with request stream access", () async {
      adapter.on(
        matcher: const DioStubMatcher.path("/upload", method: "POST"),
        reply: DioStubReply.custom((options, requestStream) async {
          final chunks = await requestStream?.toList() ?? [];
          final bytes = chunks.fold<List<int>>(
            [],
            (acc, chunk) => acc..addAll(chunk),
          );
          final body = utf8.decode(bytes);
          return ResponseBody.fromString(
            jsonEncode({"received": body}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }),
      );

      final response = await dio.post<dynamic>(
        "https://api.example.com/upload",
        data: "file contents",
      );

      expect(
        (response.data as Map<String, dynamic>)["received"],
        isNotEmpty,
      );
    });
  });
}
