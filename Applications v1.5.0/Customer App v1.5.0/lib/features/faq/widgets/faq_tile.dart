import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/faq/models/faq_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class FaqTile extends StatefulWidget {
  final FaqData faq;
  const FaqTile({super.key, required this.faq});

  @override
  State<FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingS),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r8,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: AppRadius.r8,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceM,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      widget.faq.question,
                      style: context.tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                  AppSvgIcon(
                    _expanded
                        ? AssetsConstants.arrowUpIcon
                        : AssetsConstants.arrowDownIcon,
                    color: context.cs.onSurfaceVariant,
                    size: ThemeConstants.iconL,
                  ),
                ],
              ),
              if (_expanded) ...[
                Divider(height: 1, color: context.cs.outlineVariant),
                AppText(
                  widget.faq.answer,
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
                    color: context.cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
