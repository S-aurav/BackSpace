import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api/apis.dart';

/// A smart text widget that automatically detects URLs/links in plain text,
/// renders them with distinct clickable styling (like WhatsApp / iMessage),
/// and opens the link via [APIs.openUrl] upon tapping.
class LinkifyText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool isMe;
  final void Function(String url)? onOpenUrl;

  const LinkifyText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.isMe = false,
    this.onOpenUrl,
  });

  @override
  State<LinkifyText> createState() => _LinkifyTextState();
}

class _LinkifyTextState extends State<LinkifyText> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  // Regex matching http://, https://, www., or standard domain TLD links
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9][-a-zA-Z0-9]*\.(com|org|net|edu|gov|io|ai|dev|app|co|in|me|info|biz|tv|cc|to|tech|online|store|site|xyz|live|link|cloud|club|gg|ly|sh|so)\b([^\s]*))',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _buildSpans();
  }

  @override
  void didUpdateWidget(covariant LinkifyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.linkStyle != widget.linkStyle ||
        oldWidget.isMe != widget.isMe) {
      _disposeRecognizers();
      _buildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Separates trailing punctuation (like trailing dots, commas, exclamation marks)
  /// from the actual URL so that sentences like "Check https://flutter.dev!" don't
  /// break the link. Also handles balanced parentheses e.g. for Wikipedia links.
  (String, String) _splitUrlAndTrailing(String rawUrl) {
    int end = rawUrl.length;
    while (end > 0) {
      final char = rawUrl[end - 1];
      if (char == '.' ||
          char == ',' ||
          char == '!' ||
          char == '?' ||
          char == ':' ||
          char == ';' ||
          char == '"' ||
          char == '\'' ||
          char == '>') {
        end--;
      } else if (char == ')' || char == ']') {
        final openChar = char == ')' ? '(' : '[';
        final sub = rawUrl.substring(0, end);
        final openCount = openChar.allMatches(sub).length;
        final closeCount = char.allMatches(sub).length;
        if (closeCount > openCount) {
          end--;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    final cleanUrl = rawUrl.substring(0, end);
    final trailing = rawUrl.substring(end);
    return (cleanUrl, trailing);
  }

  void _buildSpans() {
    _spans = [];
    final text = widget.text;

    if (text.isEmpty) return;

    // Determine default link styling based on bubble color (isMe) or theme
    final defaultLinkColor = widget.isMe
        ? const Color(0xFFB3E5FC) // Ice cyan blue - high contrast on solid iOS blue bubble
        : const Color(0xFF007AFF); // Classic vibrant iOS blue

    final defaultLinkStyle = TextStyle(
      color: defaultLinkColor,
      decoration: TextDecoration.underline,
      decorationColor: defaultLinkColor,
      decorationThickness: 1.2,
    );

    final effectiveLinkStyle = (widget.style ?? const TextStyle())
        .merge(defaultLinkStyle)
        .merge(widget.linkStyle);

    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      _spans.add(TextSpan(text: text, style: widget.style));
      return;
    }

    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        _spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: widget.style,
        ));
      }

      final rawMatch = match.group(0)!;
      final (cleanUrl, trailing) = _splitUrlAndTrailing(rawMatch);

      if (cleanUrl.isNotEmpty) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (widget.onOpenUrl != null) {
              widget.onOpenUrl!(cleanUrl);
            } else {
              APIs.openUrl(cleanUrl);
            }
          };
        _recognizers.add(recognizer);

        _spans.add(
          TextSpan(
            text: cleanUrl,
            style: effectiveLinkStyle,
            recognizer: recognizer,
          ),
        );
      }

      if (trailing.isNotEmpty) {
        _spans.add(TextSpan(
          text: trailing,
          style: widget.style,
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      _spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: widget.style,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
