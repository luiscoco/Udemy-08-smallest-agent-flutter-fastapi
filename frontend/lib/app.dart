import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'code_block.dart';
import 'download.dart';
import 'lesson.dart';
import 'models.dart';

abstract class ThemePreferences {
  Future<bool> read();
  Future<void> write(bool dark);
}

class SavedTheme implements ThemePreferences {
  final storage = SharedPreferencesAsync();
  @override
  Future<bool> read() async => await storage.getBool('agent-dark') ?? false;
  @override
  Future<void> write(bool dark) => storage.setBool('agent-dark', dark);
}

class SmallestAgentApp extends StatefulWidget {
  final AgentClient? client;
  final ThemePreferences? preferences;
  const SmallestAgentApp({super.key, this.client, this.preferences});
  @override
  State<SmallestAgentApp> createState() => _SmallestAgentAppState();
}

class _SmallestAgentAppState extends State<SmallestAgentApp> {
  bool dark = false;
  late final ThemePreferences preferences = widget.preferences ?? SavedTheme();
  @override
  void initState() {
    super.initState();
    preferences
        .read()
        .then((value) {
          if (mounted) setState(() => dark = value);
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) {
      final base = ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorSchemeSeed: const Color(0xff0865cf),
      );
      return base.copyWith(
        scaffoldBackgroundColor: dark
            ? const Color(0xff0b1529)
            : const Color(0xfff4f8ff),
        textTheme: base.textTheme.copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 21,
            height: 1.65,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 21,
            height: 1.65,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 16,
            height: 1.5,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 18),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      );
    }

    return MaterialApp(
      title: 'The Smallest Agent · Flutter + FastAPI',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: AgentHome(
        client: widget.client,
        dark: dark,
        toggleTheme: () {
          setState(() => dark = !dark);
          preferences.write(dark).catchError((Object _) {});
        },
      ),
    );
  }
}

class LessonCard extends StatelessWidget {
  final Widget child;
  final int color;
  final String? title, eyebrow;
  const LessonCard({
    super.key,
    required this.child,
    this.color = 0,
    this.title,
    this.eyebrow,
  });
  @override
  Widget build(BuildContext context) {
    const light = [
      Color(0xffedf5ff),
      Color(0xfff3edff),
      Color(0xffeaf7f0),
      Color(0xfffff2e6),
    ];
    const dark = [
      Color(0xff182e4c),
      Color(0xff2a2445),
      Color(0xff17362e),
      Color(0xff392a24),
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark
            ? dark
            : light)[color % 4],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Text(
              eyebrow!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

class RunIntent extends Intent {
  const RunIntent();
}

class AgentHome extends StatefulWidget {
  final AgentClient? client;
  final bool dark;
  final VoidCallback toggleTheme;
  const AgentHome({
    super.key,
    this.client,
    required this.dark,
    required this.toggleTheme,
  });
  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  late final AgentClient client = widget.client ?? ApiClient();
  final prompt = TextEditingController(text: 'Hello world!');
  final scroll = ScrollController();
  String section = 'lab', mode = 'stream', status = 'idle', error = '';
  bool? keyConfigured;
  bool checked = false, connected = false, busy = false;
  AgentResult? result;
  final messages = <AgentMessage>[];
  final clock = Stopwatch();
  Timer? timer;
  static const sections = {
    'lab': 'Application lab',
    'learn': 'What you will learn',
    'setup': 'How to run',
    'architecture': 'Architecture & workflow',
    'walkthrough': 'Code walkthrough',
  };
  @override
  void initState() {
    super.initState();
    client
        .health()
        .then((value) {
          if (mounted)
            setState(() {
              checked = true;
              connected = true;
              keyConfigured = value;
            });
        })
        .catchError((Object _) {
          if (mounted) setState(() => checked = true);
        });
  }

  @override
  void dispose() {
    timer?.cancel();
    client.cancel();
    if (widget.client == null) client.dispose();
    prompt.dispose();
    scroll.dispose();
    super.dispose();
  }

  void notify(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 7)),
      );
  }

