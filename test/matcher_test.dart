import "package:dio/dio.dart";
import "package:dio_stub/dio_stub.dart";
import "package:test/test.dart" hide Matcher;

void main() {
  group("Matcher.path", () {
    group("path matching", () {
      test("matches exact path", () {
        const matcher = Matcher.path("/users");
        final options = RequestOptions(path: "https://api.example.com/users");

        expect(matcher.matches(options), isTrue);
      });

      test("does not match different path", () {
        const matcher = Matcher.path("/users");
        final options = RequestOptions(path: "https://api.example.com/posts");

        expect(matcher.matches(options), isFalse);
      });

      test("normalizes path without leading slash", () {
        const matcher = Matcher.path("users");
        final options = RequestOptions(path: "https://api.example.com/users");

        expect(matcher.matches(options), isTrue);
      });

      test("matches nested paths", () {
        const matcher = Matcher.path("/api/v1/users");
        final options =
            RequestOptions(path: "https://api.example.com/api/v1/users");

        expect(matcher.matches(options), isTrue);
      });

      test("does not match partial paths", () {
        const matcher = Matcher.path("/users");
        final options =
            RequestOptions(path: "https://api.example.com/users/123");

        expect(matcher.matches(options), isFalse);
      });
    });

    group("method matching", () {
      test("matches any method when method is null", () {
        const matcher = Matcher.path("/users");

        expect(
          matcher.matches(
            RequestOptions(path: "https://api.example.com/users"),
          ),
          isTrue,
        );
        expect(
          matcher.matches(
            RequestOptions(
              path: "https://api.example.com/users",
              method: "POST",
            ),
          ),
          isTrue,
        );
        expect(
          matcher.matches(
            RequestOptions(
              path: "https://api.example.com/users",
              method: "DELETE",
            ),
          ),
          isTrue,
        );
      });

      test("matches specific method", () {
        const matcher = Matcher.path("/users", method: "POST");
        final options = RequestOptions(
          path: "https://api.example.com/users",
          method: "POST",
        );

        expect(matcher.matches(options), isTrue);
      });

      test("does not match wrong method", () {
        const matcher = Matcher.path("/users", method: "POST");
        final options = RequestOptions(
          path: "https://api.example.com/users",
          method: "GET",
        );

        expect(matcher.matches(options), isFalse);
      });

      test("matches method case-insensitively", () {
        const matcher = Matcher.path("/users", method: "post");
        final options = RequestOptions(
          path: "https://api.example.com/users",
          method: "POST",
        );

        expect(matcher.matches(options), isTrue);
      });
    });

    group("query parameter matching", () {
      test("matches any query when queryParameters is null", () {
        const matcher = Matcher.path("/users");
        final options = RequestOptions(
          path: "https://api.example.com/users",
          queryParameters: {"active": "true"},
        );

        expect(matcher.matches(options), isTrue);
      });

      test("matches exact query parameters", () {
        const matcher = Matcher.path(
          "/users",
          queryParameters: {"active": "true"},
        );
        final options = RequestOptions(
          path: "https://api.example.com/users",
          queryParameters: {"active": "true"},
        );

        expect(matcher.matches(options), isTrue);
      });

      test("does not match different query parameters", () {
        const matcher = Matcher.path(
          "/users",
          queryParameters: {"active": "true"},
        );
        final options = RequestOptions(
          path: "https://api.example.com/users",
          queryParameters: {"active": "false"},
        );

        expect(matcher.matches(options), isFalse);
      });

      test("does not match missing query parameters", () {
        const matcher = Matcher.path(
          "/users",
          queryParameters: {"active": "true"},
        );
        final options = RequestOptions(path: "https://api.example.com/users");

        expect(matcher.matches(options), isFalse);
      });

      test("does not match extra query parameters", () {
        const matcher = Matcher.path(
          "/users",
          queryParameters: {"active": "true"},
        );
        final options = RequestOptions(
          path: "https://api.example.com/users",
          queryParameters: {"active": "true", "page": "1"},
        );

        expect(matcher.matches(options), isFalse);
      });
    });

    group("data matching", () {
      test("matches any data when data is null", () {
        const matcher = Matcher.path("/users");
        final options = RequestOptions(
          path: "https://api.example.com/users",
          data: {"name": "Alice"},
        );

        expect(matcher.matches(options), isTrue);
      });

      test("matches exact map data (order-independent)", () {
        const matcher = Matcher.path(
          "/users",
          method: "POST",
          data: {"name": "Alice", "age": 30},
        );
        final options = RequestOptions(
          path: "https://api.example.com/users",
          method: "POST",
          data: {"age": 30, "name": "Alice"},
        );

        expect(matcher.matches(options), isTrue);
      });

      test("does not match different map data", () {
        const matcher = Matcher.path(
          "/users",
          method: "POST",
          data: {"name": "Alice"},
        );
        final options = RequestOptions(
          path: "https://api.example.com/users",
          method: "POST",
          data: {"name": "Bob"},
        );

        expect(matcher.matches(options), isFalse);
      });

      test("matches exact list data", () {
        const matcher = Matcher.path(
          "/bulk",
          method: "POST",
          data: [1, 2, 3],
        );
        final options = RequestOptions(
          path: "https://api.example.com/bulk",
          method: "POST",
          data: [1, 2, 3],
        );

        expect(matcher.matches(options), isTrue);
      });

      test("does not match list data in wrong order", () {
        const matcher = Matcher.path(
          "/bulk",
          method: "POST",
          data: [1, 2, 3],
        );
        final options = RequestOptions(
          path: "https://api.example.com/bulk",
          method: "POST",
          data: [3, 2, 1],
        );

        expect(matcher.matches(options), isFalse);
      });

      test("matches primitive data", () {
        const matcher = Matcher.path("/echo", method: "POST", data: "hello");
        final options = RequestOptions(
          path: "https://api.example.com/echo",
          method: "POST",
          data: "hello",
        );

        expect(matcher.matches(options), isTrue);
      });

      test("does not match when request data is null but expected is not", () {
        const matcher = Matcher.path(
          "/users",
          method: "POST",
          data: {"name": "Alice"},
        );
        final options = RequestOptions(
          path: "https://api.example.com/users",
          method: "POST",
        );

        expect(matcher.matches(options), isFalse);
      });
    });

    group("toString", () {
      test("formats path only", () {
        const matcher = Matcher.path("/users");

        expect(matcher.toString(), 'Matcher.path("/users")');
      });

      test("formats path with method", () {
        const matcher = Matcher.path("/users", method: "POST");

        expect(matcher.toString(), 'Matcher.path("/users", method: "POST")');
      });

      test("formats path with query parameters", () {
        const matcher = Matcher.path(
          "/users",
          queryParameters: {"active": "true"},
        );

        expect(
          matcher.toString(),
          'Matcher.path("/users", queryParameters: {active: true})',
        );
      });

      test("formats path with data", () {
        const matcher = Matcher.path("/users", data: {"id": 1});

        expect(matcher.toString(), 'Matcher.path("/users", data: {id: 1})');
      });

      test("formats all fields", () {
        const matcher = Matcher.path(
          "/users",
          method: "POST",
          queryParameters: {"v": "2"},
          data: "body",
        );

        expect(
          matcher.toString(),
          'Matcher.path("/users", method: "POST", '
          "queryParameters: {v: 2}, data: body)",
        );
      });
    });
  });

  group("Matcher.custom", () {
    test("matches when predicate returns true", () {
      final matcher = Matcher.custom(
        (o) => o.path.startsWith("/api/"),
      );
      final options = RequestOptions(path: "/api/users");

      expect(matcher.matches(options), isTrue);
    });

    test("does not match when predicate returns false", () {
      final matcher = Matcher.custom(
        (o) => o.path.startsWith("/api/"),
      );
      final options = RequestOptions(path: "/v2/users");

      expect(matcher.matches(options), isFalse);
    });

    test("can match with regex", () {
      final matcher = Matcher.custom(
        (o) => RegExp(r"^/users/\d+$").hasMatch(o.uri.path),
      );

      expect(
        matcher.matches(
          RequestOptions(path: "https://api.example.com/users/123"),
        ),
        isTrue,
      );
      expect(
        matcher.matches(
          RequestOptions(path: "https://api.example.com/users/abc"),
        ),
        isFalse,
      );
    });

    test("can use method in predicate", () {
      final matcher = Matcher.custom(
        (o) => o.method == "DELETE" && o.uri.path.startsWith("/users/"),
      );

      expect(
        matcher.matches(
          RequestOptions(
            path: "https://api.example.com/users/1",
            method: "DELETE",
          ),
        ),
        isTrue,
      );
      expect(
        matcher.matches(
          RequestOptions(
            path: "https://api.example.com/users/1",
            method: "GET",
          ),
        ),
        isFalse,
      );
    });
  });
}
