import 'dart:io';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/assets_constants.dart';

import '../../../commons/widgets/app_text.dart';

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_success_dialog.dart';
import 'package:customer/commons/widgets/star_rating_row.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/cubit/rating_add_update_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ExistingRatingImage {
  final String id;
  final String url;
  const ExistingRatingImage({required this.id, required this.url});
}

/// Returns the `data` object from the add/update-rating API response (the
/// updated rating), or null if the sheet was dismissed without submitting.
Future<Map<String, dynamic>?> showRateProductSheet(
  BuildContext context, {
  required String productId,
  required String productName,
  String? ratingId,
  int initialRate = 0,
  String initialReview = '',
  List<ExistingRatingImage> initialImages = const [],
}) {
  return showAppBottomSheet<Map<String, dynamic>?>(
    context,
    showDragHandle: false,
    padding: null,
    builder: (_) => BlocProvider(
      create: (_) => RatingAddUpdateCubit(),
      child: RateProductSheet(
        productId: productId,
        productName: productName,
        ratingId: ratingId,
        initialRate: initialRate,
        initialReview: initialReview,
        initialImages: initialImages,
      ),
    ),
  );
}

class RateProductSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final String? ratingId;
  final int initialRate;
  final String initialReview;
  final List<ExistingRatingImage> initialImages;

  const RateProductSheet({
    super.key,
    required this.productId,
    required this.productName,
    this.ratingId,
    this.initialRate = 0,
    this.initialReview = '',
    this.initialImages = const [],
  });

  @override
  State<RateProductSheet> createState() => _RateProductSheetState();
}

class _RateProductSheetState extends State<RateProductSheet> {
  late final _reviewController = TextEditingController(
    text: widget.initialReview,
  );
  final _picker = ImagePicker();
  late int _rate = widget.initialRate;
  final List<String> _imagePaths = [];
  late final List<ExistingRatingImage> _existingImages = [
    ...widget.initialImages,
  ];
  final List<String> _deleteImageIds = [];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _imagePaths.addAll(picked.map((f) => f.path)));
  }

  void _submit() {
    if (_rate == 0) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.selectRatingError),
        type: SnackBarType.error,
      );
      return;
    }
    context.read<RatingAddUpdateCubit>().submit(
      productId: widget.productId,
      ratingId: widget.ratingId,
      rate: _rate.toString(),
      review: _reviewController.text.trim(),
      imagePaths: _imagePaths.isEmpty ? null : _imagePaths,
      deleteImageIds: _deleteImageIds.isEmpty ? null : _deleteImageIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RatingAddUpdateCubit, RatingAddUpdateState>(
      listener: (context, state) {
        if (state is RatingAddUpdateSuccess) {
          final rootContext = AppNavigator.of(context).context;
          AppNavigator.pop(context, state.data);
          showAppSuccessDialog(
            rootContext,
            message: rootContext.translate(LanguageLabelKeys.ratingSubmitted),
          );
        } else if (state is RatingAddUpdateError) {
          final rootContext = AppNavigator.of(context).context;
          AppNavigator.pop(context);
          AppSnackBar.show(
            context: rootContext,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is RatingAddUpdateLoading;
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL +
                context.keyboardInset +
                context.bottomSafePadding,
          ),
          child: SlideAnimationList(
            crossAxisAlignment: .start,
            children: [
              AppText(
                context.translate(
                  widget.ratingId != null
                      ? LanguageLabelKeys.rateProduct
                      : LanguageLabelKeys.writeAReview,
                ),
                style: context.tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppSpacing.h4,
              AppText(
                widget.productName,
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: .ellipsis,
              ),
              AppSpacing.h16,
              Center(
                child: StarRatingRow(
                  rating: _rate.toDouble(),
                  size: ThemeConstants.iconXL,
                  outlineColor: context.cs.outlineVariant,
                  enabled: !isSubmitting,
                  onStarTap: (rate) => setState(() => _rate = rate),
                ),
              ),
              AppSpacing.h12,
              AppTextField(
                controller: _reviewController,
                maxLines: 3,
                enabled: !isSubmitting,
                hintText: context.translate(
                  LanguageLabelKeys.reviewOptionalHint,
                ),
              ),
              AppSpacing.h12,
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingImages.map(
                      (img) => Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: ThemeConstants.paddingS,
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.r8,
                              child: AppNetworkImage(
                                url: img.url,
                                width: context.screenWidth * 0.17,
                                height: context.screenWidth * 0.17,
                                fit: BoxFit.cover,
                              ),
                            ),
                            PositionedDirectional(
                              top: -8,
                              end: -8,
                              child: IconButton(
                                icon: const AppSvgIcon(
                                  AssetsConstants.closeCircleIcon,
                                  size: ThemeConstants.iconS,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () => setState(() {
                                        _existingImages.remove(img);
                                        _deleteImageIds.add(img.id);
                                      }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ..._imagePaths.map(
                      (path) => Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: ThemeConstants.paddingS,
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.r8,
                              child: Image.file(
                                File(path),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            PositionedDirectional(
                              top: -8,
                              end: -8,
                              child: IconButton(
                                icon: const AppSvgIcon(
                                  AssetsConstants.closeCircleIcon,
                                  size: ThemeConstants.iconS,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () => setState(
                                        () => _imagePaths.remove(path),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: isSubmitting ? null : _pickImages,
                      borderRadius: AppRadius.r8,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: AppDecorations.box(
                          border: Border.all(color: context.cs.outlineVariant),
                          borderRadius: AppRadius.r8,
                        ),
                        child: AppSvgIcon(
                          AssetsConstants.phoneUploadIcon,
                          color: context.cs.onSurfaceVariant,
                          fit: BoxFit.scaleDown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              AppButton(
                label: context.translate(LanguageLabelKeys.submit),
                onPressed: isSubmitting ? null : _submit,
                isLoading: isSubmitting,
              ),
            ],
          ),
        );
      },
    );
  }
}
