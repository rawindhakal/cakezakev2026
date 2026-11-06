import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_network_video.dart';
import 'package:customer/utils/media_type.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/features/products/widgets/product_detail_view.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  /// Opened from the product detail gallery, which already decoded these
  /// images at its hero size — shown as each page's placeholder so the
  /// viewer never flashes the logo placeholder while decoding its own.
  final bool fromProductDetail;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.fromProductDetail = false,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late ScrollController _thumbnailController;
  late int _currentIndex;
  double? _precachedPageHeight;

  // Fixed decode size for thumbnails — otherwise the selected one's thicker
  // border shrinks its box, changes the decode key and re-flashes the
  // placeholder every time the page changes.
  static const double _thumbnailSize = 80;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbnailController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  void _scrollToThumbnail(int index) {
    final thumbnailWidth = 80.0;
    final offset =
        (index * (thumbnailWidth + 8)) -
        (context.screenWidth / 2 - thumbnailWidth / 2);
    _thumbnailController.animateTo(
      offset.clamp(0.0, _thumbnailController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // PageView only builds a page once it starts sliding in, so without this
  // every page past the first decodes mid-swipe and shows the placeholder.
  // Same height as each page's AppNetworkImage, so it's the same cache entry.
  void _precachePages(double pageHeight) {
    if (_precachedPageHeight == pageHeight) return;
    _precachedPageHeight = pageHeight;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final url in widget.images) {
        AppNetworkImage.precache(context, url, height: pageHeight);
        AppNetworkImage.precache(context, url, height: _thumbnailSize);
      }
    });
  }

  Widget? _heroPlaceholder(String url) {
    if (!widget.fromProductDetail) return null;
    final (memCacheWidth, memCacheHeight) = productHeroMemCacheSize(context);
    return AppNetworkImage(
      url: url,
      fit: BoxFit.contain,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: context.cs.surface,
      appBar: CustomAppBar(
        title: '${_currentIndex + 1} / ${widget.images.length}',
        showBackButton: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
            child: CircleAvatar(
              backgroundColor: context.cs.onSurface,
              child: IconButton(
                icon: AppSvgIcon(
                  AssetsConstants.closeIcon,
                  color: context.cs.surface,
                ),
                onPressed: () => AppNavigator.pop(context),
                iconSize: 20,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageHeight = constraints.maxHeight;
                _precachePages(pageHeight);
                return PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _scrollToThumbnail(index);
                  },
                  itemCount: widget.images.length,
                  itemBuilder: (_, i) => Center(
                    child: isVideoUrl(widget.images[i])
                        ? AppNetworkVideo(
                            url: widget.images[i],
                            play: i == _currentIndex,
                            muted: false,
                            showControls: true,
                          )
                        : AppNetworkImage(
                            url: widget.images[i],
                            height: pageHeight,
                            fit: BoxFit.contain,
                            placeholder: _heroPlaceholder(widget.images[i]),
                          ),
                  ),
                );
              },
            ),
          ),
          if (widget.images.length > 1) ...[
            AppSpacing.h12,
            SizedBox(
              height: 80,
              child: ListView.builder(
                controller: _thumbnailController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ThemeConstants.paddingM,
                ),
                itemCount: widget.images.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: ThemeConstants.paddingS,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 80,
                      decoration: AppDecorations.box(
                        border: Border.all(
                          color: _currentIndex == i
                              ? context.cs.primary
                              : context.cs.outlineVariant,
                          width: _currentIndex == i ? 2 : 1,
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.r6,
                        child: AppNetworkImage(
                          url: widget.images[i],
                          fit: BoxFit.contain,
                          memCacheHeight:
                              (_thumbnailSize *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.h12,
          ],
        ],
      ),
    );
  }
}
