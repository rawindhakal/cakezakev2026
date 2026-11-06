import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/commons/models/country_settings_model.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/buyer_tax_fields.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Typed buyer tax details for ONE order — `buyer_tax_number` +
/// `buyer_business_name` on `POST customer/place_order`.
class BuyerTaxInput {
  const BuyerTaxInput({this.taxNumber = '', this.businessName = ''});

  /// Kept exactly as typed (trimmed) — the server uppercases it and strips
  /// spaces, and echoes the normalised value back on the order.
  final String taxNumber;
  final String businessName;

  bool get isEmpty => taxNumber.isEmpty && businessName.isEmpty;
}

/// "Business details" card on the order form, right beside the
/// order note — the number is typed per order like the note and is NEVER
/// saved to the address book (the same flat may order for a company one week
/// and for a person the next, so a number kept on the address would quietly
/// attach itself to both).
///
/// Built only when [field] is enabled for the billed party's country; a
/// consumer simply skips past it — sending nothing is a normal order.
class CheckoutBuyerTaxSection extends StatelessWidget {
  const CheckoutBuyerTaxSection({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final BuyerTaxField field;
  final BuyerTaxInput value;
  final ValueChanged<BuyerTaxInput> onChanged;

  Future<void> _openSheet(BuildContext context) async {
    final result = await showCheckoutBuyerTaxSheet(
      context,
      field: field,
      initial: value,
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final summary = [
      value.businessName,
      // Label from the billed party's country spec — never a hardcoded "GST".
      if (value.taxNumber.isNotEmpty) '${field.label}: ${value.taxNumber}',
    ].where((s) => s.isNotEmpty).join(' · ');
    return CheckoutCard(
      child: InkWell(
        borderRadius: AppRadius.r12,
        onTap: () => _openSheet(context),
        child: Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceS,
          children: [
            Expanded(
              child: CheckoutSectionHeader(
                icon: AssetsConstants.buildingIcon,
                title: context.translate(LanguageLabelKeys.businessDetails),
                subtitle: summary.isNotEmpty
                    ? summary
                    : context
                          .translate(LanguageLabelKeys.buyerTaxSubtitle)
                          .replaceAll('{label}', field.label),
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

/// Opens the business-details sheet; resolves with the entered values
/// (possibly both empty = cleared), or `null` when dismissed. Also used by
/// place-order to re-open the sheet when the typed number no longer passes
/// the (possibly changed) billed country's pattern.
Future<BuyerTaxInput?> showCheckoutBuyerTaxSheet(
  BuildContext context, {
  required BuyerTaxField field,
  required BuyerTaxInput initial,
}) {
  return showAppBottomSheet<BuyerTaxInput>(
    context,
    showDragHandle: false,
    padding: null,
    builder: (_) => _BuyerTaxSheet(field: field, initial: initial),
  );
}

class _BuyerTaxSheet extends StatefulWidget {
  const _BuyerTaxSheet({required this.field, required this.initial});

  final BuyerTaxField field;
  final BuyerTaxInput initial;

  @override
  State<_BuyerTaxSheet> createState() => _BuyerTaxSheetState();
}

class _BuyerTaxSheetState extends State<_BuyerTaxSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _taxNumberCtrl = TextEditingController(
    text: widget.initial.taxNumber,
  );
  late final TextEditingController _businessNameCtrl = TextEditingController(
    text: widget.initial.businessName,
  );

  @override
  void initState() {
    super.initState();
    // Re-opened from place-order with a number that fails the pattern —
    // show the error straight away instead of waiting for a submit tap.
    if (widget.initial.taxNumber.isNotEmpty &&
        !widget.field.isValid(widget.initial.taxNumber)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _formKey.currentState?.validate(),
      );
    }
  }

  @override
  void dispose() {
    _taxNumberCtrl.dispose();
    _businessNameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    // Local pre-check against `regex` only; empty always passes.
    if (!_formKey.currentState!.validate()) return;
    AppNavigator.pop(
      context,
      BuyerTaxInput(
        taxNumber: _taxNumberCtrl.text.trim(),
        businessName: _businessNameCtrl.text.trim(),
      ),
    );
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
      child: Form(
        key: _formKey,
        child: SlideAnimationList(
          crossAxisAlignment: .start,
          children: [
            Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXS,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.businessDetails),
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                AppText(
                  context
                      .translate(LanguageLabelKeys.buyerTaxSubtitle)
                      .replaceAll('{label}', widget.field.label),
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            AppSpacing.h12,
            BuyerTaxFields(
              field: widget.field,
              businessNameCtrl: _businessNameCtrl,
              taxNumberCtrl: _taxNumberCtrl,
            ),
            AppSpacing.h16,
            Row(
              spacing: ThemeConstants.spaceM,
              children: [
                Expanded(
                  child: AppButton(
                    label: context.translate(LanguageLabelKeys.clear),
                    variant: AppButtonVariant.outline,
                    onPressed: () {
                      _taxNumberCtrl.clear();
                      _businessNameCtrl.clear();
                    },
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: context.translate(LanguageLabelKeys.submit),
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
