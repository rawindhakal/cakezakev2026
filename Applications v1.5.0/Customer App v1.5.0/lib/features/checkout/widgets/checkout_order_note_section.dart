import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CheckoutOrderNoteSection extends StatefulWidget {
  const CheckoutOrderNoteSection({
    super.key,
    required this.onNoteChanged,
    this.initialNote = '',
  });

  final ValueChanged<String> onNoteChanged;
  final String initialNote;

  @override
  State<CheckoutOrderNoteSection> createState() =>
      _CheckoutOrderNoteSectionState();
}

class _CheckoutOrderNoteSectionState extends State<CheckoutOrderNoteSection> {
  late String _note = widget.initialNote;

  Future<void> _openNoteSheet() async {
    final result = await showAppBottomSheet<String>(
      context,
      showDragHandle: false,
      padding: null,
      builder: (_) => _OrderNoteSheet(initialNote: _note),
    );
    if (result != null && mounted) {
      setState(() => _note = result);
      widget.onNoteChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNote = _note.isNotEmpty;
    return CheckoutCard(
      child: InkWell(
        borderRadius: AppRadius.r12,
        onTap: _openNoteSheet,
        child: Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceS,
          children: [
            Expanded(
              child: CheckoutSectionHeader(
                icon: AssetsConstants.noteIcon,
                title: context.translate(LanguageLabelKeys.deliveryInstruction),
                subtitle: hasNote
                    ? _note
                    : context.translate(
                        LanguageLabelKeys.deliveryInstructionSubtitle,
                      ),
              ),
            ),
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                color: context.cs.onSurfaceVariant,
                size: ThemeConstants.iconL,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderNoteSheet extends StatefulWidget {
  const _OrderNoteSheet({required this.initialNote});

  final String initialNote;

  @override
  State<_OrderNoteSheet> createState() => _OrderNoteSheetState();
}

class _OrderNoteSheetState extends State<_OrderNoteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXS,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.deliveryInstruction),
                style: context.tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText(
                context.translate(
                  LanguageLabelKeys.deliveryInstructionSubtitle,
                ),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          AppTextField(
            controller: _controller,
            hintText: context.translate(
              LanguageLabelKeys.enterDeliveryInstruction,
            ),
            maxLines: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
          ),
          AppSpacing.h16,
          Row(
            spacing: ThemeConstants.spaceM,
            children: [
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.clear),
                  variant: AppButtonVariant.outline,
                  onPressed: () => _controller.clear(),
                ),
              ),
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.submit),
                  onPressed: () =>
                      AppNavigator.pop(context, _controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
