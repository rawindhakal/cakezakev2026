import 'dart:async';

import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Solid-color header sitting above the map (Blinkit/Zomato style) — big bold
/// "Your order #123 is on its way" with an "Arriving in N minutes" ETA.
/// Before live tracking starts, this ticks down locally from an absolute
/// `created_at + total_deliver_time` target (recomputed every second, not a
/// locally-decrementing counter, so it doesn't restart when the screen is
/// closed/reopened). Once the rider's live-tracking API starts returning
/// `time_to_deliver` (a fresh, distance-based estimate refreshed every 30s
/// poll as the rider moves), the local per-second ticking stops entirely —
/// the value is displayed as-is and simply updates whenever a new poll
/// result arrives, since the rider getting closer already keeps it current.
class OrderTrackingTopBar extends StatefulWidget {
  final int? orderId;
  final VoidCallback onBack;

  /// Order creation timestamp from API (server time). Combined with
  /// [totalDeliverTime] to compute the absolute ETA before live tracking
  /// takes over.
  final String? createdAt;

  /// Raw ETA duration from API, e.g. "12 mins" / "12", added to [createdAt].
  final String? totalDeliverTime;

  /// Latest `time_to_deliver` from the live-tracking API (e.g. "7 minutes"),
  /// refreshed every 30s poll while the order is out for delivery. Takes
  /// over from [createdAt]/[totalDeliverTime] as the ETA source once
  /// present, since it reflects the rider's real live position/distance
  /// rather than the original order-time estimate.
  final String? liveTimeToDeliver;

  /// Order status name from API (e.g. "Packing your order"). Falls back to
  /// the localized "Your order #123 is on its way" when absent.
  final String? statusLabel;

  const OrderTrackingTopBar({
    super.key,
    required this.orderId,
    required this.onBack,
    this.createdAt,
    this.totalDeliverTime,
    this.liveTimeToDeliver,
    this.statusLabel,
  });

  @override
  State<OrderTrackingTopBar> createState() => _OrderTrackingTopBarState();
}

class _OrderTrackingTopBarState extends State<OrderTrackingTopBar> {
  Timer? _timer;
  DateTime? _etaTarget;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant OrderTrackingTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createdAt != widget.createdAt ||
        oldWidget.totalDeliverTime != widget.totalDeliverTime ||
        oldWidget.liveTimeToDeliver != widget.liveTimeToDeliver) {
      _startCountdown();
    }
  }

  /// Extracts the leading integer minutes from an api duration string, e.g.
  /// "12 mins" / "7 minutes" / "12".
  static int? _parseMinutes(String? raw) =>
      int.tryParse(RegExp(r'\d+').firstMatch(raw ?? '')?.group(0) ?? '');

  void _startCountdown() {
    _timer?.cancel();
    final liveMinutes = _parseMinutes(widget.liveTimeToDeliver);
    if (liveMinutes != null && liveMinutes > 0) {
      // Live tracking already refreshes this every 30s as the rider moves —
      // a local per-second countdown on top would just drift and disagree
      // with the next poll, so display the api value as-is until then.
      _etaTarget = null;
      _remainingSeconds = liveMinutes * 60;
      return;
    }
    final minutes = _parseMinutes(widget.totalDeliverTime);
    final createdAt = AppDateFormatter.parse(widget.createdAt);
    _etaTarget = (minutes != null && minutes > 0 && createdAt != null)
        ? createdAt.add(Duration(minutes: minutes))
        : null;
    if (_etaTarget == null) {
      _remainingSeconds = null;
      return;
    }
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_updateRemaining()) timer.cancel();
    });
  }

  /// Recomputes remaining seconds from the absolute [_etaTarget] rather than
  /// decrementing a local counter, so it self-corrects after any pause
  /// (backgrounding, screen close/reopen) instead of drifting. Returns false
  /// once the target has passed, so the caller can stop the timer.
  bool _updateRemaining() {
    final target = _etaTarget;
    if (target == null) return false;
    final remaining = target.difference(DateTime.now()).inSeconds;
    setState(() => _remainingSeconds = remaining > 0 ? remaining : 0);
    return remaining > 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = context.cs.onPrimary;
    final remaining = _remainingSeconds;
    final remainingMinutes = remaining == null ? null : (remaining / 60).ceil();
    return Container(
      width: double.infinity,
      color: context.cs.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingM,
            ThemeConstants.paddingS,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
          ),
          child: Row(
            crossAxisAlignment: .center,
            spacing: ThemeConstants.spaceM,
            children: [
              _HeaderButton(
                onTap: widget.onBack,
                icon: AssetsConstants.arrowLeftIcon,
                onPrimary: onPrimary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .center,
                  spacing: ThemeConstants.spaceXXS,
                  children: [
                    AppText(
                      (widget.statusLabel?.isNotEmpty ?? false)
                          ? '${context.translate(LanguageLabelKeys.yourOrder)} '
                                '${context.translate(LanguageLabelKeys.isText)} '
                                '${widget.statusLabel!}'
                          : '${context.translate(LanguageLabelKeys.yourOrder)} '
                                '${AppConstants.hashSymbol}${widget.orderId} '
                                '${context.translate(LanguageLabelKeys.isOnItsWay)}',
                      style: context.tt.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: onPrimary,
                      ),
                      textAlign: .center,
                      maxLines: 2,
                      overflow: .ellipsis,
                    ),
                    AppText(
                      remainingMinutes != null && remainingMinutes > 0
                          ? '${context.translate(LanguageLabelKeys.arrivingIn)} '
                                '${remainingMinutes == 1 ? context.translate(LanguageLabelKeys.durationOneMinute) : context.translate(LanguageLabelKeys.durationMinutes).replaceAll('{count}', '$remainingMinutes')}'
                          : context.translate(
                              LanguageLabelKeys.reachingYouSoon,
                            ),
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: onPrimary.withValues(alpha: 0.85),
                      ),
                      textAlign: .center,
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

class _HeaderButton extends StatelessWidget {
  final VoidCallback onTap;
  final String icon;
  final Color onPrimary;

  const _HeaderButton({
    required this.onTap,
    required this.icon,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Transform.flip(
          flipX: Directionality.of(context) == TextDirection.rtl,
          child: AppSvgIcon(icon, size: ThemeConstants.iconS, color: onPrimary),
        ),
      ),
    );
  }
}
