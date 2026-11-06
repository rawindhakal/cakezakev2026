import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/text_align_type.dart';
import 'package:customer/features/home/utils/home_redirect_handler.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class TextSection extends StatelessWidget {
  final Blocks block;
  const TextSection({super.key, required this.block});

  void _handleTap(BuildContext context) {
    handleHomeRedirectTap(
      context,
      redirectType: block.redirectType,
      redirectId: block.redirectId,
      redirectUrl: block.redirectUrl,
      redirectSlug: block.redirectSlug,
      redirectTitle: block.redirectTitle,
      redirectParams: block.redirectParams,
      hasChild: block.hasChild,
      skipUrlWhenTypeNone: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = block.config?.sectionTitle;
    final subtitle = block.config?.sectionSubtitle;
    if ((title == null || title.isEmpty) &&
        (subtitle == null || subtitle.isEmpty)) {
      return const SizedBox.shrink();
    }

    final bgColor = block.config?.backgroundColor.toColor();
    final textColor =
        block.config?.textColor.toColor() ??
        (context.isDark ? context.cs.onSurface : context.cs.onSurface);
    final align = _textAlign(block.config?.textAlign);

    Widget content = Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
      child: Column(
        crossAxisAlignment: _crossAxisAlign(align),
        spacing: ThemeConstants.spaceXS,
        children: [
          if (title?.isNotEmpty == true)
            AppText(
              title!,
              textAlign: align,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          if (subtitle?.isNotEmpty == true)
            AppText(
              subtitle!,
              textAlign: align,
              style: context.tt.bodySmall?.copyWith(
                fontSize: 13,
                color: textColor,
              ),
            ),
        ],
      ),
    );

    if (bgColor != null) {
      content = ColoredBox(color: bgColor, child: content);
    }

    return GestureDetector(onTap: () => _handleTap(context), child: content);
  }

  TextAlign _textAlign(String? value) {
    switch (TextAlignType.fromRaw(value)) {
      case TextAlignType.center:
        return TextAlign.center;
      case TextAlignType.right:
        return TextAlign.right;
      case TextAlignType.left:
        return TextAlign.left;
    }
  }

  CrossAxisAlignment _crossAxisAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return .center;
      case TextAlign.right:
        return .end;
      default:
        return .start;
    }
  }
}
