import 'package:flutter/material.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'home_header_profile_row.dart';

/// Sliver header showing the delivery boy's profile and online status.
/// Pinned so it stays fixed at the top while the rest of the dashboard scrolls.
class HomeHeader extends StatelessWidget {
  final String name;
  final String email;
  final String profileUrl;
  final bool isOnline;
  final VoidCallback onToggle;

  const HomeHeader({
    super.key,
    required this.name,
    required this.email,
    required this.profileUrl,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final extent = context.topSafePadding + 16 + 46 + 14;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _HomeHeaderDelegate(
        extent: extent,
        child: HomeHeaderProfileRow(
          name: name,
          email: email,
          profileUrl: profileUrl,
          isOnline: isOnline,
          onToggle: onToggle,
        ),
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _HomeHeaderDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: AppDecorations.card(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: context.topSafePadding + 16,
          start: ThemeConstants.paddingXL,
          end: ThemeConstants.paddingXL,
          bottom: 14,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
