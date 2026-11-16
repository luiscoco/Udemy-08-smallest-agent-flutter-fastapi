import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smallest_agent_flutter/api.dart';
import 'package:smallest_agent_flutter/models.dart';

const result = <String, dynamic>{
  'result': 'Hello!',
  'num_turns': 1,
  'duration_ms': 42,
  'total_cost_usd': null,
  'is_error': false,
};
void main() {
  test(
    'SSE preserves one-byte UTF-8 chunks, CRLF, comments and multiline JSON',
    () async {
      final encoded = utf8.encode(
        ': heartbeat\r\n\r\nevent: message\r\ndata: {"text":\r\ndata: "héllo"}\r\n\r\nevent: done\ndata: {}\n\n',
      );
      final frames = await readEvents(
        Stream.fromIterable(encoded.map((byte) => [byte])),
      ).toList();
      expect(frames.length, 2);
      expect(frames.first.event, 'message');
      expect(frames.first.data, {'text': 'héllo'});
      expect(frames.last.event, 'done');
    },
  );
  test('query posts JSON and validates normalized result', () async {
    final client = ApiClient(
      base: Uri.parse('http://localhost:8300'),
      createClient: () => MockClient((request) async {
        expect(request.url.path, '/api/agent/query');
        expect(jsonDecode(request.body), {'prompt': 'Hi'});
        return http.Response(jsonEncode(result), 200);
      }),
    );
    expect((await client.query('Hi')).result, 'Hello!');
    client.dispose();
  });
  test('stream delivers a final result only with terminal done', () async {
    final client = ApiClient(
      base: Uri.parse('http://localhost'),
      createClient: () => MockClient(
        (_) async => http.Response(
          'event: message\ndata: ${jsonEncode({'type': 'ResultMessage', 'summary': 'Final', 'data': result})}\n\nevent: done\ndata: {}\n\n',
          200,
        ),
      ),
    );
    final messages = <AgentMessage>[];
    await client.stream('Hi', messages.add);
    expect(messages.single.type, 'ResultMessage');
    client.dispose();
  });
  test(
    'missing done or final result fails rather than inventing an answer',
    () async {
      for (final text in [
        'event: done\ndata: {}\n\n',
        'event: message\ndata: ${jsonEncode({'type': 'ResultMessage', 'summary': 'Final', 'data': result})}\n\n',
      ]) {
        final client = ApiClient(
          base: Uri.parse('http://localhost'),
          createClient: () => MockClient((_) async => http.Response(text, 200)),
        );
        await expectLater(
          client.stream('Hi', (_) {}),
          throwsA(isA<ApiException>()),
        );
        client.dispose();
      }
    },
  );
  test('safe SSE error and HTTP detail reach the UI', () async {
    final client = ApiClient(
      base: Uri.parse('http://localhost'),
      createClient: () => MockClient(
        (request) async => request.url.path.endsWith('stream')
            ? http.Response(
                'event: error\ndata: {"detail":"Configure the server key"}\n\n',
                200,
              )
            : http.Response('{"detail":"Origin is not allowed."}', 403),
      ),
    );
    await expectLater(
      client.stream('Hi', (_) {}),
      throwsA(
        predicate(
          (Object error) =>
              error.toString().contains('Configure the server key'),
        ),
      ),
    );
    await expectLater(
      client.query('Hi'),
      throwsA(
        predicate(
          (Object error) => error.toString().contains('Origin is not allowed.'),
        ),
      ),
    );
    client.dispose();
  });
  test(
    'public result contract rejects invalid values and retains SDK error',
    () {
      expect(
        () => AgentResult.fromJson({...result, 'num_turns': 'one'}),
        throwsFormatException,
      );
      expect(AgentResult.fromJson({...result, 'is_error': true}).isError, true);
      expect(
        () => AgentMessage.fromJson({
          'type': 'SecretMessage',
          'summary': 'raw',
          'data': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    },
  );
}
