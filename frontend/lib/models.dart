typedef Json = Map<String, dynamic>;

class AgentResult {
  final String result;
  final int numTurns, durationMs;
  final double? cost;
  final bool isError;
  const AgentResult(
    this.result,
    this.numTurns,
    this.durationMs,
    this.cost,
    this.isError,
  );
  factory AgentResult.fromJson(Json data) {
    if (data['result'] is! String ||
        data['num_turns'] is! int ||
        data['duration_ms'] is! int ||
        data['is_error'] is! bool ||
        (data['total_cost_usd'] != null && data['total_cost_usd'] is! num)) {
      throw const FormatException('The API returned an invalid result.');
    }
    return AgentResult(
      data['result'] as String,
      data['num_turns'] as int,
      data['duration_ms'] as int,
      (data['total_cost_usd'] as num?)?.toDouble(),
      data['is_error'] as bool,
    );
  }
}

class AgentMessage {
  final String type, summary;
  final Json data;
  final int elapsed;
  const AgentMessage(this.type, this.summary, this.data, [this.elapsed = 0]);
  factory AgentMessage.fromJson(Json json) {
    const types = [
      'SystemMessage',
      'AssistantMessage',
      'UserMessage',
      'ResultMessage',
      'OtherMessage',
    ];
    if (!types.contains(json['type']) ||
        json['summary'] is! String ||
        json['data'] is! Json)
      throw const FormatException('The API returned an invalid message.');
    final message = AgentMessage(
      json['type'] as String,
      json['summary'] as String,
      json['data'] as Json,
    );
    if (message.type == 'ResultMessage') AgentResult.fromJson(message.data);
    return message;
  }
}

abstract class AgentClient {
  Future<bool> health();
  Future<AgentResult> query(String prompt);
  Future<void> stream(String prompt, void Function(AgentMessage) receive);
  void cancel();
  void dispose();
}
