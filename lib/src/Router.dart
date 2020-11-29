
import 'dart:html';

extension Trimmer on String {

  /// similar to [trim] but with multiple and 
  /// optionally defined strings instead only whitespaces
  String truncate([String part = ' ']) {
    var str = this;
    while(str.startsWith(part)) {
      str = str.substring(part.length);
    }
    while (str.endsWith(part)) {
      str = str.substring(0, str.length - part.length);
    }
    return str;
  }

  /// similar to [trimLeft] but with multiple and 
  /// optionally defined strings instead only whitespaces
  String truncateLeft([String part = ' ']) {
    var str = this;
    while(str.startsWith(part)) {
      str = str.substring(part.length);
    }
    return str;
  }

  /// similar to [trimRight] but with multiple and 
  /// optionally defined strings instead only whitespaces
  String truncateRight([String part = ' ']) {
    var str = this;
    while (str.endsWith(part)) {
      str = str.substring(0, str.length - part.length);
    }
    return str;
  }
}

extension IterableFreedom<E> on Iterable<E> {
  /// Returns at most one element that satisfies [test] or null.
  ///
  /// Checks elements to see if `test(element)` returns true.
  /// If exactly one element satisfies [test], that element is returned.
  /// If more than one matching element is found, throws [StateError].
  /// If no matching element is found, returns [null].
  E? atMostOneWhere(bool Function(E element) test) {
    late E result;
    var foundMatching = false;
    for (var element in this) {
      if (test(element)) {
        if (foundMatching) {
          throw StateError('Too many elements');
        }
        result = element;
        foundMatching = true;
      }
    }
    if (foundMatching) return result;
    return null;
  }
}

/// web browsers history API allows to store states;
/// dart objects must be serializable to JS maps.
abstract class StateObject {
  Map<String, dynamic> toMap();
}

/// representation of an url with an optional history state;
/// a Url's path always starts with '/'
class Url<T extends StateObject> {
  static RegExp get _regex => RegExp(r'[-a-zA-Z0-9%_\+~/]*');
  Url(this.path, {this.params = const{}, this.query = const{}, this.code = 200, this.userState}){
    if (!_regex.hasMatch(path)){
      throw FormatException("invalid url path '$path'");
    }
  }
  final int code;
  final String path;
  final T? userState;
  final Map<String,String> params;
  final Map<String,String> query;

  String get queryString => query.entries.map((e) => '${e.key}=${e.value}').join('&');

  @override
  String toString() => query.isEmpty ? path : '$path?$queryString';
}

/// a segment of an Url / path; everything between '/'
class _Segment {
  _Segment(this.index, this.name){
    if ((_validationRegex.stringMatch(name)?.length ?? 0) != name.length){
      throw FormatException("invalid url segment '$name'");
    }
  }
  final String name;
  final int index;

  RegExp get _validationRegex => RegExp(r"[-a-zA-Z0-9_.~!\*\(\);:@&=+\$,%\[\]']+");

  @override
  String toString() => name;
}

/// the definition of a segment used by [Route]
class _SegmentTemplate extends _Segment{
  
  factory _SegmentTemplate.from(int index, String template) {
    if (template.startsWith(':')) {
      return _ValueSegmentTemplate(index, template);
    }
    return _SegmentTemplate(index, template);
  }
  _SegmentTemplate(int index, String template): super(index, template);

  @override
  RegExp get _validationRegex => RegExp(r'[-a-zA-Z0-9%_\+~]+');

  /// used for testing if a [_Segment] matches a template
  bool matches(_Segment f) => name == f.name;

  /// the value used for semantical comparison:
  /// in the context of url matching a route 'resource/:var1' is the same as 'resource/:var2':
  /// if we receive an url 'resource/17' we don't know wether it applies to route 'resource/:var1' or 'resource/:var2'
  String get templateIdentity => name;

  String get label => name;
}

