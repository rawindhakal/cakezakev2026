import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

// ── Floating map button (recenter, etc.) ───────────────────────────────────────

class MapButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const MapButton({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: context.theme.shadowColor.withValues(alpha: 0.25),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class TrackingInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  final bool isDark;

  const TrackingInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        AppText(label, style: context.tt.labelSmall?.copyWith(color: subColor)),
        AppText(
          value,
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          maxLines: 2,
          overflow: .ellipsis,
        ),
      ],
    );
  }
}
