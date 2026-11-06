import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';
import '../../utils/extensions/size_extensions.dart';
import '../../core/constants/navigation_service.dart';
import '../../utils/show_app_bottom_sheet.dart';
import '../animations/slide_animation.dart';
import '../../commons/widgets/app_text.dart';

/// Circular profile-photo picker with a camera badge — used on the sign-up
/// and edit-profile screens. Tap opens a camera/gallery bottom sheet.
class ProfileAvatarPicker extends StatelessWidget {
  final File? image;
  final String? imageUrl;
  final ValueChanged<File> onPicked;
  final double size;
  // Small variant (app bar): thinner ring, smaller icon and camera badge.
  final bool compact;

  const ProfileAvatarPicker({
    super.key,
    required this.onPicked,
    this.image,
    this.imageUrl,
    this.size = 100,
    this.compact = false,
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
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.translate(LanguageLabelKeys.cropPhoto),
          toolbarColor: context.cs.primary,
          toolbarWidgetColor: context.cs.onPrimary,
          activeControlsWidgetColor: context.cs.primary,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: context.translate(LanguageLabelKeys.cropPhoto),
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped != null) onPicked(File(cropped.path));
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = image != null;
    final hasNetworkImage = imageUrl != null && imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => _pick(context),
      child: Stack(
        clipBehavior: .none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: AppDecorations.circle(
              color: context.cs.primaryContainer,
              border: Border.all(
                color: context.cs.primary.withValues(alpha: 0.25),
                width: compact ? 1.5 : 3,
              ),
            ),
            child: ClipOval(
              child: hasLocalImage
                  ? Image.file(image!, fit: .cover)
                  : hasNetworkImage
                  ? AppNetworkImage(
                      url: imageUrl!,
                      placeholder: Center(
                        child: AppSvgIcon(
                          AssetsConstants.userIcon,
                          size: compact ? size * 0.5 : ThemeConstants.iconXL,
                          color: context.cs.primary,
                        ),
                      ),
                      errorWidget: Center(
                        child: AppSvgIcon(
                          AssetsConstants.userIcon,
                          size: compact ? size * 0.5 : ThemeConstants.iconXL,
                          color: context.cs.primary,
                        ),
                      ),
                    )
                  : Center(
                      child: AppSvgIcon(
                        AssetsConstants.userIcon,
                        size: compact ? size * 0.5 : ThemeConstants.iconXL,
                        color: context.cs.primary,
                      ),
                    ),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: compact ? size * 0.45 : context.screenWidth * 0.085,
              height: compact ? size * 0.45 : context.screenWidth * 0.085,
              decoration: AppDecorations.circle(
                color: context.cs.primary,
                border: Border.all(
                  color: context.cs.surface,
                  width: compact ? 1 : 2,
                ),
              ),
              padding: EdgeInsetsDirectional.all(compact ? 2 : 5.0),
              child: AppSvgIcon(
                AssetsConstants.cameraIcon,
                size: compact ? size * 0.3 : ThemeConstants.iconL,
                color: context.cs.onPrimary,
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
