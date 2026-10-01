import 'dart:js_interop';

@JS('fetch')
external JSPromise<_Response> _fetch(JSString endpoint);

extension type _Response(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSString> text();
}

// GET only, with no credentials or request body. No SDK plugin registration,
// account operation, or financial-data request is needed for this public policy.
Future<({int status, String body})> readStartupPolicy(String endpoint) async {
  if (!RegExp(
    r'^https://[a-z0-9-]+\.firebaseio\.com/app_config/min_version\.json$',
  ).hasMatch(endpoint)) {
    throw ArgumentError('Only the public startup-policy endpoint is permitted');
  }
  final response = await _fetch(endpoint.toJS).toDart;
  return (status: response.status, body: (await response.text().toDart).toDart);
}
