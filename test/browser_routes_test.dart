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

void main() {
  String? errorMessage;
  int? errorCode;
  Router? router;

  
  setUp(() {
    router = HashRouter(onError: (url) {
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

}

