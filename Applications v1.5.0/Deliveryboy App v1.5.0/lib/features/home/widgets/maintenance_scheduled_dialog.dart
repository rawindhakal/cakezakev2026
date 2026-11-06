import 'dart:async';

import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Shown once per app session when the settings api reports an upcoming/
/// ongoing scheduled maintenance window (`app_mode_delivery_boy` == '0' but
/// `app_mode_delivery_boy_start`/`app_mode_delivery_boy_end` are set) — as
/// opposed to `RouteNames.maintenance`, the full-screen block shown when
/// `app_mode_delivery_boy` == '1'.
class MaintenanceScheduledDialog extends StatefulWidget {
  final DateTime startLocal;
  final DateTime? endLocal;

  /// Identifies this maintenance window (raw api start+end strings) — stored
  /// on "OK" tap so this exact window isn't shown again on future app opens.
  final String dismissKey;

  const MaintenanceScheduledDialog({
    super.key,
    required this.startLocal,
    this.endLocal,
    required this.dismissKey,
  });

  static bool _shownThisSession = false;

  /// Api sends wall-clock strings with no timezone marker, which is the
  /// server's UTC time — reinterpret as UTC before comparing/displaying,
  /// same convention as [AppDateFormatter].
  static DateTime? _parseApiUtc(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    if (RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw.trim())) {
      return parsed.toUtc();
    }
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    );
  }

  /// Returns true if the dialog was shown.
  static bool maybeShow(BuildContext context, {AppSettingsData? settings}) {
    final data = settings ?? SettingsHiveBox.instance.getAppSettings();
    if (data == null) return false;
    // Full maintenance mode already takes over via RouteNames.maintenance.
    if (data.appModeDeliveryBoy == '1') return false;
    if (_shownThisSession) return false;

    final startUtc = _parseApiUtc(data.appModeDeliveryBoyStart);
    if (startUtc == null) return false;
    final endUtc = _parseApiUtc(data.appModeDeliveryBoyEnd);

    // Window already elapsed — nothing to announce. No end date means the
    // window is open-ended, so there's nothing to check it against.
    if (endUtc != null && DateTime.now().toUtc().isAfter(endUtc)) {
      return false;
    }

    final dismissKey =
        '${data.appModeDeliveryBoyStart}_${data.appModeDeliveryBoyEnd}';
    if (SettingsHiveBox.instance.maintenanceDialogDismissedWindow ==
        dismissKey) {
      return false;
    }

    _shownThisSession = true;
    showDialog(
      context: context,
      barrierColor: context.cs.scrim.withValues(alpha: 0.54),
      builder: (_) => MaintenanceScheduledDialog(
        startLocal: startUtc.toLocal(),
        endLocal: endUtc?.toLocal(),
        dismissKey: dismissKey,
      ),
    );
    return true;
  }

  /// Resets the session flag, e.g. on logout.
  static void resetSession() => _shownThisSession = false;

  @override
  State<MaintenanceScheduledDialog> createState() =>
      _MaintenanceScheduledDialogState();
}

