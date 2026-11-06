import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';
import '../../utils/extensions/size_extensions.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import '../../commons/widgets/app_text.dart';

/// Tappable image upload box with a camera/gallery picker bottom sheet and error display.
class AppImageUploadField extends StatelessWidget {
  final String label;
  final File? image;
  final String? imageUrl;
  final ValueChanged<File> onPicked;
  final String? errorText;

  static final ImagePicker _picker = ImagePicker();

  const AppImageUploadField({
    super.key,
    required this.label,
    required this.onPicked,
    this.image,
    this.imageUrl,
    this.errorText,
  });

  Future<void> _pick(BuildContext context) async {
    final source = await showAppBottomSheet<ImageSource>(
      context,
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        ThemeConstants.paddingS,
        0,
        ThemeConstants.paddingS,
      ),
      builder: (ctx) => SlideAnimationList(
        children: [
          ListTile(
            leading: AppSvgIcon(
              AssetsConstants.cameraIcon,
              size: ThemeConstants.iconL,
              color: context.cs.onSurfaceVariant,
            ),
            title: AppText(ctx.translate(LanguageLabelKeys.takePhoto)),
            onTap: () => AppNavigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: AppSvgIcon(
              AssetsConstants.galleryIcon,
              size: ThemeConstants.iconL,
              color: context.cs.onSurfaceVariant,
            ),
            title: AppText(ctx.translate(LanguageLabelKeys.chooseFromGallery)),
            onTap: () => AppNavigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) onPicked(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final hasImage =
        image != null || (imageUrl != null && imageUrl!.isNotEmpty);

    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        height: context.screenHeight * 0.16,
        width: double.infinity,
        decoration: AppDecorations.card(
          color: context.cs.surface,
          borderRadius: AppRadius.r10,
          border: Border.all(
            color: hasError ? context.cs.error : context.cs.outline,
            width: hasError ? 1.5 : 1.0,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: AppRadius.r10,
                child: Stack(
                  fit: .expand,
                  children: [
                    // Image layer
                    if (image != null)
                      Image.file(image!, fit: .cover)
                    else
                      AppNetworkImage(
                        url: imageUrl!,
                        fit: .cover,
                        errorWidget: Column(
                          mainAxisAlignment: .center,
                          children: _buildUploadPlaceholder(context, hasError),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 6,
                        ),
                        color: context.cs.scrim.withValues(alpha: 0.5),
                        child: Row(
                          mainAxisAlignment: .center,
                          spacing: ThemeConstants.spaceS,
                          children: [
                            AppSvgIcon(
                              AssetsConstants.editIcon,
                              size: ThemeConstants.iconXS,
                              color: context.cs.onPrimary,
                            ),
                            AppText(
                              context.translate(LanguageLabelKeys.tapToChange),
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: .center,
                children: _buildUploadPlaceholder(context, hasError),
              ),
      ),
    );
  }

  List<Widget> _buildUploadPlaceholder(BuildContext context, bool hasError) {
    return [
      AppSvgIcon(
        AssetsConstants.uploadIcon,
        size: ThemeConstants.iconXL,
        color: hasError ? context.cs.error : context.cs.primary,
      ),
      AppSpacing.h8,
      AppText(
        '${context.translate(LanguageLabelKeys.tapToUpload)} $label',
        style: context.tt.headlineLarge?.copyWith(
          color: hasError ? context.cs.error : context.cs.onSurfaceVariant,
        ),
      ),
      AppSpacing.h4,
      AppText(
        context.translate(LanguageLabelKeys.jpgPngSupported),
        style: context.tt.labelSmall?.copyWith(
          color: context.cs.outlineVariant,
        ),
      ),
    ];
  }
}
