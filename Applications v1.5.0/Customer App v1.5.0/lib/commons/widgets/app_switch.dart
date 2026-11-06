import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Common themed switch — flat track/thumb colors, no default M3 border
/// artifacts. Used across settings/toggle rows app-wide.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.88,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStatePropertyAll(context.cs.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? context.cs.primary
              : context.cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
