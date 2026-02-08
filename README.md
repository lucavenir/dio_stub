# dio_stub

a Dio HTTP client adapter for tests that care about behavior, not implementation.

`dio_stub` works at the `HttpClientAdapter` layer, which is Dio's lowest abstraction before real HTTP hits; this implies that no behavior is skipped (e.g. serialization, interceptors, etc.).

this package aims at giving the highest-fidelity stub possible, without hitting a real server.

## usage

`dio_stub` allows you to add a stub ("reply") to a specific set of queried routes ("matcher"); in a nutshell:

```dart
import 'package:dio/dio.dart';
import 'package:dio_stub/dio_stub.dart';

// ... set-up
final adapter = DioStub()
  ..on(
    matcher: Matcher.path("/login", method: "POST"),
    reply: Reply.json({"token": "abc"}, status: 201),
  )
  ..on(
    matcher: Matcher.path("/users"),
    reply: Reply.json([{"id": 1}, {"id": 2}]),
  );

final client = Dio();
client.httpClientAdapter = adapter;

// ... test
final response = await dio.get("https://api.example.com/users");
print(response.data); // [{"id": 1}, {"id": 2}]
```

of course, this becomes useful when you want to test an API that *depends* on `dio`.

### matching

you can tell the adapter to be evaluated, simply, by path (and optionally, also by method, by query parameters and by body):

```dart
Matcher.path("/users")
Matcher.path("/users", method: "POST")
Matcher.path("/users", queryParameters: {"active": "true"})
Matcher.path("/users", method: "POST", data: {"name": "Alice"})
```

you can also exploit a custom callback that, given the requests options, will evaluate the adapter if that returns `true`

```dart
Matcher.custom((options) => options.uri.path.startsWith("/api/v2/"))
Matcher.custom((options) => RegExp(r"^/users/\d+$").hasMatch(options.uri.path))
```

### replying

there's some built-in simple replies you can exploit, and there's also a `.custom` constructor that allows you to reply however you want!

```dart
Reply.json({"key": "value"})                            // JSON with status 200
Reply.json({"error": "not found"}, status: 404)         // JSON with custom status
Reply.jsonWith((options) => {"path": options.path})     // dynamic JSON from request
Reply.text("ok")                                        // plain text
Reply.bytes(pngBytes, contentType: "image/png")         // raw bytes
Reply.custom((options, requestStream) async { ... })    // full control
```

### last override wins

stubs are matched last-registered-first; this lets tests override `setUp` stubs with no surprises:

```dart
late DioStub adapter;
late Dio dio;

setUp(() {
  adapter = DioStub()
    ..on(
      matcher: Matcher.path("/user"),
      reply: Reply.json({"role": "user"}),
    );
  dio = Dio()..httpClientAdapter = adapter;
});

test("admin override", () {
  adapter.on(
    matcher: Matcher.path("/user"),
    reply: Reply.json({"role": "admin"}), // wins
  );

  final response = await dio.get("https://api.example.com/user");
  expect(response.data["role"], "admin");
});
```

##  motivation

this package offers a more pragmatic approach to unit testing, which is called **behavioral testing**; instead of mocking a direct dependency, we **stub the actual boundaries** of our code, and we also avoid verifying the internals.

for `dio`, the last boundary before hitting the server is `HttpClientAdapter`, and that's where this package works.

### why tho
a typical mock-based Dio test looks like this:

```dart
import "package:mocktail:mocktail.dart";

// ... in a setup
final client = MockDio();
final repository = Repository(dio: client);

// ... in a test
when(mockDio.get("/users")).thenAnswer((_) async {  // my stomach aches already
  return Response(                                  // .. huh?
    data: [{"id": 1}],                              // ok
    statusCode: 200,                                // great
    requestOptions: RequestOptions(path: "/users"), // .. who cares?
  );
});

final result = await userRepository.getUsers();
// are we *positive* we need to test this implementation detail?
verify(mockDio.get("/users")).called(1);
```

nowadays, mocking like so disturbs quite the amount of developers, because:
 * it breaks if you choose to change *how* you call `dio` (say, e.g. from `dio.get` to `dio.fetch`)
 * it skips `dio`'s actual http adapter, meaning it won't catch any problems with:
   * encoding/decoding
   * request/response type configuration
   * interceptors
   * validate status
 * it leads you to carefully hand-craft fake responses and fake dio exceptions, whose behaviors might not adhere to the actual reality of the call stack
 * when it fails, the *why* is a lot less explicit: have you wished you got a helpful message, instead of a generic `MissingStubError`?
 * it locks-in your architecture, meaning that if you choose to start lean, and bring the "big guns" later, you'd have to *carefully* re-write all your tests
 * it defeats the most important aspect of testing: to document an API contract; when reading a test, you don't care about the noisy details, you want to understand the system as a whole
 * it breaks when `package:dio` internals change, which quite a remote possibility, but it's still there

**furthermore**:
* mocking leads to laziness: since you mock away one layer at a time, some developers "lazy themselves out" of testing some important details
  * e.g. mocking a service leads to a `/users` --> `/v2/users` change invisible to the tests!
* mocking leads to more maintenance work: `when` and `verify` looks cool once they're in place, but it's a lengthy process and those two might break easily


### behavioral testing

if the above convinced you to at least try a different approach, you'll find yourself home with `dio_stub`; define what the server would return, and ..that's it! your whole dependency injection / call stack works out of the box, with no fakes, no mocks, no verifies.

we still want to avoid hitting the network, but everything else stays in place

```dart
import "package:dio_stub/dio_stub.dart";

// ... in a setup
final client = Dio();
final adapter = DioStub();
client.httpClientAdapter = adapter;
final repository = Repository(dio: client);

// ... in a test
adapter.on(
  matcher: Matcher.path("/users"),                      // when hitting /users..
  reply: Reply.json([{"id": 1, "name": "Alice"}]),  // ..reply with a 200 ok json
);
final users = await userRepository.getUsers();

expect(users, [User(id: 1, name: "Alice")]);
```

the above is easy to read, easy to write, easy to understand, and easy to maintain (you'll hardly touch this ever again); this test doesn't know or care whether your repository uses `dio.get()`, `dio.fetch()`, or if it passes through three interceptors first, or if you chose to encapsulate your http calls through an API service class.

in other words, when we choose to mock `Dio` directly, we're asserting "ok, my code calls this method, and it does that with these arguments"; instead, when we stub the HTTP interface, we're asserting "given this API response, my code produces this result". that's the motivation for this package: that is always what we actually care about.

### so.. mocks are trash?

**no**.

mocks still have their place, especially when you can't work around some APIs.

for example, if you need to *verify* that a specific method was called a specific number of times (or in a specific order), and that's a critical part of your behavior, then mocks are great!


## contribution

### "no LLM" / "no AI" policy

while this package has been developed with some AI assistance, it's been handcrafted with human hands.

please refer to `AI_POLICY.md`

### strict "english only" policy
english is required: please communicate with it

because of the above "no LLM" policy, you're greatly discouraged at translating using LLMs, as it'll probably schlop-ify your intentions

google translate solved language problems already 25 years ago, please stick with it, or proceed communicating in english with your other means
