import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smallest_agent_flutter/app.dart';
import 'package:smallest_agent_flutter/code_block.dart';
import 'package:smallest_agent_flutter/models.dart';

class MemoryTheme implements ThemePreferences {
  bool dark = false;
  @override
  Future<bool> read() async => dark;
  @override
  Future<void> write(bool value) async {
    dark = value;
  }
}

class FakeClient implements AgentClient {
  int queries = 0, streams = 0;
  String? prompt;
  bool fail = false,
      errorResult = false,
      missingResult = false,
      cancelled = false;
  Completer<AgentResult>? pending;
  AgentResult get answer => AgentResult(
    '**Hello!**\n\n```python\nprint("Hello")\n```',
    1,
    42,
    null,
    errorResult,
  );
  @override
  Future<bool> health() async => true;
  @override
  Future<AgentResult> query(String value) async {
    queries++;
    prompt = value;
    return pending?.future ?? Future.value(answer);
  }

  @override
  Future<void> stream(String value, void Function(AgentMessage) receive) async {
    streams++;
    prompt = value;
    if (fail) throw const FormatException('private provider exception');
    receive(
      const AgentMessage('SystemMessage', 'Agent initialized', {
        'subtype': 'init',
      }),
    );
    if (!missingResult)
      receive(
        AgentMessage('ResultMessage', 'Final answer received', {
          'result': answer.result,
          'num_turns': 1,
          'duration_ms': 42,
          'total_cost_usd': null,
          'is_error': errorResult,
        }),
      );
  }

  @override
  void cancel() {
    cancelled = true;
  }

  @override
  void dispose() {
    cancel();
  }
}

Future<void> mount(
  WidgetTester tester,
  FakeClient client, {
  MemoryTheme? theme,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    SmallestAgentApp(client: client, preferences: theme ?? MemoryTheme()),
  );
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all tabs update content on one application and retain the prompt',
    (tester) async {
      await mount(tester, FakeClient());
      await tester.enterText(
        find.byKey(const Key('prompt')),
        'Remember this question',
      );
      for (final item in [
        ['learn', 'Small enough to understand. Real enough to explore.'],
        ['setup', 'Two terminals. One learning application.'],
        ['architecture', 'See how the pieces connect.'],
        ['walkthrough', 'The same loop. A Flutter application.'],
        ['lab', 'Start with a little curiosity.'],
      ]) {
        await click(tester, find.byKey(Key('tab-${item[0]}')));
        expect(find.text(item[1]), findsOneWidget);
        final semantics = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(Key('tab-${item[0]}')),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.selected, true);
        if (item[0] == 'architecture')
          for (var n = 1; n <= 16; n++) {
            expect(find.byKey(Key('source-$n')), findsOneWidget);
          }
      }
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('prompt')))
            .controller!
            .text,
        'Remember this question',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Simple uses trimmed input and shows actual answer metrics', (
    tester,
  ) async {
    final client = FakeClient();
    await mount(tester, client);
    await click(tester, find.text('Simple'));
    await tester.enterText(find.byKey(const Key('prompt')), '  Hi  ');
    await click(tester, find.byKey(const Key('run')));
    expect(client.prompt, 'Hi');
    expect(client.queries, 1);
    expect(find.text('success'), findsOneWidget);
    expect(find.text('Not reported (USD)'), findsOneWidget);
    expect(find.byType(SafeMarkdown), findsOneWidget);
    expect(find.byType(CodeBlock), findsWidgets);
  });
  testWidgets('Stream displays safe events and expandable JSON', (
    tester,
  ) async {
    final client = FakeClient();
    await mount(tester, client);
    await click(tester, find.byKey(const Key('run')));
    expect(client.streams, 1);
    expect(find.text('success'), findsOneWidget);
    expect(find.text('2 events'), findsOneWidget);
    await click(tester, find.text('SystemMessage'));
    expect(find.byType(CodeBlock), findsWidgets);
  });
  testWidgets(
    'duplicate actions lock immediately until the request completes',
    (tester) async {
      final client = FakeClient()..pending = Completer<AgentResult>();
      await mount(tester, client);
      await click(tester, find.text('Simple'));
      final button = find.byKey(const Key('run'));
      await tester.ensureVisible(button);
      final action = tester.widget<FilledButton>(button).onPressed!;
      action();
      action();
      await tester.pump();
      expect(client.queries, 1);
      expect(
        tester.widget<TextField>(find.byKey(const Key('prompt'))).enabled,
        false,
      );
      client.pending!.complete(client.answer);
      await tester.pumpAndSettle();
      expect(find.text('success'), findsOneWidget);
    },
  );
  testWidgets('errors recover controls and theme choice persists', (
    tester,
  ) async {
    final client = FakeClient()..fail = true;
    final theme = MemoryTheme();
    await mount(tester, client, theme: theme);
    await click(tester, find.byKey(const Key('run')));
    expect(find.byKey(const Key('error')), findsOneWidget);
    expect(find.textContaining('private provider exception'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('run'))).onPressed,
      isNotNull,
    );
    await click(tester, find.byTooltip('Switch to dark mode'));
    expect(theme.dark, true);
  });
  testWidgets('SDK error and absent final result never show success', (
    tester,
  ) async {
    final client = FakeClient()..errorResult = true;
    await mount(tester, client);
    await click(tester, find.byKey(const Key('run')));
    expect(find.text('error'), findsOneWidget);
    client
      ..errorResult = false
      ..missingResult = true;
    await click(tester, find.byKey(const Key('run')));
    expect(find.text('success'), findsNothing);
    expect(find.byKey(const Key('error')), findsOneWidget);
  });
  testWidgets('narrow layout remains usable without Flutter overflow', (
    tester,
  ) async {
    await mount(tester, FakeClient());
    tester.view.physicalSize = const Size(430, 930);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await click(tester, find.byKey(const Key('tab-setup')));
    expect(tester.takeException(), isNull);
  });
}
