import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';

/// Add-on module: the chosen options under a dish — on checkout lines
/// and order items alike — as one comma-separated run instead of a line per
/// option. Free options show just their name; only a positive `line_price`
/// gets a "+price" suffix. Runs longer than [collapsedLines] fold behind an inline
/// "Read more" / "Read less". [addonTotal] is display only: it is already
/// inside the line's price, so it's never added to any total.
class CartAddonList extends StatefulWidget {
  const CartAddonList({
    super.key,
    required this.addons,
    required this.currency,
    required this.decimalPoint,
    this.addonTotal = 0,
    this.collapsedLines = 1,
  });

  final List<CartAddon> addons;
  final double addonTotal;
  final String currency;
  final int decimalPoint;

  /// Lines shown before the run folds behind "Read more".
  final int collapsedLines;

  @override
  State<CartAddonList> createState() => _CartAddonListState();
}

class _CartAddonListState extends State<CartAddonList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = context.tt.bodySmall?.copyWith(
      color: context.cs.onSurfaceVariant,
    );
    final unavailableStyle = style?.copyWith(
      color: context.cs.error,
      decoration: TextDecoration.lineThrough,
    );
    final toggleStyle = style?.copyWith(fontWeight: FontWeight.w700);
    final unavailableLabel = context.translate(
      LanguageLabelKeys.addonUnavailable,
    );

    // Plain chunks (option text and ", " separators) so the collapsed run
    // can be cut at any character while keeping each option's style.
    final chunks = <(String, TextStyle?)>[];
    for (final (i, a) in widget.addons.indexed) {
      if (i > 0) chunks.add((', ', null));
      chunks.add((
        [
          formatCartAddon(
            a,
            currency: widget.currency,
            decimalPoint: widget.decimalPoint,
          ),
          if (a.isUnavailable) '($unavailableLabel)',
        ].join(' '),
        a.isUnavailable ? unavailableStyle : null,
      ));
    }
    final totalLength = chunks.fold<int>(0, (n, c) => n + c.$1.length);

    List<InlineSpan> spansUpTo(int limit) {
      final spans = <InlineSpan>[];
      var left = limit;
      for (final (text, chunkStyle) in chunks) {
        if (left <= 0) break;
        final cut = text.length <= left ? text : text.substring(0, left);
        left -= cut.length;
        spans.add(TextSpan(text: cut, style: chunkStyle));
      }
      // Never end a folded run on a dangling ", " or space.
      while (spans.isNotEmpty && limit < totalLength) {
        final last = spans.removeLast() as TextSpan;
        final trimmed = last.text!.replaceFirst(RegExp(r'[,\s]+$'), '');
        if (trimmed.isNotEmpty) {
          spans.add(TextSpan(text: trimmed, style: last.style));
          break;
        }
      }
      return spans;
    }

    void toggle() => setState(() => _expanded = !_expanded);

    final totalNote = widget.addonTotal > 0
        ? AppText(
            context
                .translate(LanguageLabelKeys.addonTotalInfo)
                .replaceAll(
                  '{amount}',
                  '${widget.currency}${widget.addonTotal.formatPrice(widget.decimalPoint)}',
                ),
            style: context.tt.labelSmall?.copyWith(
              color: context.cs.onSurfaceVariant.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          )
        : null;

    Widget withTotal(Widget run) {
      if (totalNote == null) return run;
      return Column(
        crossAxisAlignment: .start,
        spacing: 2,
        children: [run, totalNote],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        bool fits(List<InlineSpan> spans) {
          final painter = TextPainter(
            text: TextSpan(style: style, children: spans),
            maxLines: widget.collapsedLines,
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          final ok = !painter.didExceedMaxLines;
          painter.dispose();
          return ok;
        }

        final full = spansUpTo(totalLength);
        if (fits(full)) {
          return withTotal(Text.rich(TextSpan(style: style, children: full)));
        }

        if (_expanded) {
          return GestureDetector(
            onTap: toggle,
            behavior: HitTestBehavior.opaque,
            child: withTotal(
              Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    ...full,
                    TextSpan(
                      text:
                          '  ${context.translate(LanguageLabelKeys.readLess)}',
                      style: toggleStyle,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final more = TextSpan(
          text: '… ${context.translate(LanguageLabelKeys.readMore)}',
          style: toggleStyle,
        );
        // Longest prefix that still leaves room for "… more".
        var lo = 0;
        var hi = totalLength;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          if (fits([...spansUpTo(mid), more])) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        return withTotal(
          GestureDetector(
            onTap: toggle,
            behavior: HitTestBehavior.opaque,
            child: Text.rich(
              TextSpan(style: style, children: [...spansUpTo(lo), more]),
              maxLines: widget.collapsedLines,
            ),
          ),
        );
      },
    );
  }
}
