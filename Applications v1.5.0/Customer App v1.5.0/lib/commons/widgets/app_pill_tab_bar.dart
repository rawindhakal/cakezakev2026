import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

class AppPillTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const AppPillTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;

    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r20,
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        indicator: AppDecorations.box(
          borderRadius: AppRadius.r16,
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsetsDirectional.zero,
        dividerColor: Colors.transparent,
        labelColor: context.cs.onPrimary,
        unselectedLabelColor: context.cs.onSurfaceVariant,
        labelStyle: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        splashBorderRadius: AppRadius.r16,
        tabs: [for (final t in tabs) Tab(height: 44, text: t)],
      ),
    );
  }
}
