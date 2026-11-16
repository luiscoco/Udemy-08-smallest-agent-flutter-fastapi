import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class CodeBlock extends StatelessWidget {
  final String code, language;
  const CodeBlock(this.code, {super.key, this.language = 'dart'});
  @override
  Widget build(BuildContext context) {
    const supported = [
      'dart',
      'python',
      'json',
      'powershell',
      'bash',
      'ini',
      'javascript',
      'typescript',
      'xml',
    ];
    final normalized = language == 'env' ? 'ini' : language;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xff18263e),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language.toUpperCase(),
            style: const TextStyle(color: Color(0xffb7c9e5), fontSize: 16),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: supported.contains(normalized)
                ? HighlightView(
                    code,
                    language: normalized,
                    theme: atomOneDarkTheme,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      height: 1.6,
                    ),
                    padding: const EdgeInsets.all(8),
                  )
                : SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      height: 1.6,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class FencedCodeBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final child = element.children?.whereType<md.Element>().firstOrNull;
    final language =
        child?.attributes['class']?.replaceFirst('language-', '') ?? 'text';
    return CodeBlock(element.textContent, language: language);
  }
}

class SafeMarkdown extends StatelessWidget {
  final String data;
  const SafeMarkdown(this.data, {super.key});
  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: data,
    selectable: true,
    builders: {'pre': FencedCodeBuilder()},
    // Flutter widgets do not execute HTML or scripts. Suppress remote images.
    imageBuilder: (uri, title, alt) => Text(alt ?? '[Image omitted]'),
    onTapLink: (text, href, title) {
      final uri = Uri.tryParse(href ?? '');
      if (uri != null && ['https', 'http'].contains(uri.scheme)) launchUrl(uri);
    },
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        fontSize: 21,
        height: 1.65,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
