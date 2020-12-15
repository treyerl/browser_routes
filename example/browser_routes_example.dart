import 'package:browser_routes/browser_routes.dart';

bool authOk(void Function() f) {
  f();
  return true;
}

void main() {
  final router = HashRouter(onError: (Url<StateObject> url) => authOk(() => print('${url.code}: $url')));
  final hello_route = router.register('/', 'hello/:name', (Url url) => 
    authOk(() => print("hello '${url.params['name']}'"))
  );
  // ignore: unused_local_variable
  final home_route = router.register('/', 'Home', (Url url) => 
    authOk(() => print('home screen'))
  );

  hello_route.navigateTo(params: {'name': 'Peter'});
}
