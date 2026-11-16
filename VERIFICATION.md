# Verification — 9 November 2026

## Toolchain

- Windows; Python 3.14.5 in this edition's isolated `.venv`.
- Flutter 3.47.9 stable / Dart 3.13.7, official SDK revision c197ca5199e9ee5661e865596c9c07294dfab51c. Flutter was absent from PATH, so validation used `$env:TEMP\codex-flutter-sdk` without editing PATH. The frontend launcher accepts that path explicitly.
- Python direct requirements and Flutter direct dependencies are pinned; frontend/pubspec.lock records resolved Dart dependencies.

## Automated checks

- Python backend: **28 passing tests** with `python -m pytest -p no:cacheprovider -q`.
- Dart client and Flutter widgets: **13 passing tests** (6 client/contract/SSE tests, 7 widget tests).
- Total: **41 passing automated tests**.
- `flutter analyze`: **No issues found**, with strict inference/casts enabled for source and tests.
- `flutter build web --no-web-resources-cdn`: successful production web bundle and Wasm compatibility dry run. Renderer resources are local. Both Material and Cupertino icon fonts are included; the earlier missing-font warning is resolved.
- Generator outputs are deterministic; all 16 source numbers/titles resolve, the SVG has five lifelines, and root/embedded build prompts are identical. The native Flutter diagram uses the generated labels, including Python's `stream_agent()` spelling.

Backend coverage includes bounded/chunked input, strict prompt/JSON/content-type validation, origin checks and explicit Flutter CORS, missing key, restrictive SDK options, safe projections/key redaction, provider/missing-result failures, SDK error subtypes, iterator closure and disconnect cancellation. No SDK model call is made by these tests.

Frontend coverage includes split single-byte UTF-8, CRLF, comments and multiline SSE data; typed results; final-result/done enforcement; safe errors; all five tab clicks on one mounted app; selected semantics; retained prompt; all 16 architecture cards; both response modes; highlighted answer fences; synchronous duplicate-submit lock; error recovery; theme persistence; and a narrow layout without Flutter overflow.

Tests caught an ExpansionTile/ListTile Material-surface assertion inside colored cards. Cards now supply a Material ancestor below their decoration, keeping event expansion and ink effects valid. Browser checks caught duplicate accessibility entries for tabs; MergeSemantics now exposes one button per tab.

## Real HTTP and browser verification

- Started FastAPI on 8300 with this project's interpreter and the exact `Start-Frontend.ps1 -FlutterPath ...` launcher on 4900. Verified the production bundle served by FastAPI separately from the actual Flutter development server.
- `scripts/check_http.py` passed against the running server: health/docs/OpenAPI, unknown API 404, input 400/403/413/415/422, both allowed development origins, foreign-origin rejection, no-key query 503 and SSE error without done, plus production JS/image/diagram/source assets.
- Chrome checks passed against **both** http://127.0.0.1:8300 and http://127.0.0.1:4900. Enabled Flutter's accessibility semantics, clicked all five tabs, checked headings, typed a prompt and verified its retention in the real POST body after revisits, downloaded workflow.svg, checked readable missing-key Stream feedback and persisted theme after reload. No browser page errors were reported.
- Inspected desktop/mobile screenshots and the native UML rendering. Screenshots are in `verification/`; the application adapts to 1440-pixel and 430-pixel viewports.
- Flutter's unfocused semantics textarea does not mirror its controller value, so browser retention is checked through the actual request body; widget tests independently inspect the retained controller text.
- Optional browser QA uses Python Playwright and the existing Chrome executable. It is not a runtime dependency. Install it in this environment with `python -m pip install playwright` before rerunning `scripts/check_browser.py`. The script refuses a configured backend before submitting a prompt, keeping this check free of model calls.

Only verification servers owned by this task were stopped. The temporary Flutter SDK is retained for the documented launcher override.

## Limits

No real backend/.env was created, borrowed or read from other editions. Live Claude authentication, account model access, billing and successful inference were not tested. Tests inject the SDK boundary; real browser requests exercise the missing-key path. Copy/download behavior and the UI target Flutter Web; native mobile/desktop scaffolding and platform packaging are outside this edition's scope. The workspace has no Git repository, so a Git diff was unavailable.
