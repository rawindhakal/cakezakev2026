import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/models/order_addon_model.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';

/// Add-on module: the chosen options under an order item as one
/// comma-separated run instead of a line per option. Free options show just
/// their name; only a positive `line_price` gets a "+price" suffix. Runs
/// longer than one line fold behind an inline "Read more" / "Read less".
/// [addonTotal] is display only: it is already inside the item's price, so
/// it's never added to any total.
class OrderAddonList extends StatefulWidget {
  const OrderAddonList({
    super.key,
    required this.addons,
    required this.currency,
    this.addonTotal = 0,
  });

  final List<OrderAddon> addons;
  final double addonTotal;
  final String currency;

  @override
  State<OrderAddonList> createState() => _OrderAddonListState();
}

class _OrderAddonListState extends State<OrderAddonList> {
  static const _collapsedLines = 1;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = context.tt.bodySmall?.copyWith(
      color: context.cs.onSurfaceVariant,
    );
    final toggleStyle = style?.copyWith(fontWeight: FontWeight.w700);
    final text = formatOrderAddons(widget.addons, currency: widget.currency);

    String prefix(int limit) {
      if (limit >= text.length) return text;
      // Never end a folded run on a dangling ", " or space.
      return text.substring(0, limit).replaceFirst(RegExp(r'[,\s]+$'), '');
    }

    void toggle() => setState(() => _expanded = !_expanded);

    return Column(
      crossAxisAlignment: .start,
      spacing: 2,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final direction = Directionality.of(context);
            final scaler = MediaQuery.textScalerOf(context);
            bool fits(List<InlineSpan> spans) {
              final painter = TextPainter(
                text: TextSpan(style: style, children: spans),
                maxLines: _collapsedLines,
                textDirection: direction,
                textScaler: scaler,
              )..layout(maxWidth: constraints.maxWidth);
              final ok = !painter.didExceedMaxLines;
              painter.dispose();
              return ok;
            }

            if (fits([TextSpan(text: text)])) {
              return Text(text, style: style);
            }

            if (_expanded) {
              return GestureDetector(
                onTap: toggle,
                behavior: HitTestBehavior.opaque,
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      TextSpan(text: text),
                      TextSpan(
                        text:
                            '  ${context.translate(LanguageLabelKeys.readLess)}',
                        style: toggleStyle,
                      ),
                    ],
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
            var hi = text.length;
            while (lo < hi) {
              final mid = (lo + hi + 1) ~/ 2;
              if (fits([TextSpan(text: prefix(mid)), more])) {
                lo = mid;
              } else {
                hi = mid - 1;
              }
            }
            return GestureDetector(
              onTap: toggle,
              behavior: HitTestBehavior.opaque,
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: [TextSpan(text: prefix(lo)), more],
                ),
                maxLines: _collapsedLines,
              ),
            );
          },
        ),
        if (widget.addonTotal > 0)
          AppText(
            context
                .translate(LanguageLabelKeys.addonTotalInfo)
                .replaceAll(
                  '{amount}',
                  '${widget.currency}${widget.addonTotal.trimmedFixed()}',
                ),
            style: context.tt.labelSmall?.copyWith(
              color: context.cs.onSurfaceVariant.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
