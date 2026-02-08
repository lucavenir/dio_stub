// example file uses print to demonstrate output
// ignore_for_file: avoid_print

import "package:dio/dio.dart";
import "package:dio_stub/dio_stub.dart";

Future<void> main() async {
  final adapter = DioStub()
    ..on(
      matcher: const DioStubMatcher.path("/users"),
      reply: const DioStubReply.json([
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
      ]),
    )
    ..on(
      matcher: const DioStubMatcher.path("/login", method: "POST"),
      reply: const DioStubReply.json({"token": "abc123"}, status: 201),
    );

  final dio = Dio()..httpClientAdapter = adapter;

  final users = await dio.get<dynamic>("https://api.example.com/users");
  print("Users: ${users.data}");

  final login = await dio.post<dynamic>("https://api.example.com/login");
  print("Login: ${login.data}");
}
