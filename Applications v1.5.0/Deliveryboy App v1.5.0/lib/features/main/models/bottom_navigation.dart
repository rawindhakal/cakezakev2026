/// Describes a single bottom navigation tab (label, active/inactive assets).
class BottomNavItem {
  final String label;

  /// Optional SVG asset paths for active / inactive states.
  final String? activeIconPath;
  final String? inactiveIconPath;

  const BottomNavItem({
    required this.label,
    this.activeIconPath,
    this.inactiveIconPath,
  });
}