class _MaintenanceScheduledDialogState
    extends State<MaintenanceScheduledDialog> {
  Timer? _ticker;
  Duration? _remaining;
  bool _countingToStart = false;

  @override
  void initState() {
    super.initState();
    if (widget.endLocal != null) {
      _tick();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final end = widget.endLocal;
    if (end == null) return;
    final now = DateTime.now();
    final countingToStart = now.isBefore(widget.startLocal);
    final target = countingToStart ? widget.startLocal : end;
    final remaining = target.difference(now);
    if (remaining.isNegative && !countingToStart) {
      _ticker?.cancel();
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
          _countingToStart = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
        _countingToStart = countingToStart;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String? _duration(BuildContext context) {
    final end = widget.endLocal;
    if (end == null) return null;
    final diff = end.difference(widget.startLocal);
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? '1 day' : '${diff.inDays} days';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? '1 hour' : '${diff.inHours} hours';
    }
    final minutes = diff.inMinutes.clamp(1, 59);
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  static const double _bandHeight = 84;
  static const double _iconSize = 72;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: ThemeConstants.paddingXXL, vertical: ThemeConstants.paddingXXL),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppDecorations.shadowedCard(
              color: context.cs.surface,
              shadowColor: context.cs.scrim.withValues(alpha: 0.2),
              borderRadius: AppRadius.r24,
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: _bandHeight,
                      color: context.cs.primary.withValues(alpha: 0.08),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ThemeConstants.paddingXXL,
                        _iconSize / 2 + 16,
                        ThemeConstants.paddingXXL,
                        ThemeConstants.paddingXXL,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AppText(
                            context.translate(
                              LanguageLabelKeys.scheduledMaintenanceTitle,
                            ),
                            textAlign: TextAlign.center,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.cs.onSurface,
                            ),
                          ),
                          AppSpacing.h8,
                          Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              style: tt.bodyMedium?.copyWith(
                                color: context.cs.onSurfaceVariant,
                                height: 1.45,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${context.translate(LanguageLabelKeys.scheduledMaintenanceMessagePrefix)} ',
                                ),
                                TextSpan(
                                  text: AppDateFormatter.formatDateTime(
                                    widget.startLocal,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: context.cs.onSurface,
                                  ),
                                ),
                                if (_duration(context) != null)
                                  TextSpan(text: ' · ${_duration(context)}'),
                              ],
                            ),
                          ),
                          if (_remaining != null) ...[
                            AppSpacing.h24,
                            Text(
                              context
                                  .translate(
                                    _countingToStart
                                        ? LanguageLabelKeys
                                              .scheduledMaintenanceStartsIn
                                        : LanguageLabelKeys
                                              .scheduledMaintenanceEndsIn,
                                  )
                                  .toUpperCase(),
                              style: tt.labelSmall?.copyWith(
                                color: context.cs.onSurfaceVariant,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppSpacing.h12,
                            _CountdownPill(remaining: _remaining!),
                          ],
                          AppSpacing.h24,
                          AppButton(
                            label: context.translate(LanguageLabelKeys.ok),
                            variant: AppButtonVariant.primary,
                            height: context.screenHeight * 0.062,
                            onPressed: () {
                              SettingsHiveBox.instance
                                  .setMaintenanceDialogDismissedWindow(
                                    widget.dismissKey,
                                  );
                              AppNavigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: _bandHeight - _iconSize / 2,
                  child: Container(
                    width: _iconSize,
                    height: _iconSize,
                    alignment: Alignment.center,
                    decoration: AppDecorations.circle(
                      color: context.cs.primary,
                      border: Border.all(color: context.cs.surface, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: context.cs.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: AppSvgIcon(
                      AssetsConstants.warningIcon,
                      size: ThemeConstants.iconXL,
                      color: context.cs.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified countdown pill — `08 : 45 : 12` style, digit groups separated by
/// colons inside one rounded container. Leading zero units (days, then
/// hours) drop off once irrelevant; seconds always show.
class _CountdownPill extends StatelessWidget {
  final Duration remaining;

  const _CountdownPill({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    final segments = <(String, String)>[
      if (days > 0) (days.toString().padLeft(2, '0'), 'DAYS'),
      if (days > 0 || hours > 0) (hours.toString().padLeft(2, '0'), 'HRS'),
      (minutes.toString().padLeft(2, '0'), 'MINS'),
      (seconds.toString().padLeft(2, '0'), 'SECS'),
    ];

    final tt = context.tt;
    final accent = context.cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.paddingXL, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: AppRadius.r16,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.paddingS),
                child: Text(
                  ':',
                  style: tt.titleLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            _DigitGroup(
              value: segments[i].$1,
              label: segments[i].$2,
              textTheme: tt,
              color: accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _DigitGroup extends StatelessWidget {
  final String value;
  final String label;
  final TextTheme textTheme;
  final Color color;

  const _DigitGroup({
    required this.value,
    required this.label,
    required this.textTheme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(height: context.screenHeight * 0.005),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
