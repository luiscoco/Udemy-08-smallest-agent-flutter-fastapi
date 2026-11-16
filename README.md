# The Smallest Agent — Flutter + FastAPI + Python

Independent edition 08 with a real Flutter Web interface, Material 3 widgets, Dart HTTP/SSE client, FastAPI and the actual Python Claude Agent SDK. Includes the lab, five lesson tabs, large pastel cards, dark theme, colored source/Markdown code and a native 16-step UML diagram with SVG/PlantUML downloads.

## Prerequisites

- Python 3.11 or newer (verified with 3.14.5).
- Flutter stable with web support and Git for Windows. Verified SDK: Flutter 3.47.9 / Dart 3.13.7.
- A current browser. The web-server device lets you open the URL yourself; Android Studio, .NET and Node.js are unnecessary for this web edition.
- [Official Flutter setup](https://docs.flutter.dev/install/manual) and [web setup](https://docs.flutter.dev/platform-integration/web/setup).

Flutter was absent from PATH here. Validation uses an official SDK checked out to the temporary directory `$env:TEMP\codex-flutter-sdk`, without modifying PATH. That temporary SDK can be used now with `-FlutterPath` below; for lasting use install Flutter at your preferred location and add its bin directory to PATH. Reopen Windows Terminal after changing PATH.

## First-time installation — PowerShell

From **Lesson 0**:

```powershell
cd .\08-smallest-agent-flutter-fastapi
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
if (!(Test-Path backend/.env)) { Copy-Item backend/.env.example backend/.env }
notepad backend/.env
```

Set your own key:

```dotenv
ANTHROPIC_API_KEY=your_actual_api_key
CLAUDE_MODEL=
AGENT_SYSTEM_PROMPT=
AGENT_MAX_TURNS=1
```

Leave model/system prompt blank for SDK defaults. Turns accept 1–10 and default to one. Process environment overrides this project's backend/.env. Its location resolves from the config module, independently of cwd. Restart FastAPI after changes. Never copy keys from other editions, commit them or put them in Dart or --dart-define. Health only reports key presence, not authentication/credit/model readiness.

With Flutter on PATH, from the project root:

```powershell
flutter --version
flutter doctor
cd frontend
flutter pub get
cd ..
```

## Run — two terminals

**Terminal 1**, from Lesson 0:

```powershell
cd .\08-smallest-agent-flutter-fastapi
.\Start-Backend.ps1
```

Equivalent: `.\.venv\Scripts\python.exe backend/run.py` from this edition's root. Backend: **http://127.0.0.1:8300**. Swagger: **http://127.0.0.1:8300/docs**.

**Terminal 2**, from Lesson 0:

```powershell
cd .\08-smallest-agent-flutter-fastapi
.\Start-Frontend.ps1
```

If Flutter is not on PATH, use the temporary SDK created for this task:

```powershell
.\Start-Frontend.ps1 -FlutterPath "$env:TEMP\codex-flutter-sdk\bin\flutter.bat"
```

Open **http://127.0.0.1:4900** manually. Keep both terminals running; Ctrl+C stops each. Helpers resolve their own project paths. No npm command or another edition's Python interpreter is used. A missing .venv means run the installation commands from THIS project first.

The frontend helper runs `flutter pub get` and `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 4900 --dart-define=API_BASE_URL=http://127.0.0.1:8300` from frontend. That define is a public server address, never a secret. The only development origins allowed by FastAPI are http://127.0.0.1:4900 and http://localhost:4900; no wildcard CORS. Other ports require explicit configuration changes.

## Check and build

From **08-smallest-agent-flutter-fastapi**, with Flutter on PATH (or replace flutter with the absolute SDK command):

```powershell
.\.venv\Scripts\python.exe scripts/generate_lesson.py
.\.venv\Scripts\python.exe -m pytest -p no:cacheprovider -q
cd frontend
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
cd ..
```

Stop development, then run `.\Start-Backend.ps1`. FastAPI now serves the production Flutter Web build and API together at **http://127.0.0.1:8300**. The default production API address is same-origin; do not retain the development API_BASE_URL define when building for same-origin serving. Backend mounting occurs at startup, so restart it after the first build.

## How it works

`frontend/lib` contains actual Dart widgets, typed contracts and HTTP streaming. Lab state lives in AgentHome and remains intact while visiting lesson tabs. The native Flutter diagram pans/zooms, while the matching SVG and PlantUML remain downloadable. `scripts/generate_lesson.py` extracts 16 numbered snippets from actual Dart/Python files and checks SVG labels. Run it after source changes; commit its generated assets and pubspec.lock.

`backend/app` contains settings, strict Pydantic contracts, bounded input middleware and an isolated SDK service. SDK options remove built-ins, settings/skills/MCP/plugins, disable session persistence and default to one turn. The key goes to the SDK subprocess options without process-wide mutation. Safe projections exclude thinking, raw configuration, paths and session IDs. UTF-8 SSE supports comments, CRLF, split/multiline frames, final-result/done enforcement and disconnect cancellation. Server execution has a three-minute deadline. No preloaded live answers or paid calls in tests.

Markdown is rendered as Flutter widgets; HTML/JavaScript is not executed. Fenced source is colored with flutter_highlight. Remote answer images are omitted, links only open HTTP(S), unknown code languages remain plain text. Clipboard failures show feedback; Markdown and diagram downloads are implemented for the Web target. Native mobile/desktop scaffolding is not included in this web-focused edition.

API: GET /api/health, POST /api/agent/query, POST /api/agent/stream, /docs and /openapi.json. JSON validation returns safe 400/403/413/415/422 details; query missing key is 503 and provider failure 502. After stream headers, failures use an SSE error without done. A completed transport never overrides a failed SDK result.

See BUILD-PROMPT.txt for recreation instructions, ASSETS.md for provenance and VERIFICATION.md for actual checks and limitations.
