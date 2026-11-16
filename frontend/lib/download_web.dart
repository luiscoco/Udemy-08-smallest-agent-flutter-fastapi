import 'package:web/web.dart' as web;

void downloadText(String name, String text, {String mime = 'text/plain'}) {
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:$mime;charset=utf-8,${Uri.encodeComponent(text)}'
    ..download = name;
  anchor.click();
}
