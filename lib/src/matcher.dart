import "package:collection/collection.dart";
import "package:dio/dio.dart";

/// defines how to match incoming requests.
sealed class DioStubMatcher {
  const DioStubMatcher();

  /// match requests with an exact path (and optionally a specific HTTP method).
  ///
  /// ```dart
  /// DioStubMatcher.path("/users")              // matches any method
  /// DioStubMatcher.path("/users", method: "GET")  // matches only GET
  /// DioStubMatcher.path("/users", queryParameters: {"active": "true"})  // matches if query parameters match
  /// DioStubMatcher.path("/users", data: {"id": 1})  // matches only if data matches
  /// ```
  ///
  /// the path is normalized: a leading "/" is added if missing, and any scheme/host
  /// prefix is stripped. so `DioStubMatcher.path("/users")` will match requests to
  /// `https://api.example.com/users`.
  ///
  /// query parameters in the URL are matched separately via `queryParameters`.
  const factory DioStubMatcher.path(
    String path, {
    String? method,
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) = PathMatcher;

  /// match requests using a custom predicate.
  ///
  /// ```dart
  /// DioStubMatcher.custom((o) => o.path.startsWith("/api/"))
  /// DioStubMatcher.custom((o) => RegExp(r"^/users/\d+$").hasMatch(o.path))
  /// ```
  const factory DioStubMatcher.custom(
    bool Function(RequestOptions options) predicate,
  ) = CustomMatcher;

  /// returns true if this matcher matches the given request options.
  bool matches(RequestOptions options);
}

final class PathMatcher extends DioStubMatcher {
  const PathMatcher(this.path, {this.method, this.queryParameters, this.data});
  final String path;
  final String? method;
  final Map<String, dynamic>? queryParameters;
  final Object? data;

  @override
  bool matches(RequestOptions options) {
    final normalizedPath = _normalizePath(path);
    final requestPath = options.uri.path;
    final pathMatches = requestPath == normalizedPath;
    final methodMatches = _matchesMethod(options);
    final queryMatches = _matchesQuery(options);
    final dataMatches = _matchesData(options);
    return pathMatches && methodMatches && queryMatches && dataMatches;
  }

  String _normalizePath(String path) {
    if (path.startsWith("/")) return path;
    return "/$path";
  }

  bool _matchesMethod(RequestOptions options) {
    final upperCase = method?.toUpperCase();
    return upperCase == null || options.method.toUpperCase() == upperCase;
  }

  bool _matchesQuery(RequestOptions options) {
    if (queryParameters == null) return true;
    const mapEquality = MapEquality<String, dynamic>();
    return mapEquality.equals(options.queryParameters, queryParameters);
  }

  bool _matchesData(RequestOptions options) {
    if (data == null) return true;

    if (options.data == null) return false;

    // unimportant match, we don't care about inner types for this check
    // ignore: strict_raw_type
    if (data case final Map data) {
      final request = options.data;
      const equality = DeepCollectionEquality.unordered();
      return request is Map && equality.equals(data, request);
    }

    // unimportant match, we don't care about inner types for this check
    // ignore: strict_raw_type
    if (data case final List data) {
      final request = options.data;
      const equality = DeepCollectionEquality();
      return request is List && equality.equals(data, request);
    }

    return data == options.data;
  }

  @override
  String toString() {
    final buffer = StringBuffer('DioStubMatcher.path("$path"');
    if (method != null) {
      buffer.write(', method: "$method"');
    }
    if (queryParameters != null) {
      buffer.write(", queryParameters: $queryParameters");
    }
    if (data != null) {
      buffer.write(", data: $data");
    }
    buffer.write(")");
    return buffer.toString();
  }
}

/// custom matcher for advanced use cases where the built-in matchers aren't sufficient;
/// the predicate follows closely the structure of a [HttpClientAdapter] fetch method
final class CustomMatcher extends DioStubMatcher {
  const CustomMatcher(this.predicate);
  final bool Function(RequestOptions options) predicate;

  @override
  bool matches(RequestOptions options) => predicate(options);

  @override
  String toString() => "DioStubMatcher.custom($predicate)";
}
