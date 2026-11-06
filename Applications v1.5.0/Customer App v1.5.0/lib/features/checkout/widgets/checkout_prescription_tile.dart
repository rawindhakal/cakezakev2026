import 'dart:io';

import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Per-product prescription uploader shown only for medical products
/// (product_type == 5). A [ProductDataModel.requiresPrescription] item marks
/// the upload mandatory; otherwise it's optional. Accepts a single image
/// (jpg/png) or a PDF, keyed by the product's variant id at place-order time.
class CheckoutPrescriptionTile extends StatelessWidget {
  const CheckoutPrescriptionTile({
    super.key,
    required this.item,
    required this.file,
    required this.onPicked,
    required this.onRemove,
  });

  final ProductDataModel item;
  final File? file;
  final ValueChanged<File> onPicked;
  final VoidCallback onRemove;

  static final ImagePicker _picker = ImagePicker();

  // Keep uploads reasonable for a checkout attachment.
  static const int _maxBytes = 10 * 1024 * 1024;

  bool _isWithinSizeLimit(BuildContext context, String path) {
    if (File(path).lengthSync() <= _maxBytes) return true;
    AppSnackBar.show(
      context: context,
      message: context.translate(LanguageLabelKeys.fileTooLarge),
      type: SnackBarType.warning,
    );
    return false;
  }

  Future<void> _pick(BuildContext context) async {
    final tooltipKey = GlobalKey<TooltipState>();
    final source = await showAppBottomSheet<_PrescriptionSource>(
      context,
      builder: (ctx) => SlideAnimationList(
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisSize: .min,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.uploadPrescription),
                style: ctx.tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ctx.cs.onSurface,
                ),
              ),
              AppSpacing.w6,
              GestureDetector(
                onTap: () => tooltipKey.currentState?.ensureTooltipVisible(),
                child: Tooltip(
                  key: tooltipKey,
                  message: context.translate(
                    LanguageLabelKeys.imageOrPdfSupported,
                  ),
                  triggerMode: TooltipTriggerMode.manual,
                  child: AppSvgIcon(
                    AssetsConstants.infoCircleIcon,
                    size: ThemeConstants.iconXS,
                    color: ctx.cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppSvgIcon(
              AssetsConstants.cameraIcon,
              color: ctx.cs.primary,
            ),
            title: AppText(context.translate(LanguageLabelKeys.takePhoto)),
            onTap: () => AppNavigator.pop(context, _PrescriptionSource.camera),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppSvgIcon(
              AssetsConstants.galleryIcon,
              color: ctx.cs.primary,
            ),
            title: AppText(
              context.translate(LanguageLabelKeys.chooseFromGallery),
            ),
            onTap: () => AppNavigator.pop(context, _PrescriptionSource.gallery),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppSvgIcon(
              AssetsConstants.fileIcon,
              color: ctx.cs.primary,
            ),
            title: AppText(context.translate(LanguageLabelKeys.choosePdf)),
            onTap: () => AppNavigator.pop(context, _PrescriptionSource.pdf),
          ),
        ],
      ),
    );

    if (source == null || !context.mounted) return;

    String? path;
    if (source == _PrescriptionSource.pdf) {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      path = result?.path;
    } else {
      final picked = await _picker.pickImage(
        source: source == _PrescriptionSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
      );
      path = picked?.path;
    }

    if (path == null || !context.mounted) return;
    if (!_isWithinSizeLimit(context, path)) return;
    onPicked(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final isPdf =
        file != null && p.extension(file!.path).toLowerCase() == '.pdf';
    final isRequired = item.requiresPrescription;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 0),
      child: file == null
          ? _buildEmpty(context, isRequired)
          : _buildPicked(context, isPdf),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isRequired) {
    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: () => _pick(context),
      child: Row(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceXS,
        children: [
          AppSvgIcon(
            AssetsConstants.uploadIcon,
            size: ThemeConstants.iconXS,
            color: context.cs.onSurfaceVariant,
          ),
          Flexible(
            child: AppText(
              context.translate(LanguageLabelKeys.uploadPrescription),
              style: context.tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
              maxLines: 1,
              overflow: .ellipsis,
              isRequired: isRequired,
            ),
          ),
          AppSvgIcon(
            AssetsConstants.arrowRightIcon,
            size: ThemeConstants.iconXS,
            color: context.cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildPicked(BuildContext context, bool isPdf) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              borderRadius: AppRadius.r8,
              onTap: () => _pick(context),
              child: ClipRRect(
                borderRadius: AppRadius.r8,
                child: isPdf
                    ? Container(
                        width: 40,
                        height: 40,
                        color: context.cs.error.withValues(alpha: 0.1),
                        child: AppSvgIcon(
                          AssetsConstants.fileIcon,
                          size: ThemeConstants.iconM,
                          color: context.cs.error,
                        ),
                      )
                    : Image.file(
                        file!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            PositionedDirectional(
              top: -5,
              end: -5,
              child: InkWell(
                borderRadius: AppRadius.r10,
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.cs.shadow.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: AppSvgIcon(
                    AssetsConstants.closeIcon,
                    size: 12,
                    color: context.cs.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        AppSpacing.w10,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.prescription),
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              AppText(
                p.basename(file!.path),
                style: context.tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
        AppSpacing.w8,
        GestureDetector(
          onTap: () => _pick(context),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingXS,
              vertical: ThemeConstants.paddingXS,
            ),
            child: AppText(
              context.translate(LanguageLabelKeys.change),
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _PrescriptionSource { camera, gallery, pdf }
