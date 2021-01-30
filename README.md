In-browser routing for simple dart-driven single page applications (SPA). Support for:

1. plain urls: `/my/example/page`
2. named path variable: `/hello/:name`
3. optionally named path variables: `/hello/:name/:?andGuest`
4. path with wildcards: `/api/*` to allow for dynamic content or route to a subsystem

Incoming URL's are compared by segment length first. Route definitions with equal length are resolved in the order as defined above.

## Usage

Set up a simple dart web app:

```bash 
stagehand web-simple
```

Edit `pubspec.yaml`:

```yml
dependencies:
  browser_routes: ^1.0.0
```

Edit `web/main.dart`:

```dart
import 'package:browser_routes/browser_routes.dart';

bool authOk(void Function() f) {
  f();
  return true;
}

void main() {
  final router = HashRouter(onError: (Url url) => 
    authOk(() => print('${url.code}: $url'))
  );
  final hello_route = router.register('hello/:name', 'Hello World', (Url url) => 
    authOk(() => print("hello '${url.params['name']}'"))
  );
  final home_route = router.register('/', 'Home', (Url url) => 
    authOk(() => print('home screen'))
  );

  hello_route.navigateTo(params: {'name': 'Peter'});
}
```

```bash
webdev serve
```

Navigate to [localhost:8080/#/hello/Brian](http://localhost:8080/#/hello/Brian)

## Path's without `#`

When using `Router()` instead of `HastRouter()` configure your webserver to serve `index.html` for all paths.

Nginx-sample: 

```nginx
location / {
      try_files $uri $uri/ /index.html;
}
```


## Testing

```bash
pub run test -p chrome test/browser_routes_test.dart 
pub run test -p chrome test/browser_routes_test_async.dart 
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/treyerl/browser_routes/issues
