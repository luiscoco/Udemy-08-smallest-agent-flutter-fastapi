import 'dart:math' as math;

import 'package:flutter/material.dart';

class WorkflowDiagram extends StatelessWidget {
  final List<Map<String, dynamic>> steps;
  const WorkflowDiagram(this.steps, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'UML sequence diagram. Five participants and 16 interactions. Full text and code follow below.',
    child: SizedBox(
      height: 650,
      child: InteractiveViewer(
        constrained: false,
        minScale: 0.35,
        maxScale: 2,
        child: CustomPaint(
          size: const Size(1440, 1660),
          painter: _WorkflowPainter(steps),
        ),
      ),
    ),
  );
}

class _WorkflowPainter extends CustomPainter {
  final List<Map<String, dynamic>> steps;
  _WorkflowPainter(this.steps);
  void text(
    Canvas canvas,
    String value,
    double x,
    double y, {
    double size = 18,
    double width = 500,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: const Color(0xff142547),
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset(x, y));
  }

  void arrow(Canvas canvas, double x1, double x2, double y, bool returns) {
    final paint = Paint()
      ..color = const Color(0xff285b98)
      ..strokeWidth = 2;
    if (returns) {
      final left = math.min(x1, x2), right = math.max(x1, x2);
      for (double x = left; x < right; x += 14) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 7, right), y), paint);
      }
    } else {
      canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    }
    final direction = x2 > x1 ? 1.0 : -1.0;
    canvas.drawLine(Offset(x2, y), Offset(x2 - direction * 12, y - 6), paint);
    canvas.drawLine(Offset(x2, y), Offset(x2 - direction * 12, y + 6), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfff5f9ff),
    );
    text(
      canvas,
      'One prompt, from Flutter to Claude and back',
      45,
      35,
      size: 28,
      bold: true,
      width: 1350,
    );
    const xs = [145.0, 425.0, 705.0, 985.0, 1265.0];
    const names = [
      'Student / Browser',
      'Flutter client',
      'FastAPI + service',
      'Python Agent SDK',
      'Claude API',
    ];
    for (var i = 0; i < xs.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xs[i] - 130, 105, 260, 70),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xffe4efff),
      );
      text(
        canvas,
        names[i],
        xs[i] - 118,
        124,
        size: 20,
        width: 245,
        bold: true,
      );
      for (double y = 180; y < 1580; y += 14) {
        canvas.drawLine(
          Offset(xs[i], y),
          Offset(xs[i], y + 7),
          Paint()..color = const Color(0xff9baec7),
        );
      }
    }
    const starts = [0, 1, 2, 2, 3, 4, 3, 2, 1, 3, 2, 1, 2, 2, 1, 2];
    const ends = [1, 2, 2, 3, 4, 3, 2, 1, 0, 2, 1, 0, 1, 1, 0, 1];
    const ys = [
      225.0,
      285.0,
      385.0,
      470.0,
      535.0,
      600.0,
      720.0,
      795.0,
      875.0,
      1025.0,
      1090.0,
      1155.0,
      1220.0,
      1335.0,
      1400.0,
      1540.0,
    ];
    void frame(double y, double height, String label) {
      canvas.drawRect(
        Rect.fromLTWH(45, y, 1350, height),
        Paint()
          ..color = const Color(0xff9baec7)
          ..style = PaintingStyle.stroke,
      );
      text(canvas, label, 58, y + 8, bold: true, width: 1250);
    }

    frame(320, 1260, 'alt [valid prompt and configured key]');
    frame(630, 290, 'loop [each intermediate SDK message]');
    frame(940, 500, 'alt [final result / SDK failure]');
    text(
      canvas,
      'else [SDK failure or missing final result]',
      70,
      1250,
      bold: true,
    );
    text(
      canvas,
      'else [missing key or invalid input; SDK is not called]',
      58,
      1460,
      bold: true,
    );
    for (var i = 0; i < 16; i++) {
      final x1 = xs[starts[i]], x2 = xs[ends[i]], y = ys[i];
      if (x1 == x2) {
        canvas.drawRect(
          Rect.fromLTWH(x1, y - 25, 65, 25),
          Paint()
            ..color = const Color(0xff285b98)
            ..style = PaintingStyle.stroke,
        );
        text(
          canvas,
          '${i + 1}. ${steps[i]['title']}',
          x1 + 80,
          y - 25,
          width: 450,
        );
      } else {
        arrow(canvas, x1, x2, y, i >= 5);
        text(
          canvas,
          '${i + 1}. ${steps[i]['title']}',
          math.min(x1, x2) + 8,
          y - 28,
          width: (x2 - x1).abs() + 160,
        );
      }
    }
    text(
      canvas,
      'Dashed arrows carry responses. Done closes transport; is_error still means failure.',
      45,
      1600,
      width: 1340,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkflowPainter oldDelegate) =>
      oldDelegate.steps != steps;
}
