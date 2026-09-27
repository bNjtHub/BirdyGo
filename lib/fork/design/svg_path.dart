/// Minimal SVG path parser (J6e): draws the mockup's line glyphs (status
/// emblems, SPEC.md 4.3) without `flutter_svg`. Supports M L H V C S Q T A Z,
/// absolute and relative.
library;

import 'dart:ui';

final RegExp _token = RegExp(
  r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
);

/// Parses an SVG path `d` attribute.
Path parseSvgPath(String data) {
  final tokens = [for (final m in _token.allMatches(data)) m.group(0)!];
  final path = Path();
  var i = 0;
  var command = '';
  var current = Offset.zero;
  var start = Offset.zero;
  Offset? lastControl;
  var lastCommand = '';

  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);
  bool hasNumber() => i < tokens.length && !isCommand(tokens[i]);
  // Arc flags may be written without separators ("a2 2 0 011 1").
  bool flag() {
    final t = tokens[i];
    if (t.length > 1 && (t[0] == '0' || t[0] == '1')) {
      tokens[i] = t.substring(1);
      return t[0] == '1';
    }
    i++;
    return t == '1';
  }

  while (i < tokens.length) {
    if (isCommand(tokens[i])) {
      command = tokens[i++];
    } else if (command.isEmpty) {
      throw FormatException('Path must start with a command', data);
    }
    final relative = command == command.toLowerCase();
    Offset point(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);

    switch (command.toUpperCase()) {
      case 'M':
        current = point(next(), next());
        start = current;
        path.moveTo(current.dx, current.dy);
        // Further pairs are implicit line-tos.
        command = relative ? 'l' : 'L';
        lastControl = null;
      case 'L':
        current = point(next(), next());
        path.lineTo(current.dx, current.dy);
        lastControl = null;
      case 'H':
        final x = next();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
        lastControl = null;
      case 'V':
        final y = next();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
        lastControl = null;
      case 'C':
        final c1 = point(next(), next());
        final c2 = point(next(), next());
        final end = point(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastControl = c2;
        current = end;
      case 'S':
        final c1 =
            lastControl != null && 'CcSs'.contains(lastCommand)
                ? current * 2 - lastControl
                : current;
        final c2 = point(next(), next());
        final end = point(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastControl = c2;
        current = end;
      case 'Q':
        final c = point(next(), next());
        final end = point(next(), next());
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        lastControl = c;
        current = end;
      case 'T':
        final c =
            lastControl != null && 'QqTt'.contains(lastCommand)
                ? current * 2 - lastControl
                : current;
        final end = point(next(), next());
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        lastControl = c;
        current = end;
      case 'A':
        final rx = next();
        final ry = next();
        final rotation = next();
        final large = flag();
        final sweep = flag();
        final end = point(next(), next());
        path.arcToPoint(
          end,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
        current = end;
        lastControl = null;
      case 'Z':
        path.close();
        current = start;
        lastControl = null;
    }
    lastCommand = command;
    if (command.toUpperCase() == 'Z' && hasNumber()) {
      throw FormatException('Numbers after Z', data);
    }
  }
  return path;
}
