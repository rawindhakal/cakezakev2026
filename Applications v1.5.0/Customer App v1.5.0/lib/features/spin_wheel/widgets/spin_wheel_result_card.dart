import 'dart:async';

import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/features/spin_wheel/models/spin_wheel_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "You won" card shown over the spin dialog once the wheel has landed on a
/// prize. Purple two-layer card (same palette as the wheel's board), the won
/// segment's icon on top, the API's own message / label, a coupon
/// ticket with copy for promo-code wins, and a hex "Spin Again" button.
class SpinWheelResultCard extends StatefulWidget {
  final SpinResultData result;

  /// `icon_url` of the segment the wheel landed on, shown as the card's hero
  /// image.
  final String? prizeIconUrl;

  /// True while the user still has spins today. Decides the button: "Spin
  /// Again" while true, "Shop Now" once the quota is used up.
  final bool canSpinAgain;

  /// "Spin Again" tapped: the caller closes the card and starts another spin.
  final VoidCallback onSpinAgain;

  /// Floating close (X) button: dismisses the card and nothing else.
  final VoidCallback onClose;

  /// "Shop Now" tapped (no spins left): the caller closes the dialog and
  /// takes the user to the Home tab.
  final VoidCallback onShopNow;

  /// Logical size of the hero icon. The dialog precaches the won segment's
  /// icon at this size while the wheel is landing.
  static const double heroIconSize = 104.0;

  const SpinWheelResultCard({
    super.key,
    required this.result,
    this.prizeIconUrl,
    required this.canSpinAgain,
    required this.onSpinAgain,
    required this.onShopNow,
    required this.onClose,
  });

  @override
  State<SpinWheelResultCard> createState() => _SpinWheelResultCardState();
}

class _SpinWheelResultCardState extends State<SpinWheelResultCard> {
  static Color get _rim => SpinWheelPurple.shade(0.292, 1.6);
  static Color get _bodyTop => SpinWheelPurple.shade(0.110, 1.3);
  static Color get _bodyBottom => SpinWheelPurple.shade(-0.082, 0.95);
  static Color get _insetTop => SpinWheelPurple.shade(0.016, 1.03);
  static Color get _insetBottom => SpinWheelPurple.shade(-0.194);
  static const _gold = AppColors.spinWheelTitleBottomFillEnd;

  // Fixed size so the card and its floating buttons line up the same way on
  // every device instead of shifting with screen width.
  static const _cardWidth = 320.0;

