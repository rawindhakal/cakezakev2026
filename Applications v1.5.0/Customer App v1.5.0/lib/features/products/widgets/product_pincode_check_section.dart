import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/cubit/serviceability_cubit.dart';
import 'package:customer/features/products/models/serviceability_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Flipkart/Myntra-style "check delivery at pincode" card for the product
/// detail screen. API runs only on the Check button tap; a variant change
/// clears the previous result.
class ProductPincodeCheckSection extends StatefulWidget {
  final String variantId;

  const ProductPincodeCheckSection({super.key, required this.variantId});

  @override
  State<ProductPincodeCheckSection> createState() =>
      _ProductPincodeCheckSectionState();
}

class _ProductPincodeCheckSectionState
    extends State<ProductPincodeCheckSection> {
  final _controller = TextEditingController();
  String? _inputError;

  /// Last non-loading state; kept on screen while a re-check runs so the
  /// card height (and everything below it) doesn't jump.
  ServiceabilityState _settled = const ServiceabilityInitial();

  @override
  void initState() {
    super.initState();
    // Auto-fill + check with the user's saved pincode on open; the user can
    // edit it and tap Check to re-run.
    final saved = _savedPincode();
    if (saved.isNotEmpty) {
      _controller.text = saved;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit(silentInvalid: true);
      });
    }
  }

  /// Saved location pincode; falls back to the postal code inside the saved
  /// location address (locations saved before pincode was stored).
  String _savedPincode() {
    final box = SettingsHiveBox.instance;
    if (box.userPincode.isNotEmpty) return box.userPincode;
    final matches = RegExp(r'\b\d{5,6}\b').allMatches(box.locationAddress);
    return matches.isEmpty ? '' : matches.last.group(0)!;
  }

  @override
  void didUpdateWidget(covariant ProductPincodeCheckSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Result belongs to the old variant; re-check the new one with the
    // pincode already in the field, else clear it.
    if (oldWidget.variantId != widget.variantId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.text.trim().length >= 3) {
          _submit(silentInvalid: true);
        } else {
          context.read<ServiceabilityCubit>().reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({bool silentInvalid = false}) {
    final pin = _controller.text.trim();
    if (pin.length < 3 || widget.variantId.isEmpty) {
      if (silentInvalid) return;
      setState(
        () => _inputError = context.translate(
          LanguageLabelKeys.enterValidPincode,
        ),
      );
      return;
    }
    setState(() => _inputError = null);
    FocusScope.of(context).unfocus();
    context.read<ServiceabilityCubit>().check(
      pincode: pin,
      productVariantId: widget.variantId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingL,
        vertical: ThemeConstants.paddingS,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        decoration: AppDecorations.box(
          color: context.cs.surface,
          borderRadius: AppRadius.r12,
          boxShadow: [
            BoxShadow(
              color: context.cs.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: BlocBuilder<ServiceabilityCubit, ServiceabilityState>(
          builder: (context, state) {
            final loading = state is ServiceabilityLoading;
            if (!loading) _settled = state;
            final shown = _settled;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  context.translate(
                    LanguageLabelKeys.checkDeliveryAvailability,
                  ),
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.h8,
                AppTextField(
                  controller: _controller,
                  hintText: context.translate(LanguageLabelKeys.enterPincode),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.disabled,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  suffixIcon: loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: () => _submit(),
                          child: Text(
                            context.translate(LanguageLabelKeys.checkDelivery),
                          ),
                        ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: AlignmentDirectional.topStart,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: loading ? 0.4 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_inputError != null) ...[
                          AppSpacing.h6,
                          AppText(
                            _inputError!,
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.error,
                            ),
                          ),
                        ],
                        if (shown is ServiceabilityLoaded) ...[
                          AppSpacing.h8,
                          _ResultView(result: shown.result),
                        ],
                        if (shown is ServiceabilityError) ...[
                          AppSpacing.h8,
                          AppText(
                            context.translate(
                              LanguageLabelKeys.pincodeNotServiceable,
                            ),
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ServiceabilityModel result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final pin = result.pincode ?? '';

    // Only courier_serviceable decides the result; the API message is not
    // shown.
    if (result.courierServiceable == false) {
      return _line(
        context,
        icon: Icons.cancel,
        color: cs.error,
        title: context.translate(LanguageLabelKeys.pincodeNotServiceable),
      );
    }

    if (result.courierServiceable != true) return const SizedBox.shrink();

    return _line(
      context,
      icon: Icons.check_circle,
      color: cs.onSecondaryContainer,
      title: '${context.translate(LanguageLabelKeys.deliveryAvailableAt)} $pin',
    );
  }

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeConstants.spaceXS,
      children: [
        Icon(icon, size: ThemeConstants.iconS, color: color),
        Expanded(
          child: AppText(
            title,
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