  void select(String next) {
    setState(() => section = next);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> run() async {
    final trimmed = prompt.text.trim();
    if (busy || trimmed.isEmpty || trimmed.length > 4000) return;
    busy = true;
    setState(() {
      status = 'running';
      error = '';
      result = null;
      messages.clear();
    });
    clock
      ..reset()
      ..start();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
    AgentResult? finalResult;
    try {
      if (mode == 'stream') {
        await client.stream(trimmed, (message) {
          if (!mounted) return;
          setState(() {
            if (messages.length < 500)
              messages.add(
                AgentMessage(
                  message.type,
                  message.summary,
                  message.data,
                  clock.elapsedMilliseconds,
                ),
              );
            if (message.type == 'ResultMessage') {
              finalResult = AgentResult.fromJson(message.data);
              result = finalResult;
            }
          });
        });
        if (finalResult == null)
          throw const ApiException(
            'The agent finished without a final result. Please try again.',
          );
      } else {
        finalResult = await client.query(trimmed);
        if (mounted) setState(() => result = finalResult);
      }
      if (finalResult!.isError)
        throw const ApiException(
          'The agent could not complete this prompt. Check the server configuration and try again.',
        );
      if (mounted) setState(() => status = 'success');
    } catch (err) {
      if (mounted) {
        final message = err is ApiException
            ? err.message
            : err is TimeoutException
            ? 'The agent timed out. Check the connection and try again.'
            : 'The request failed. Check the server connection and API key.';
        setState(() {
          error = message;
          status = 'error';
        });
        notify(message);
      }
    } finally {
      timer?.cancel();
      clock.stop();
      busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> copyAnswer() async {
    try {
      await Clipboard.setData(ClipboardData(text: result?.result ?? ''));
      notify('Answer copied');
    } catch (_) {
      notify('Clipboard unavailable. Select the answer to copy it.');
    }
  }

  Widget promptCard() => LessonCard(
    title: 'Give your agent a prompt',
    eyebrow: 'YOUR FIRST PYTHON AGENT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('prompt'),
          controller: prompt,
          enabled: !busy,
          minLines: 4,
          maxLines: 8,
          maxLength: 4000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'What would you like to ask?',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            helperText: 'Your first agent starts with a question.',
          ),
          style: const TextStyle(fontSize: 21, height: 1.6),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${prompt.text.trim().length}/4000 characters after trimming',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final example in [
              'Hello world!',
              'Explain what an AI agent is in one sentence.',
              'What is Python?',
            ])
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() => prompt.text = example),
                child: Text(example),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in ['stream', 'simple'])
              Semantics(
                selected: mode == value,
                child: ChoiceChip(
                  label: Text(value == 'stream' ? 'Stream' : 'Simple'),
                  selected: mode == value,
                  onSelected: busy ? null : (_) => setState(() => mode = value),
                ),
              ),
            FilledButton(
              key: const Key('run'),
              onPressed: busy || prompt.text.trim().isEmpty ? null : run,
              child: Text(busy ? 'Running…' : 'Run agent ↗'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          mode == 'stream'
              ? 'Watch every safe SDK message as it arrives · Ctrl + Enter'
              : 'Receive the final answer in one response · Ctrl + Enter',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  Widget answerCard() => LessonCard(
    color: 2,
    title: 'Agent’s answer',
    eyebrow: '02 / OUTPUT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status,
          key: const Key('status'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: status == 'error'
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Agent is working · ${clock.elapsedMilliseconds} ms',
                  ),
                ),
              ],
            ),
          ),
        if (error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                error,
                key: const Key('error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        if (result != null) ...[
          const SizedBox(height: 16),
          SafeMarkdown(result!.result),
          const SizedBox(height: 20),
          Wrap(
            spacing: 26,
            runSpacing: 12,
            children: [
              Text('${result!.numTurns} turns'),
              Text('${result!.durationMs} ms'),
              Text(
                result!.cost == null
                    ? 'Not reported (USD)'
                    : '\$${result!.cost!.toStringAsFixed(6)} USD',
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: copyAnswer,
                child: const Text('Copy answer'),
              ),
              TextButton(
                onPressed: () {
                  try {
                    downloadText(
                      'claude-answer.md',
                      result!.result,
                      mime: 'text/markdown',
                    );
                  } catch (_) {
                    notify('Download unavailable. Copy the answer instead.');
                  }
                },
                child: const Text('Download .md'),
              ),
            ],
          ),
        ],
        if (status == 'idle')
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Your next discovery starts with a question. Run the agent to see a real answer; no sample response is preloaded.',
            ),
          ),
      ],
    ),
  );
  Widget inspector() => LessonCard(
    color: 1,
    title: 'Message stream',
    eyebrow: 'INSIDE THE AGENT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${messages.length} events'),
        const Text(
          'Expand a safe SDK event to inspect its JSON. Streaming shows SDK messages rather than individual tokens.',
        ),
        if (messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              mode == 'simple'
                  ? 'Simple mode shows the final answer. Switch to Stream to inspect SDK messages.'
                  : 'Your agent’s journey starts here. Run a prompt to see real messages as they arrive.',
            ),
          ),
        for (final message in messages)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                message.type,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '+${message.elapsed} ms · ${message.summary}',
                style: const TextStyle(fontSize: 16),
              ),
              children: [
                CodeBlock(
                  const JsonEncoder.withIndent('  ').convert(message.data),
                  language: 'json',
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget lab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Start with a little curiosity.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text('One prompt. One agent. See exactly what comes back.'),
      const SizedBox(height: 24),
      Wrap(
        spacing: 30,
        runSpacing: 12,
        children: const [
          Text('01 / Ask a question'),
          Text('02 / Watch the stream'),
          Text('03 / Read the result'),
        ],
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, size) {
          if (size.maxWidth < 1000)
            return Column(children: [promptCard(), answerCard(), inspector()]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(children: [promptCard(), answerCard()]),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: inspector()),
            ],
          );
        },
      ),
      LessonCard(
        color: 3,
        title: 'The same agent, with a web application around it.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your prompt travels through Flutter → FastAPI → the Python Claude Agent SDK → Claude. Built-in tools are disabled and the key stays on the server. Submitting a prompt may use API credits.',
            ),
            TextButton(
              onPressed: () => select('architecture'),
              child: const Text('Explore the architecture →'),
            ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter, control: true): RunIntent(),
    },
    child: Actions(
      actions: {
        RunIntent: CallbackAction<RunIntent>(
          onInvoke: (_) {
            if (section == 'lab') run();
            return null;
          },
        ),
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            controller: scroll,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1480),
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'a·  The Smallest Agent',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            !checked
                                ? 'Checking server…'
                                : connected
                                ? 'Server connected'
                                : 'Server offline',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (keyConfigured == false)
                            const Text(
                              'API key not configured',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xffba4a16),
                              ),
                            ),
                          TextButton(
                            onPressed: () => launchUrl(
                              (client is ApiClient
                                  ? (client as ApiClient).endpoint('/docs')
                                  : Uri.parse('http://127.0.0.1:8300/docs')),
                            ),
                            child: const Text('API docs ↗'),
                          ),
                          IconButton(
                            tooltip: widget.dark
                                ? 'Switch to light mode'
                                : 'Switch to dark mode',
                            onPressed: widget.toggleTheme,
                            icon: Icon(
                              widget.dark ? Icons.light_mode : Icons.dark_mode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 44),
                      LayoutBuilder(
                        builder: (context, size) => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LEARN IT. BUILD IT. WATCH IT WORK.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Your first agent.\nA real web application.',
                                    style: TextStyle(
                                      fontSize: size.maxWidth < 700 ? 38 : 58,
                                      height: 1.1,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Take the smallest agent from the terminal to the browser. Ask a question, follow the messages, and understand every layer.',
                                  ),
                                  const SizedBox(height: 20),
                                  const Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      Chip(label: Text('Flutter + Dart')),
                                      Chip(label: Text('FastAPI + Python')),
                                      Chip(label: Text('Claude Agent SDK')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (size.maxWidth > 850)
                              SizedBox(
                                width: 280,
                                child: Image.asset(
                                  'assets/astronaut.png',
                                  semanticLabel: 'Waving course astronaut',
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      LessonCard(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final entry in sections.entries)
                              MergeSemantics(
                                child: Semantics(
                                  selected: section == entry.key,
                                  button: true,
                                  child: TextButton(
                                    key: Key('tab-${entry.key}'),
                                    onPressed: () => select(entry.key),
                                    style: TextButton.styleFrom(
                                      backgroundColor: section == entry.key
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : null,
                                    ),
                                    child: Text(entry.value),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (section == 'lab')
                        lab()
                      else
                        Lesson(section: section, onNavigate: select),
                      const Divider(height: 60),
                      const Text(
                        'The Smallest Agent · Flutter + FastAPI + Python Edition',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'A small agent at the core. A real application around it.',
                        style: TextStyle(fontSize: 16),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(
                            'https://github.com/luiscoco/Udemy-Claude-Agent-SDK-lesson01-app',
                          ),
                        ),
                        child: const Text('Course design reference ↗'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
