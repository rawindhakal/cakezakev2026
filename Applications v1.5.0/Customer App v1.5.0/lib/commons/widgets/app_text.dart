import 'package:flutter/material.dart';
import '../../utils/extensions/localization_extensions.dart';

/// Common text widget.
///
/// Wraps [Text] with all commonly needed parameters. Always use this
/// instead of raw [Text] to keep styling consistent and refactorable.
///
/// Style comes from `context.tt.<slot>` (or via `.copyWith(...)`).
/// [text] is run through [context.translate] automatically — pass a
/// LanguageLabelKeys key for localized copy, or a dynamic runtime value
/// (order id, amount, date) which passes through unchanged since it won't
/// match any translation key.
class AppText extends StatelessWidget {
  /// The display string or translation key.
  final String text;

  /// Text style — use `context.tt.bodyMedium?.copyWith(...)` etc.
  final TextStyle? style;

  final TextAlign? textAlign;

  /// Caps the number of visible lines. Pairs with [overflow].
  final int? maxLines;

  /// What to do when text overflows. Defaults to clip.
  final TextOverflow? overflow;

  final bool softWrap;

  /// Appends a red " *" after the text — use on field labels to mark
  /// mandatory inputs.
  final bool isRequired;

  const AppText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRequired) {
      return Text(
        context.translate(text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap,
      text: TextSpan(
        text: context.translate(text),
        style: style,
        children: [
          TextSpan(
            text: ' *',
            style: style?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }
}