/// definition of a segment used by [Route] that contains a named placeholder
/// filled with string values in "real" urls
class _ValueSegmentTemplate extends _SegmentTemplate {
  _ValueSegmentTemplate(int index, this.label): super(index, label.substring(1));
  @override
  final String label;
  @override
  bool matches(_Segment f) => true;
  @override
  String get templateIdentity => '-';
}

abstract class _RouteBase<T extends StateObject> {
  /// the title of a web page
  String get title;
  /// the operation being called upon receiving an url / open navigation (internally and back-button)
  bool Function(Url<T> url) get onActivate;

  /// used to ensure toString() override
  String get representation;

  @override
  String toString() => representation;
}

/// default route
class Route<T extends StateObject> extends _RouteBase<T>{
  /// Route can only be created using [Router.register]
  Route._(String blueprint, this._router, this.title, this.onActivate, this._fromMap):
    segments = blueprint
      .truncate('/').split('/').asMap().entries
      .map((e) => _SegmentTemplate.from(e.key, e.value)).toList() {

      final valueTemplates = segments.whereType<_ValueSegmentTemplate>()
        .map((e) => e.name).toList(growable: false);
      if (valueTemplates.length > valueTemplates.toSet().length){
        throw StateError('ambiguous parameter names: $valueTemplates');
      }
      templateIdentity = segments.map((f) => f.templateIdentity).join().hashCode;
    }

  @override
  final String title;
  @override
  final bool Function(Url<T> url) onActivate;
  final List<_SegmentTemplate> segments;
  final T Function(Map<dynamic, dynamic> map)? _fromMap;
  /// mind cyclic references: never make it public
  final Router _router;
  late final int templateIdentity;

  bool _isActive = false;
  bool get isActive => _isActive;

  /// for instantiating state objects
  T? deserializeState(Map<dynamic, dynamic>? map) => (_fromMap != null && map != null) ? _fromMap!(map) : null;

  String _toUrlPath(Map<String,String> params) => '/' + segments.map((e) => params.containsKey(e.name) ? params[e.name] : e.name).join('/');

  Url<T> _toUrl(String path, Map<String,String> params, Map<String, String> query, [T? userState]) =>
    Url<T>(path, params: params, query: query, userState: userState);

  /// integrate key value pairs into url path and create [Url] object
  Url<T> toUrl({Map<String,String> params = const{}, Map<String, String> query = const{}, T? userState}) {
    // check if parameters are complete
    final missing = segments.whereType<_ValueSegmentTemplate>().where((s) => !params.containsKey(s.name));
    if (missing.isNotEmpty){
      throw StateError('missing parameters: ${missing.map((e) => e.name).toList()}');
    }
    return Url<T>(_toUrlPath(params), params: params, query: query, userState: userState);
  }

  /// infers key value pairs from url paths;
  /// checks if numbers of values to infer is lower than the length of [from]
  Map<String, String> inferParameters({required List<_Segment> from}) {
    final valueTemplates = segments.whereType<_ValueSegmentTemplate>();
    assert(valueTemplates.length <= from.length);
    final params = <String,String>{};
    valueTemplates.forEach((vf) => params[vf.name] = from[vf.index].name);
    return params;
  }


  @override
  String get representation => '/' + segments.map((f) => f.label).join('/');

  /// deactivate all other routes and if this route's callback allows us to do so, active it
  void _activate(Url<T> url)  {
    assert(_router._routes.contains(this));
    _router._routes.forEach((e) => e._isActive = false);
    if (onActivate(url)){
      _isActive = true;
    } else {
      _router.errorRoute.onActivate(Url<T>(url.toString(), code: 403));
    }
  }

  /// activate a route and push a new state to the browser history using [Router._pushState] / 
  /// [HashRouter._pushState] method to determine the appropriate url
  Url navigateTo({Map<String,String> params = const{}, Map<String, String> query = const{}, T? userState})  {
    final url = toUrl(params: params, query: query, userState: userState);
    _activate(url);
    _router._pushState(userState, title, url);
    return url;
  }
}

