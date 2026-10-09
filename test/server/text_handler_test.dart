import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/constants.dart';
import 'package:local_drop/server/server_event.dart';

import 'handler_test_utils.dart';

void main() {
  late HandlerFixture f;

  setUp(() async => f = await HandlerFixture.create());
  tearDown(() => f.dispose());

  const json = {'content-type': 'application/json'};

  Future<int> post(Object body, {Map<String, String> headers = json}) async =>
      (await f.send(
        'POST',
        '/api/text',
        headers: headers,
        body: body,
      )).statusCode;

  test('geçerli metin → 200 + TextReceived olayı', () async {
    expect(await post(jsonEncode({'text': 'merhaba şöğü 👋'})), 200);
    final event = f.events.single as TextReceived;
    expect(event.text, 'merhaba şöğü 👋');
  });

  test('tam sınırda metin kabul edilir', () async {
    // {"text":"..."} → 11 bayt JSON çerçevesi.
    final text = 'a' * (AppConstants.maxTextBytes - 11);
    expect(await post(jsonEncode({'text': text})), 200);
  });

  test('64 KB + 1 → 413 (Content-Length ile)', () async {
    final body = jsonEncode({'text': 'a' * AppConstants.maxTextBytes});
    expect(await post(body), 413);
    expect(f.events, isEmpty);
  });

  test('64 KB + 1 → 413 (akışta, Content-Length yok)', () async {
    final bytes = utf8.encode(
      jsonEncode({'text': 'a' * AppConstants.maxTextBytes}),
    );
    expect(await post(Stream.value(bytes)), 413);
    expect(f.events, isEmpty);
  });

  test('JSON değil → 400', () async {
    expect(await post('düz metin'), 400);
  });

  test('text eksik, boş ya da string değil → 400', () async {
    expect(await post(jsonEncode({'baska': 'x'})), 400);
    expect(await post(jsonEncode({'text': ''})), 400);
    expect(await post(jsonEncode({'text': 5})), 400);
    expect(await post(jsonEncode(['text'])), 400);
    expect(f.events, isEmpty);
  });

  test('bozuk UTF-8 → 400', () async {
    expect(await post(Stream.value([0x7b, 0xff, 0xfe, 0x7d])), 400);
  });

  test('token yok → 401', () async {
    final res = await f.send(
      'POST',
      '/api/text',
      auth: false,
      headers: json,
      body: jsonEncode({'text': 'x'}),
    );
    expect(res.statusCode, 401);
    expect(f.events, isEmpty);
  });
}
