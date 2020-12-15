import 'dart:html';

@TestOn('browser')

import 'package:browser_routes/browser_routes.dart';
import 'package:test/test.dart';

bool authOk(void Function() f) {
  f();
  return true;
}

bool authFail(void Function() f) {
  f();
  return false;
}

class IntByRef {
  int? value;
}

void main() {
  String? errorMessage;
  int? errorCode;
  Router? router;

  setUp(() {
    router = HashRouter.test(onError: (url) {
      errorMessage = 'error for $url';
      errorCode = url.code;
      return true;
    });
  });

  test('unauthorized', () {
    var unauthorized = router!.register(
      '/unauthorized', 
      'unauthorized access', 
      (url) => false
    );
    unauthorized.navigateTo();
    expect(errorMessage, 'error for $unauthorized');
    expect(errorCode, 403);
  });

  test('simplePath', () {
    Url? _url;
    var simplePath = router!.register<StateObject>(
      '/simplePath', 
      'simple path', 
      (url) => authOk(() => _url = url)
    );
    simplePath.navigateTo();
    expect(_url, isNotNull);
    expect(_url!.code, 200);
    expect(_url!.path, '$simplePath');
  });

  test('simplePathLonger', () {
    Url? _url;
    var simplePathLonger = router!.register<StateObject>(
      '/simple/path/to/resource', 
      'simple path with multiple segments', 
      (url) => authOk(() => _url = url)
    );
    simplePathLonger.navigateTo();
    expect(_url, isNotNull);
    expect(_url!.code, 200);
    expect(_url!.path, '/simple/path/to/resource');
    expect(_url!.path, '$simplePathLonger');
  });

  test('pathWithVariable', () {
    Url? _url;
    var pathWithVariable = router!.register<StateObject>(
      '/resource/:page', 
      'path with page variable', 
      (url) => authOk(() => _url = url)
    );
    pathWithVariable.navigateTo(params: {'page': '2'});
    expect(_url, isNotNull);
    expect(_url!.code, 200);
    expect(_url!.path, '/resource/2');
    expect(_url!.params, {'page': '2'});
  });

  test('pathWithConflictingVariable', () {
    String? message;
    router!.register(
      '/resource/:page', 
      'path with page variable', 
      (url) => true
    );
    try {
      router!.register(
        '/resource/:anotherVariableName', 
        'path with another variable', 
        (url) => true
      );
    } on StateError catch (e) {
      message = e.message;
    }
    expect(message, isNotNull);
    expect(message, "'/resource/:anotherVariableName' in conflict with '/resource/:page'");
  });

  test('twoPathsWithVariable', () {
    Url? _url;
    router!.register(
      '/resource/:page', 
      'path with page variable', 
      (url) => true
    );

    final route = router!.register<StateObject>(
      '/resource/:id/subtopic', 
      'path with page variable and subtopic', 
      (url) => authOk(() => _url = url)
    );
    route.navigateTo(params: {'id': '2'});
    expect(_url, isNotNull);
    expect(_url!.code, 200);
    expect(_url!.path, '/resource/2/subtopic');
    expect(_url!.params, {'id': '2'});
  });

  test('queryTest', () {
    Url? _url;
    final route = router!.register<StateObject>(
      '/queryPath', 
      'url with query variables', 
      (url) => authOk(() => _url = url)
    );

    route.navigateTo(query: {'name': 'Peter', 'age': '22'});
    expect(_url, isNotNull);
    expect(_url!.code, 200);
    expect(_url!.path, '/queryPath');
    expect(_url!.toString(), '/queryPath?name=Peter&age=22');
    expect(_url!.query, {'name': 'Peter', 'age': '22'});
    
    // window.history.pushState(null, '', '/normalPath');
  });

  test('window title', () {
    final route = router!.register(
      '/window/title/path', 
      'normal title', 
      (url) => true
    );
    route.navigateTo();
    expect(route.title, document.title);
  });

  test('route redirect', () {
    Url? _url;
    final normalPath = router!.register<StateObject>(
      '/normalPath', 
      'normal title', 
      (url) => authOk(() => _url = url)
    );
    final root = router!.redirect(from: '/', to: normalPath, title: 'welcome');
    root.navigateTo();
    expect(root.title, document.title);
    expect(_url!.path, '/');
  });

  test('pathWith2Variables', () {
    Url? _url;
    var pathWithVariable = router!.register<StateObject>(
      '/resource/:id/:page', 
      'path with id & page variable', 
      (url) => authOk(() => _url = url)
    );
    pathWithVariable.navigateTo(params: {'page': '2', 'id': '3'});
    expect(_url, isNotNull);
    expect(_url!.code, 200);
    expect(_url!.path, '/resource/3/2');
    expect(_url!.params, {'page': '2', 'id': '3'});
  });

  test('incomplete parameters', () {
    String? errorMessage;
    var pathWithVariable = router!.register(
      '/resource/:id/:page', 
      'path with id & page variable', 
      (url) => true
    );
    try {
      pathWithVariable.navigateTo(params: {'id': '3'});
    } on StateError catch (e) {
      errorMessage = e.message;
    }
    
    expect(errorMessage, isNotNull);
    expect(errorMessage, 'missing parameters: [page]');
  });

  test('registerInvalidPath', () {
    String? errorMessage;
    try {
      router!.register(
        '/resource/:id?', 
        'invalid path segment', 
        (url) => true
      );
    } on FormatException catch (e) {
      errorMessage = e.message;
    }
    
    expect(errorMessage, isNotNull);
    expect(errorMessage, "invalid url segment 'id?'");
  });

  test('register ambiguous parameters', () {
    String? errorMessage;
    try {
      router!.register(
        '/resource/:id/path/:id', 
        'ambiguous parameters', 
        (url) => true
      );
    } on StateError catch (e) {
      errorMessage = e.message;
    }
    
    expect(errorMessage, isNotNull);
    expect(errorMessage, 'ambiguous parameter names: [id, id]');
  });

  test('/404 path', () {
    window.location.hash = '/404 path';
    router!.go();
    expect(errorMessage, isNotNull);
    expect(errorMessage, 'error for /404%20path');
    expect(errorCode, 404);
  });

  test('///invalid path///', () {
    window.location.hash = '///invalid path///';
    router!.go();
    expect(errorMessage, isNotNull);
    expect(errorMessage, 'error for ///invalid%20path///');
    expect(errorCode, 404);
  });

  test('/empty//segment', () {
    Url? _url;
    final route = router!.register<StateObject>(
      '/empty//segment', 
      'empty segment', 
      (url) => authOk(() => _url = url)
    );
    window.location.hash = '/empty//segment';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.path, '/empty//segment');
    expect(route.segments.length, 3);
  });

  test('/valid/empty/value/:/segment', () {
    Url? _url;
    router!.register<StateObject>(
      '/valid/empty/value/:/segment', 
      'valid empty value segment', 
      (url) => authOk(() => _url = url)
    );
    window.location.hash = '/valid/empty/value/7/segment';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.path, '/valid/empty/value/7/segment');
    expect(_url!.params[''], '7');
  });

  // TODO: check if register<StateObject>() can be replace by register() --> is it a bug of the dart analizer?

  test('optional values 1', () {
    Url? _url;
    router!.register<StateObject>(
      '/valid/path/:?optional', 
      'valid optional path variable', 
      (url) => authOk(() => _url = url)
    );
    window.location.hash = '/valid/path';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.path, '/valid/path');
    expect(_url!.params['optional'], null);

    window.location.hash = '/valid/path/hello';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.path, '/valid/path/hello');
    expect(_url!.params['optional'], 'hello');
  });

  test('optional values 2', () {
    Url? _url;
    router!.register<StateObject>(
      '/valid/:path/:?optional', 
      'valid optional path variable with non-optional path variable', 
      (url) => authOk(() => _url = url)
    );
    window.location.hash = '/valid/7';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.path, '/valid/7');
    expect(_url!.params['optional'], null);
    expect(_url!.params['path'], '7');

    window.location.hash = '/valid/7/hello';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.path, '/valid/7/hello');
    expect(_url!.params['optional'], 'hello');
    expect(_url!.params['path'], '7');
  });

  test('invalid optional values', () {
    final v1 = 'after non-optional variables (:)';
    final v2 = 'regular path segments';
    void subtest(String path, String desc, String variant) {
      String? err;
      final exp = "invalid route definition '$path': optional path variables (:?) must follow $variant";
      try {
        router!.register<StateObject>(path, desc, (url) => true);
      } on StateError catch (e) {
        err = e.message;
      }
      expect(err, isNotNull);
      expect(err, exp);
    }
    subtest('/invalid/:?optional/:variable','invalid optional variable', v1);
    subtest('/invalid/:?optional/:variable/:v2','invalid optional variable', v1);
    subtest('/invalid/:?optional/path','invalid optional variable', v2);
    subtest('/invalid/:?optional/path/*','invalid optional variable', v2);
  });
  
  test('wildcard', () {
    void subtest(String path, int expectedKey, IntByRef key){
      window.location.hash = path;
      router!.go();
      expect(key.value, isNotNull);
      expect(key.value, expectedKey);
    }
    const ALL = 0;
    const LONGEST = 1;
    const LONG = 2;
    const SHORT = 3;
    final key = IntByRef();
    router!.register('/*', 'catches all', (url) => authOk(() => key.value = ALL));
    router!.register('/some/simple/path/with/*', 'catches all', (url) => authOk(() => key.value = LONGEST));
    router!.register('/some/shorter/*', 'catches all', (url) => authOk(() => key.value = LONG));
    router!.register('/some/*', 'catches all', (url) => authOk(() => key.value = SHORT));
    subtest('/just/anything', ALL, key);
    subtest('/some/simple/path/with/just/anything', LONGEST, key);
    subtest('/some/shorter/path/with/just/anything', LONG, key);
    subtest('/some/other/path/with/just/anything', SHORT, key);
    
  });
  
  test('wildcard typo', () {
    String? msg;
    try {
      router!.register('/some/wildcard*', 'wildcard typo', (url) => true);
    } on FormatException catch (e) {
      msg = e.message;
    }
    expect(msg, isNotNull);
    expect(msg, "invalid url segment 'wildcard*'");
  });

  test('invalid wildcard (wildcard not last)', () {
    void subtest(String path, String desc, String exp) {
      String? msg;
      try {
        router!.register(path, desc, (url) => true);
      } on StateError catch (e) {
        msg = e.message;
      }
      expect(msg, isNotNull);
      expect(msg, exp);
    }
    subtest('/*/path', 'invalid wildcard path', "wildcard (*) must terminate a route. Invalid segment 'path'");
    subtest('/*/:variable', 'invalid wildcard path with variable', "wildcard (*) must terminate a route. Invalid segment 'variable'");
    subtest('/*/:?optional', 'invalid wildcard path with optional variable', "wildcard (*) must terminate a route. Invalid segment 'optional'");
  });

  test('ambiguous values (optional & non-optional)', () {
    String? msg;
    try {
      router!.register('/some/:path', 'some variable path', (url) => true);
      router!.register('/some/:optional', 'some similar optional variable path', (url) => true);
    } on StateError catch (e) {
      msg = e.message;
    }
    expect(msg, isNotNull);
    expect(msg, "'/some/:optional' in conflict with '/some/:path'");
  });

  test('mixed candidate selection', () {
    const V = 1;
    const OV = 2;
    const W = 3;
    final key = IntByRef();
    void go(String path, int v){
      window.location.hash = path;
      router!.go();
      expect(key.value, v);
    }
    
    router!.register<StateObject>('/some/:varibale/:?optional', 'path with variable and optional variable', (url) => authOk(() => key.value = OV));
    router!.register<StateObject>('/some/:varibale/path', 'path with variable', (url) => authOk(() => key.value = V));
    router!.register<StateObject>('/some/*', 'path with wildcard', (url) => authOk(() => key.value = W));
    go('/some/7/path', V);
    go('/some/7/hello', OV);
    go('/some/arbitrary/longer/path', W);

  });

  test('wildcard arguments', () {
    Url? _url;
    router!.register<StateObject>('/*', 'wildcard arguments test', (url) => authOk(() => _url = url));
    window.location.hash = '/one/two/three/four';
    router!.go();
    expect(_url, isNotNull);
    expect(_url!.args.length, 4);
    expect(_url!.args.toString(), '[one, two, three, four]');
  });

  test('root with wildcard', () {
    final key = IntByRef();
    void go(String path, int v){
      window.location.hash = path;
      router!.go();
      expect(key.value, v);
    }
    router!.register('/', 'root', (url) => authOk(() => key.value = 0));
    router!.register('/*', 'anything else', (url) => authOk(() => key.value = 1));
    go('/', 0);
    go('/just/something', 1);
  });
  
  test('methods throwing errors', () {
    router!.register('/path/1', 'path 1', (url) => throw StateError('hello'));
    router!.register('/path/2', 'path 2', (url) => throw Url('/error/path', code: 499));
    try {
      window.location.hash = '/path/1';
      router!.go();
    } on StateError catch (e) {
      expect(e.message, 'hello');
    }
    window.location.hash = '/path/2';
    router!.go();
    expect(errorMessage, isNotNull);
    expect(errorCode, 499);
  });


}

