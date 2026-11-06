import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/products/cubit/notify_me_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Common "Notify me" button shown in place of the add-to-cart control
/// wherever a product/variant is sold out — product card, product list
/// item, and the product detail bottom bar. Tapping calls the notify_me
/// API; tapping again while already notified removes the subscription.
class NotifyMeButton extends StatefulWidget {
  final String productVariantId;
  final double width;
  final double height;
  final double fontSize;

  /// From the variant's `is_notify_requested` (0/1) — whether this viewer
  /// already has a pending notify-me request for this variant.
  final bool initiallyNotified;

  const NotifyMeButton({
    super.key,
    required this.productVariantId,
    required this.width,
    required this.height,
    this.fontSize = 10,
    this.initiallyNotified = false,
  });

  @override
  State<NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends State<NotifyMeButton> {
  late final NotifyMeCubit _cubit;
  late bool _notified;

  @override
  void initState() {
    super.initState();
    _cubit = NotifyMeCubit();
    _notified = widget.initiallyNotified;
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (widget.productVariantId.isEmpty) return;
    if (_notified) {
      await _cubit.removeNotifyMe(productVariantId: widget.productVariantId);
    } else {
      await _cubit.notifyMe(productVariantId: widget.productVariantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotifyMeCubit>.value(
      value: _cubit,
      child: BlocConsumer<NotifyMeCubit, NotifyMeState>(
        listener: (ctx, state) {
          if (state is NotifyMeSuccess) {
            setState(() => _notified = !_notified);
            if (state.message.isNotEmpty) {
              AppSnackBar.show(
                context: ctx,
                message: state.message,
                type: SnackBarType.success,
              );
            }
          } else if (state is NotifyMeError) {
            AppSnackBar.show(
              context: ctx,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (ctx, state) {
          final isLoading = state is NotifyMeInProgress;
          // Mirrors CartButton exactly: unfilled (surface bg, primary
          // border/text) for "Notify", filled (primary bg, onPrimary text)
          // once notified — same visual language as the add/stepper states.
          final fg = _notified ? ctx.cs.onPrimary : ctx.cs.primary;
          final label = _notified
              ? ctx.translate(LanguageLabelKeys.notified)
              : ctx.translate(LanguageLabelKeys.notifyMe);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            width: widget.width,
            height: widget.height,
            decoration: AppDecorations.cartControl(
              cs: ctx.cs,
              filled: _notified,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.r10,
              child: GestureDetector(
                onTap: isLoading ? null : _onTap,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: widget.fontSize + 2,
                          height: widget.fontSize + 2,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      : AppText(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: ctx.tt.headlineMedium?.copyWith(
                            color: fg,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
