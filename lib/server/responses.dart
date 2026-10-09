import 'dart:convert';

import 'package:shelf/shelf.dart';

const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
const htmlHeaders = {'content-type': 'text/html; charset=utf-8'};

Response jsonOk(Object? body) =>
    Response.ok(jsonEncode(body), headers: jsonHeaders);

Response jsonError(int status, String message) => Response(
  status,
  body: jsonEncode({'error': message}),
  headers: jsonHeaders,
);
