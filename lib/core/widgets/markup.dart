import 'package:flutter/widgets.dart';

/// Splits [text] on `**bold**` markers and returns spans: the segments between
/// the markers get [bold], everything else gets [base]. Mirrors v5's inline
/// `<b>` emphasis inside signal/learn copy without coupling to any engine.
List<TextSpan> parseBold(
  String text, {
  required TextStyle base,
  required TextStyle bold,
}) {
  final out = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    out.add(TextSpan(text: parts[i], style: i.isOdd ? bold : base));
  }
  return out;
}
