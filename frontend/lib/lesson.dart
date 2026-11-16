import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart' show LessonCard;
import 'code_block.dart';
import 'download.dart';
import 'workflow_diagram.dart';

class Lesson extends StatefulWidget {
  final String section;
  final void Function(String) onNavigate;
  const Lesson({super.key, required this.section, required this.onNavigate});
  @override
  State<Lesson> createState() => _LessonState();
}

class _LessonState extends State<Lesson> {
  late final source = rootBundle
      .loadString('assets/workflow.json')
      .then(
        (text) =>
            (jsonDecode(text) as List<dynamic>).cast<Map<String, dynamic>>(),
      );
  Widget heading(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Text(text),
      ],
    ),
  );
  Widget next(String label, String section) => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton(
      onPressed: () => widget.onNavigate(section),
      child: Text(label),
    ),
  );
  Widget card(Map<String, dynamic> step) => LessonCard(
    key: Key('source-${step['number']}'),
    color: (step['number'] as int) % 4,
    eyebrow: 'UML STEP ${step['number']} · SELECTED SOURCE EXCERPT',
    title: '${step['number']}. ${step['title']}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step['text'] as String),
        const SizedBox(height: 12),
        Text(
          step['source'] as String,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
        ),
        CodeBlock(step['code'] as String, language: step['language'] as String),
        Text(
          'How this code explains step ${step['number']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(step['explanation'] as String),
      ],
    ),
  );
  Future<void> downloadDiagram(String extension) async {
    try {
      final text = await rootBundle.loadString('assets/workflow.$extension');
      downloadText(
        'workflow.$extension',
        text,
        mime: extension == 'svg' ? 'image/svg+xml' : 'text/plain',
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Download unavailable. Diagram source is in frontend/assets.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section == 'learn') {
      const concepts = [
        [
          'Recognize the original agent',
          'A prompt enters query(). An async-for loop observes messages. ResultMessage carries the final answer, just like the terminal lesson.',
        ],
        [
          'Understand the server boundary',
          'Flutter owns interaction. FastAPI validates the request. A Python service owns the actual Claude Agent SDK loop.',
        ],
        [
          'Build reactive Flutter widgets',
          'StatefulWidget and setState update the prompt, timeline and answer. Lesson tabs change content while retaining lab state.',
        ],
        [
          'Keep credentials private',
          'Only backend/.env or the Python process environment contains the key. Flutter receives presence, never the secret.',
        ],
        [
          'Observe real SDK messages',
          'An HTTP POST opens an SSE stream. Safe initialization, assistant and result projections arrive as SDK messages rather than individual tokens.',
        ],
        [
          'Render code and answers safely',
          'HighlightView colors snippets. Markdown becomes Flutter widgets without executing model HTML or JavaScript. Remote answer images are omitted and only HTTP(S) links are opened.',
        ],
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'Small enough to understand. Real enough to explore.',
            'Trace a question through Flutter, FastAPI and the Python Claude Agent SDK.',
          ),
          for (var i = 0; i < concepts.length; i++)
            LessonCard(
              color: i,
              title: concepts[i][0],
              eyebrow: '0${i + 1} / LEARN',
              child: Text(concepts[i][1]),
            ),
          const LessonCard(
            color: 2,
            title: 'The core loop stays small.',
            child: Text(
              'This is the actual Agent SDK, with built-in tools disabled, isolated settings and one agent turn by default. Flutter and FastAPI supply the application around it.',
            ),
          ),
          next('Set up the application →', 'setup'),
        ],
      );
    }
    if (widget.section == 'setup') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'Two terminals. One learning application.',
            'Use Flutter stable with web support, Git for Windows and Python 3.11 or newer. Node.js and .NET are unnecessary for this edition.',
          ),
          const LessonCard(
            title: '1. Install from the new application root',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From Lesson 0, use this edition’s own Python interpreter:',
                ),
                CodeBlock(
                  'cd .\\08-smallest-agent-flutter-fastapi\npython -m venv .venv\n.\\.venv\\Scripts\\python.exe -m pip install -r backend/requirements.txt\nflutter --version\nflutter doctor\ncd frontend\nflutter pub get\ncd ..',
                  language: 'powershell',
                ),
              ],
            ),
          ),
          const LessonCard(
            color: 1,
            title: '2. Configure backend/.env',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CodeBlock(
                  'if (!(Test-Path backend/.env)) { Copy-Item backend/.env.example backend/.env }\nnotepad backend/.env',
                  language: 'powershell',
                ),
                CodeBlock(
                  'ANTHROPIC_API_KEY=your_actual_api_key\nCLAUDE_MODEL=\nAGENT_SYSTEM_PROMPT=\nAGENT_MAX_TURNS=1',
                  language: 'ini',
                ),
                Text(
                  'Replace the key placeholder. Leave model/system prompt blank for SDK defaults. Turns accept 1–10; one is the lesson default. Process variables override this file. Restart FastAPI after changes. Never put keys in Dart or --dart-define.',
                ),
              ],
            ),
          ),
          const LessonCard(
            color: 2,
            title: '3. Start the Python backend',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terminal 1, from 08-smallest-agent-flutter-fastapi:'),
                CodeBlock(
                  '.\\.venv\\Scripts\\python.exe backend/run.py',
                  language: 'powershell',
                ),
                Text(
                  'FastAPI: http://127.0.0.1:8300 · Swagger: http://127.0.0.1:8300/docs. Start-Backend.ps1 finds this project and its interpreter independently of your current directory.',
                ),
              ],
            ),
          ),
          const LessonCard(
            color: 3,
            title: '4. Start Flutter Web',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terminal 2, from 08-smallest-agent-flutter-fastapi:'),
                CodeBlock('.\\Start-Frontend.ps1', language: 'powershell'),
                Text(
                  'Open http://127.0.0.1:4900 manually. The helper runs Flutter’s web-server device with the public backend address configured. It does not require Chrome to be launched by Flutter. Keep both terminals running; Ctrl+C stops each.',
                ),
              ],
            ),
          ),
          const LessonCard(
            title: 'Verify and build',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CodeBlock(
                  '.\\.venv\\Scripts\\python.exe scripts/generate_lesson.py\n.\\.venv\\Scripts\\python.exe -m pytest backend/tests -p no:cacheprovider\ncd frontend\nflutter analyze\nflutter test\nflutter build web\ncd ..\n.\\.venv\\Scripts\\python.exe backend/run.py',
                  language: 'powershell',
                ),
                Text(
                  'Stop development first. The production Flutter build uses same-origin API paths and FastAPI serves it on http://127.0.0.1:8300. Development allows only the explicit localhost/127.0.0.1:4900 origins. Health checks connectivity/key presence, not authentication or available credits.',
                ),
              ],
            ),
          ),
          next('Try Hello world! →', 'lab'),
        ],
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: source,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Text(
            'Teaching source could not load. Run scripts/generate_lesson.py and rebuild Flutter.',
          );
        if (!snapshot.hasData)
          return const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          );
        final steps = snapshot.data!;
        if (widget.section == 'architecture')
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(
                'See how the pieces connect.',
                'Flutter handles interaction. FastAPI validates input and sends safe events. The Python SDK service owns execution.',
              ),
              const LessonCard(
                title: 'Flutter → FastAPI → Agent SDK → Claude',
                child: Text(
                  'The SDK manages its CLI runtime and model exchange. The browser posts prompts to FastAPI and consumes safe SSE message projections. Server-only options contain the key and disable built-in tools.',
                ),
              ),
              LessonCard(
                color: 1,
                title: 'From a click to a final answer',
                eyebrow: 'UML SEQUENCE DIAGRAM',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Read top to bottom. Five lifelines, a repeated-message loop and success/error/input alternatives explain all 16 interactions. Drag to pan and pinch or use trackpad gestures to zoom. Every arrow has a numbered source card below.',
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: WorkflowDiagram(steps),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        TextButton(
                          onPressed: () => downloadDiagram('svg'),
                          child: const Text('Download UML (SVG)'),
                        ),
                        TextButton(
                          onPressed: () => downloadDiagram('puml'),
                          child: const Text('Download PlantUML'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              heading(
                'Follow every UML arrow in the code',
                'All 16 excerpts are generated from this application’s actual Dart and Python source. Surrounding context is omitted.',
              ),
              for (final step in steps) card(step),
              const LessonCard(
                color: 3,
                title: 'Transport completion is not agent success.',
                child: Text(
                  'A final result and done are both required. Error SDK subtypes remain failures even if is_error was false. Streaming shows SDK messages, rather than individual tokens.',
                ),
              ),
              next('Follow the source code →', 'walkthrough'),
            ],
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(
              'The same loop. A Flutter application.',
              'Actual Dart and Python excerpts explain input, validation, server delegation, SDK results and safe presentation.',
            ),
            for (final step in steps.where(
              (step) => [1, 3, 4, 10, 12].contains(step['number']),
            ))
              card(step),
            next('Watch it run →', 'lab'),
          ],
        );
      },
    );
  }
}
