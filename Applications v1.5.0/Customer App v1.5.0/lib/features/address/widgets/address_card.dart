import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/address/widgets/address_actions.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Shared saved-address card. Used by the address list screen (static) and
/// the address picker sheet (selectable) so both stay visually identical.
///
/// Pass [onTap] to make the card selectable; omit it for the plain
/// list-screen look.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.isSelected = false,
  });

  final AddressData address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool isSelected;

  String get _typeIcon => switch (address.type ?? '') {
    'home' => AssetsConstants.homeIcon,
    'work' => AssetsConstants.officeIcon,
    _ => AssetsConstants.addressIcon,
  };

  String _typeLabel(BuildContext context) => switch (address.type ?? '') {
    'home' => context.translate(LanguageLabelKeys.home),
    'work' => context.translate(LanguageLabelKeys.work),
    _ =>
      (address.type ?? '').isNotEmpty
          ? address.type!
          : context.translate(LanguageLabelKeys.other),
  };

  String _formatAddress() {
    final a = address;
    final parts = [
      if ((a.address ?? '').isNotEmpty) a.address,
      if ((a.landmark ?? '').isNotEmpty) a.landmark,
      if ((a.area ?? '').isNotEmpty) a.area,
      if ((a.city ?? '').isNotEmpty) a.city,
      if ((a.state ?? '').isNotEmpty) a.state,
      if ((a.pincode ?? '').isNotEmpty) a.pincode,
      if ((a.country ?? '').isNotEmpty) a.country,
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = address.isDefault == '1';

    return Container(
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.r16,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  ThemeConstants.paddingM,
                ),
                child: Row(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceM,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: AppDecorations.primaryIconBox(
                        color: context.cs.primary.withValues(alpha: 0.1),
                        borderRadius: 8,
                      ),
                      child: AppSvgIcon(
                        _typeIcon,
                        size: ThemeConstants.iconM,
                        color: context.cs.primary,
                        fit: BoxFit.scaleDown,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: ThemeConstants.spaceXS,
                        children: [
                          Row(
                            spacing: ThemeConstants.spaceS,
                            children: [
                              AppText(
                                _typeLabel(context),
                                style: context.tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.cs.onSurface,
                                ),
                              ),
                              if (isDefault)
                                _Badge(
                                  label: context.translate(
                                    LanguageLabelKeys.defaultLabel,
                                  ),
                                  color: context.cs.tertiary,
                                ),
                            ],
                          ),
                          AppText(
                            _formatAddress(),
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                            maxLines: 3,
                          ),
                          if ((address.mobile ?? '').isNotEmpty &&
                              address.mobile != 'null')
                            Text.rich(
                              TextSpan(
                                style: context.tt.bodySmall?.copyWith(
                                  color: context.cs.onSurfaceVariant,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${context.translate(LanguageLabelKeys.phoneNumber)}: ',
                                  ),
                                  TextSpan(
                                    text: address.mobile,
                                    style: context.tt.bodySmall?.copyWith(
                                      color: context.cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: ThemeConstants.paddingXS,
              end: ThemeConstants.paddingXS,
            ),
            child: InkWell(
              onTap: () => showAddressOptionsSheet(
                context,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
              borderRadius: AppRadius.r20,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  ThemeConstants.paddingXS,
                ),
                child: AppSvgIcon(
                  AssetsConstants.menuIcon,
                  size: ThemeConstants.iconM,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingS,
        vertical: ThemeConstants.paddingXS,
      ),
      decoration: AppDecorations.box(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.r20,
      ),
      child: AppText(
        label,
        style: context.tt.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