/// error route; not bound to a path; [onActivate] is called whenever an error with routing occurs (403,404)
class ErrorRoute extends _RouteBase{
  ErrorRoute._(this.onActivate);
  @override
  String get representation => '__error__';
  @override
  String get title => 'Error';
  @override
  final bool Function(Url url) onActivate;
  
}

/// registry of the routes
class Router {
  Router({required bool Function(Url url) onError, String root = '/'}):
    errorRoute = ErrorRoute._(onError),
    _root = root {
    window.onPopState.listen((PopStateEvent e) {
      go(e.state);
    });
  }
  final String _root;
  final _routes = <Route>{};
  final ErrorRoute errorRoute;
  String get root => _root;
  Route? get current => _routes.atMostOneWhere((r) => r.isActive);

  /// creates a route from the parameters, adds it to the set of routes and returns it
  Route<T> register<T extends StateObject>(String path, String name, bool Function(Url<T> url) onActivate, {T Function(Map<dynamic, dynamic>)? fromMap}){
    final route = Route._(path, this, name, onActivate, fromMap);
    final conflict = _routes.atMostOneWhere((r) => r.templateIdentity == route.templateIdentity);
    if (conflict != null) {
      throw StateError("'$route' in conflict with '$conflict'");
    }
    _routes.add(route);
    return route;
  }

  /// puts userState and url to the browsers history stack; allows to be overridden by HashRouter
  void _pushState<T extends StateObject>(T? userState, String title, Url<T> url) {
    window.history.pushState(userState?.toMap(), title, url.toString());
    document.title = title;
  }

  /// handling popState and initial
  void go([dynamic state]) {
    final path = (window.location.pathname ?? '').truncateLeft(_root);
    final queryString = (window.location.search ?? '').replaceFirst(r'^\?', '');
    _handle(path, queryString, state);
  }

  /// shortcut to register existing route with different path
  Route<T> redirect<T extends StateObject>({required String from, required Route<T> to, String? title}) =>
    register<T>(from, title ?? to.title, to.onActivate, fromMap: to._fromMap);

  /// handling popState and initial calls using a path
  void _handle(final String path, final String queryString, [dynamic state]){
    final query = <String,String>{};
    
    if (queryString.isNotEmpty){
      for (var pairStr in queryString.split('&')) {
        final pair = pairStr.split('=');
        query[pair[0]] = pair[1];
      }
    }

    final urlSegments = path.truncate('/').split('/').asMap().entries
      .map((e) => _Segment(e.key, e.value)).toList();
    final candidates = _routes.where((r) => r.segments.length == urlSegments.length);

    final route = candidates.atMostOneWhere((r) => r.segments.every((f) => f.matches(urlSegments[f.index])));
    if (route == null) {
      errorRoute.onActivate(Url(path, code: 404));
    } else {
      final params = route.inferParameters(from: urlSegments);
      final url = route._toUrl(path, params, query, route.deserializeState(state));
      route._activate(url);
    }
  }
}

/// hash router allows for routing in normal .html files; useful for testing
class HashRouter extends Router {
  HashRouter({required bool Function(Url url) onError}):
    super(onError: onError, root: '');
  @override
  String get root => '#';

  @override
  void go([dynamic state]) {
    final path = window.location.hash.truncateLeft(root);
    final queryString = (window.location.search ?? '').replaceFirst(r'?', '');
    _handle(path, queryString, state);
  }

  @override
  void _pushState<T extends StateObject>(T? userState, String title, Url<T> url) {
    final location = window.location.pathname ?? '';
    final q = url.queryString.isEmpty ? '' : '?${url.queryString}';
    window.history.pushState(userState?.toMap(), title, '$location$q$root${url.path}');
    document.title = title;
  }
}

