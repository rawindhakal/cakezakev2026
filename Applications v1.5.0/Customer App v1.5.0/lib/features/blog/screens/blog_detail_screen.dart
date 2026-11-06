import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/widgets/blog_meta_info.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class BlogDetailScreen extends StatefulWidget {
  final Blog blog;
  const BlogDetailScreen({super.key, required this.blog});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final _scrollController = ScrollController();
  final _progress = ValueNotifier<double>(0);
  final _titleKey = GlobalKey();
  // True once the in-page title has scrolled up under the app bar.
  final _showTitleInBar = ValueNotifier<bool>(false);
  // App bar shadow flag — flips only when leaving/returning to the top, so
  // the app bar isn't rebuilt on every scroll tick.
  final _scrolled = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateProgress);
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    _scrolled.value = _scrollController.offset > 0;
    final max = _scrollController.position.maxScrollExtent;
    _progress.value = max <= 0
        ? 0
        : (_scrollController.offset / max).clamp(0.0, 1.0);
    _updateBarTitle();
  }

  void _updateBarTitle() {
    final box = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final titleBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final barBottom = MediaQuery.paddingOf(context).top + kToolbarHeight;
    _showTitleInBar.value = titleBottom <= barBottom;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _progress.dispose();
    _showTitleInBar.dispose();
    _scrolled.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        titleWidget: _buildBarTitle(context),
        shadowListenable: _scrolled,
      ),
      body: Stack(
        children: [
          _buildScrollBody(context),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: RepaintBoundary(child: _buildProgressBar(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarTitle(BuildContext context) {
    final style = context.tt.titleLarge?.copyWith(color: context.cs.onSurface);
    return ValueListenableBuilder<bool>(
      valueListenable: _showTitleInBar,
      builder: (context, showBlogTitle, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Align(
          key: ValueKey(showBlogTitle),
          alignment: AlignmentDirectional.centerStart,
          child: AppText(
            showBlogTitle
                ? (widget.blog.title ?? '')
                : context.translate(LanguageLabelKeys.blogDetail),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, value, _) => LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: Colors.transparent,
        color: context.cs.primary,
      ),
    );
  }

  Widget _buildScrollBody(BuildContext context) {
    final hasHero = (widget.blog.imageUrl ?? '').isNotEmpty;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsetsDirectional.only(
        bottom: ThemeConstants.spaceXXXL + context.bottomSafePadding,
      ),
      child: SlideAnimationList(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHero) _buildHeroImage(context),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final blog = widget.blog;
    final categoryName = blog.category?.name;
    final hasCategory = categoryName != null && categoryName.isNotEmpty;
    final hasDate = (blog.createdAt ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasCategory || hasDate)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: ThemeConstants.paddingS,
              ),
              child: Row(
                children: [
                  if (hasCategory)
                    Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingS,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      decoration: AppDecorations.box(
                        color: context.cs.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r4,
                      ),
                      child: AppText(
                        categoryName,
                        style: context.tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.cs.primary,
                        ),
                      ),
                    ),
                  if (hasDate) ...[
                    const Spacer(),
                    AppText(
                      AppDateFormatter.formatDateTime(blog.createdAt!),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          AppText(
            blog.title ?? '',
            key: _titleKey,
            style: context.tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
              height: 1.3,
            ),
          ),
          AppSpacing.h10,
          BlogMetaInfo(
            blog: blog,
            iconSize: 14,
            dateIconSize: 13,
            groupSpacing: AppSpacing.w16,
            showDate: false,
            textStyle: context.tt.bodySmall?.copyWith(
              fontSize: 13,
              color: context.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h20,
          if ((blog.description ?? '').isNotEmpty)
            HtmlWidget(
              blog.description!,
              textStyle: context.tt.bodyLarge?.copyWith(
                color: context.cs.onSurface,
                height: 1.65,
              ),
            ),
          if ((blog.tagNames ?? []).isNotEmpty) ...[
            AppSpacing.h24,
            _buildTags(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return AppNetworkImage(
      url: widget.blog.imageUrl!,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: _heroPlaceholder(context, height: 220),
      errorWidget: _heroPlaceholder(context, height: 220),
    );
  }

  Widget _heroPlaceholder(BuildContext context, {required double height}) {
    return Container(
      height: height,
      color: context.cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.3,
        heightFactor: 0.3,
        child: AppSvgIcon(AssetsConstants.placeholder, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: ThemeConstants.spaceS,
      runSpacing: 6,
      children: (widget.blog.tagNames ?? [])
          .map(
            (tag) => Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingS,
                vertical: ThemeConstants.paddingXS,
              ),
              decoration: AppDecorations.box(
                color: context.cs.surfaceContainerHighest,
                borderRadius: AppRadius.r20,
                border: Border.all(color: context.cs.outlineVariant),
              ),
              child: AppText(
                '${AppConstants.hashSymbol}$tag',
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
