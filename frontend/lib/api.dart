import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class SseEvent {
  final String event;
  final dynamic data;
  const SseEvent(this.event, this.data);
}

Stream<SseEvent> readEvents(Stream<List<int>> bytes) async* {
  var event = 'message';
  final data = <String>[];
  // Streaming UTF-8 plus LineSplitter preserves multibyte codepoints and CRLF
  // even when individual bytes and SSE lines cross network chunks.
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield SseEvent(event, jsonDecode(data.join('\n')));
      event = 'message';
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
}

class ApiClient implements AgentClient {
  final Uri base;
  final http.Client Function() createClient;
  http.Client? _active;
  final _healthClient = http.Client();
  ApiClient({Uri? base, http.Client Function()? createClient})
    : base =
          base ??
          Uri.base.resolve(
            const String.fromEnvironment('API_BASE_URL', defaultValue: '/'),
          ),
      createClient = createClient ?? http.Client.new;
  Uri endpoint(String path) => base.resolve(path);
  String detail(String body, int status) {
    try {
      final value = jsonDecode(body);
      if (value is Json && value['detail'] is String)
        return value['detail'] as String;
    } catch (_) {}
    return 'The API request failed (HTTP $status).';
  }

  @override
  Future<bool> health() async {
    final response = await _healthClient
        .get(endpoint('/api/health'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200)
      throw ApiException(detail(response.body, response.statusCode));
    final value = jsonDecode(response.body);
    if (value is! Json ||
        value['status'] != 'ok' ||
        value['api_key_configured'] is! bool)
      throw const ApiException('Invalid health response.');
    return value['api_key_configured'] as bool;
  }

  @override
  Future<AgentResult> query(String prompt) async {
    final client = createClient();
    _active = client;
    try {
      final response = await client
          .post(
            endpoint('/api/agent/query'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(minutes: 3, seconds: 10));
      if (response.statusCode != 200)
        throw ApiException(detail(response.body, response.statusCode));
      return AgentResult.fromJson(jsonDecode(response.body) as Json);
    } finally {
      client.close();
      if (identical(_active, client)) _active = null;
    }
  }

  @override
  Future<void> stream(
    String prompt,
    void Function(AgentMessage) receive,
  ) async {
    final client = createClient();
    _active = client;
    try {
      final request = http.Request('POST', endpoint('/api/agent/stream'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'prompt': prompt});
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200)
        throw ApiException(
          detail(await response.stream.bytesToString(), response.statusCode),
        );
      var foundResult = false, done = false;
      await for (final frame in readEvents(
        response.stream.timeout(const Duration(seconds: 45)),
      )) {
        if (frame.event == 'error')
          throw ApiException(
            frame.data is Json && (frame.data as Json)['detail'] is String
                ? (frame.data as Json)['detail'] as String
                : 'The agent stream failed.',
          );
        if (frame.event == 'message') {
          final message = AgentMessage.fromJson(frame.data as Json);
          if (message.type == 'ResultMessage') foundResult = true;
          receive(message);
        }
        if (frame.event == 'done') {
          done = true;
          break;
        }
      }
      if (!foundResult || !done)
        throw const ApiException(
          'The stream closed before the agent finished. Please try again.',
        );
    } finally {
      client.close();
      if (identical(_active, client)) _active = null;
    }
  }

  @override
  void cancel() {
    _active?.close();
    _active = null;
  }

  @override
  void dispose() {
    cancel();
    _healthClient.close();
  }
}
