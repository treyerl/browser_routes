import 'dart:html';

@TestOn('browser')

import 'package:browser_routes/browser_routes.dart';
import 'package:test/test.dart';

bool authOk(void Function() f) {
  f();
  return true;
}

class CustomUserObject implements StateObject {
  CustomUserObject(this.field1, this.field2);
  final int field1;
  final String field2;

  @override
  Map<String, dynamic> toMap() => {
    'field1': field1,
    'field2': field2
  };
}

void main() {
  // ignore: unused_local_variable
  String? errorMessage;
  // ignore: unused_local_variable
  int? errorCode;
  Router? router;

  
  setUp(() {
    router = HashRouter(onError: (url) {
      errorMessage = 'error for $url';
      errorCode = url.code;
      return true;
    });
  });

  test('popState', () {
    Url<CustomUserObject>? _url;
    var route = router!.register<CustomUserObject>(
      '/resource/:page', 
      'back button', 
      (url) => authOk(() => _url = url),
      fromMap: (map) {
        return CustomUserObject(map['field1'], map['field2']);
      }
    );
    route.navigateTo(params: {'page': '1'});
    route.navigateTo(params: {'page': '2'}, userState: CustomUserObject(1, 'one'));
    route.navigateTo(params: {'page': '3'});
    window.history.back();
    return Future.delayed(const Duration(milliseconds: 100)).then((_) {
      expect(_url, isNotNull);
      expect(_url!.code, 200);
      expect(_url!.path, '/resource/2');
      expect(_url!.params, {'page': '2'});
      expect(_url!.userState, isNotNull);
      expect(_url!.userState!.field1, 1);
    
    });
  });

  test('popStateTwice', () {
    Url<CustomUserObject>? _url;
    var route = router!.register<CustomUserObject>(
      '/resource/:page', 
      'back button twice', 
      (url) => authOk(() => _url = url),
      fromMap: (map) {
        return CustomUserObject(map['field1'], map['field2']);
      }
    );
    route.navigateTo(params: {'page': '1'});
    route.navigateTo(params: {'page': '2'}, userState: CustomUserObject(1, 'one'));
    route.navigateTo(params: {'page': '3'});
    route.navigateTo(params: {'page': '4'});
    window.history.back();
    return Future.delayed(const Duration(milliseconds: 100)).then((_) {
      // if a procedure called back by a popstate event would falsely manipulate the history stack /
      // push a new / the current state into the history we would arrive at page 2 in the end
      window.history.back();
      return Future.delayed(const Duration(milliseconds: 100)).then((_) {
        expect(_url, isNotNull);
        expect(_url!.code, 200);
        expect(_url!.path, '/resource/2');
        expect(_url!.params, {'page': '2'});
        expect(_url!.userState, isNotNull);
        expect(_url!.userState!.field1, 1);
      });
    });
  });

}