  // Room above the card for the close button, which floats over its top
  // corner.
  static const _closeButtonSpace = 18.0;

  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final code = result.promoCode?.promoCode ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: ((t - 0.85) / 0.15).clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
      child: SizedBox(
        width: _cardWidth,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Room under the card for the button that overhangs its edge, and
            // above it for the close button that floats over its top corner.
            Padding(
              padding: const EdgeInsets.only(
                top: _closeButtonSpace,
                bottom: 26,
              ),
              child: _card(context, code),
            ),
            // Centred exactly on the card's top-right corner point, so half
            // the button floats free and half overlaps the card.
            PositionedDirectional(
              top: _closeButtonSpace - 8,
              end: -2,
              child: _CloseButton(onTap: widget.onClose),
            ),
            Positioned(
              bottom: 0,
              child: _HexButton(
                label: widget.canSpinAgain
                    ? context.translate(LanguageLabelKeys.spinResultSpinAgain)
                    : context.translate(LanguageLabelKeys.spinResultShopNow),
                showIcon: widget.canSpinAgain,
                onTap: widget.canSpinAgain
                    ? widget.onSpinAgain
                    : widget.onShopNow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String code) {
    final result = widget.result;
    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _rim.withValues(alpha: 0.9), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bodyTop, _bodyBottom],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.spinWheelTitleShadow,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_insetTop, _insetBottom],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hero(),
            const SizedBox(height: 6),
            if (!result.isNoLuck)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _line(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AppText(
                      context.translate(LanguageLabelKeys.spinResultYouWon),
                      style: context.tt.labelLarge?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  _line(),
                ],
              ),
            const SizedBox(height: 8),
            AppText(
              result.isNoLuck
                  ? context.translate(LanguageLabelKeys.betterLuckNextTime)
                  : context.translate(
                      LanguageLabelKeys.spinResultCongratulations,
                    ),
              textAlign: TextAlign.center,
              style: context.tt.headlineMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (result.message.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText(
                result.message,
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
            if (code.isNotEmpty) ...[
              const SizedBox(height: 16),
              _couponTicket(context, code),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line() => Container(
    width: 26,
    height: 1.5,
    color: AppColors.white.withValues(alpha: 0.35),
  );

  // The won segment's own icon (from the API) among a few gold stars. Falls
  // back to a plain gift icon when the URL is empty or fails to load. While
  // loading it shows a soft gold glow + small spinner instead of the app's
  // default grey square placeholder.
  Widget _hero() {
    final iconUrl = widget.prizeIconUrl?.trim() ?? '';
    const size = SpinWheelResultCard.heroIconSize;
    final fallback = widget.result.isNoLuck
        ? const Icon(
            Icons.sentiment_dissatisfied_rounded,
            size: size * 0.8,
            color: _gold,
          )
        : const Icon(
            Icons.card_giftcard_rounded,
            size: size * 0.8,
            color: _gold,
          );
    return SizedBox(
      height: 132,
      width: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(left: 22, top: 22, child: _Spark(size: 14)),
          const Positioned(right: 34, top: 8, child: _Spark(size: 18)),
          const Positioned(right: 8, top: 62, child: _Spark(size: 11)),
          const Positioned(left: 40, bottom: 12, child: _Spark(size: 10)),
          iconUrl.isEmpty
              ? fallback
              : AppNetworkImage(
                  url: iconUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  placeholder: const _HeroLoading(size: size),
                  errorWidget: fallback,
                ),
        ],
      ),
    );
  }

  Widget _couponTicket(BuildContext context, String code) {
    return GestureDetector(
      onTap: () => _copy(code),
      child: SizedBox(
        height: 74,
        child: CustomPaint(
          painter: _TicketPainter(
            notchColor: _insetBottom,
            fill: SpinWheelPurple.shade(0.451, 1.6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 8, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(
                        context.translate(
                          LanguageLabelKeys.spinResultCouponCode,
                        ),
                        style: context.tt.labelSmall?.copyWith(
                          color: SpinWheelPurple.shade(-0.027, 0.41),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleLarge?.copyWith(
                          color: SpinWheelPurple.shade(-0.082, 0.95),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SpinWheelPurple.shade(0.404, 1.6),
                      ),
                      child: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 16,
                        color: SpinWheelPurple.shade(-0.082, 0.95),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      _copied
                          ? context.translate(LanguageLabelKeys.copied)
                          : context.translate(LanguageLabelKeys.spinResultCopy),
                      style: context.tt.labelSmall?.copyWith(
                        color: SpinWheelPurple.shade(-0.082, 0.95),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round floating "X" that sits on the card's top-right corner: purple glass
/// disc with a light rim, matching the card. Kept inside the card's own
/// bounds (via top padding) so its whole area is tappable.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SpinWheelPurple.shade(0.110, 1.3),
              SpinWheelPurple.shade(-0.161, 0.96),
            ],
          ),
          border: Border.all(
            color: SpinWheelPurple.shade(0.373, 1.6),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.spinWheelResultCardShadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 20,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// Hero placeholder while the prize icon loads: a round, soft gold glow with
/// a small spinner — blends into the card instead of a grey square.
class _HeroLoading extends StatelessWidget {
  final double size;

  const _HeroLoading({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.spinWheelTitleBottomFillEnd.withValues(alpha: 0.28),
            AppColors.spinWheelTitleBottomFillEnd.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SizedBox(
        width: size * 0.26,
        height: size * 0.26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          strokeCap: StrokeCap.round,
          color: AppColors.spinWheelTitleBottomFillEnd.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  final double size;

  const _Spark({required this.size});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.star_rounded,
    size: size,
    color: AppColors.spinWheelTicketLabel,
    shadows: const [
      Shadow(color: AppColors.spinWheelTicketLabelGlow, blurRadius: 6),
    ],
  );
}

/// Ticket outline: rounded rectangle with a half-circle notch punched out of
/// each side, and a dashed divider ~80% across.
class _TicketPainter extends CustomPainter {
  final Color notchColor;
  final Color fill;

  const _TicketPainter({required this.notchColor, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    const r = 14.0;
    const notch = 11.0;
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)),
      );
    final holes = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(0, size.height / 2), radius: notch),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height / 2),
          radius: notch,
        ),
      );
    final ticket = Path.combine(PathOperation.difference, body, holes);
    canvas.drawShadow(ticket, AppColors.black, 6, true);
    canvas.drawPath(ticket, Paint()..color = fill);

    final dividerX = size.width - 84;
    final dash = Paint()
      ..color = SpinWheelPurple.shade(0.245, 0.74)
      ..strokeWidth = 1.5;
    for (double y = 10; y < size.height - 10; y += 8) {
      canvas.drawLine(Offset(dividerX, y), Offset(dividerX, y + 4), dash);
    }
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.notchColor != notchColor || old.fill != fill;
}

/// Hexagonal "Spin Again" button (pointed left/right sides), dark purple with
/// a lavender rim, overhanging the card's bottom edge.
class _HexButton extends StatefulWidget {
  final String label;
  final bool showIcon; // refresh icon before the label
  final VoidCallback onTap;

  const _HexButton({
    required this.label,
    required this.showIcon,
    required this.onTap,
  });

  @override
  State<_HexButton> createState() => _HexButtonState();
}

class _HexButtonState extends State<_HexButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: 244,
          height: 52,
          child: CustomPaint(
            painter: const _HexPainter(),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  if (widget.showIcon)
                    const Icon(
                      Icons.autorenew_rounded,
                      size: 20,
                      color: AppColors.white,
                    ),
                  AppText(
                    widget.label,
                    style: context.tt.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  const _HexPainter();

  Path _hex(Rect r) {
    final tip = r.height * 0.46;
    return Path()
      ..moveTo(r.left + tip, r.top)
      ..lineTo(r.right - tip, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - tip, r.bottom)
      ..lineTo(r.left + tip, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _hex(Offset.zero & size);
    canvas.drawShadow(outer, AppColors.black, 8, true);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpinWheelPurple.shade(0.373, 1.6),
            SpinWheelPurple.shade(0.216, 1.6),
          ],
        ).createShader(Offset.zero & size),
    );
    final inner = _hex((Offset.zero & size).deflate(4));
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpinWheelPurple.shade(-0.208, 1.03),
            SpinWheelPurple.shade(-0.339, 1.06),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}
