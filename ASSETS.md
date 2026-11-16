# Asset provenance

frontend/assets/astronaut.png is the known local course astronaut, copied only from the earlier edition's public image. Original reference: https://github.com/luiscoco/Udemy-Claude-Agent-SDK-lesson01-app at commit 832439954c11d4f3623d1b4a311f7dd67389fcc8. Preserve upstream rights/attribution when redistributing course material. No real environment file was copied.

The workflow SVG and PlantUML templates are adapted locally to Flutter/Dart and FastAPI/Python. Their 16 numbers/titles drive generated source cards and the native Flutter diagram. Native diagram painting avoids an external rendering service and keeps text/zoom available in the Flutter application. Generated safe assets live in frontend/assets.

Material icons come from the Flutter SDK. Code colors use flutter_highlight's atom-one-dark theme. Markdown is rendered with flutter_markdown_plus. System/default Flutter typography is used; no application-specific remote font URL is needed.
