import 'package:customer/commons/utils/url_launcher_helper.dart';
import 'package:customer/commons/widgets/app_bouncing.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';

import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/screens/sub_category_screen.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';

import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/features/notifications/notification/cubit/notifications_cubit.dart';
import 'package:customer/features/notifications/notification/models/enums/notification_type.dart';
import 'package:customer/features/notifications/notification/models/notification_model.dart';
import 'package:customer/features/notifications/notification/widgets/notification_list_skeleton_loader.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<NotificationsCubit>().fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.notifications),
        scrollController: _scrollCtrl,
      ),
      body:
          BlocBuilder<
            NotificationsCubit,
            PaginationState<NotificationModelData>
          >(
            builder: (context, state) {
              if (state is PaginationLoading<NotificationModelData>) {
                return const NotificationListSkeletonLoader();
              }

              if (state is PaginationError<NotificationModelData>) {
                return EmptyStateWidget(
                  imagePath: AssetsConstants.noNotificationFound,
                  title: state.message,
                  subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
                  onRetry: () => context.read<NotificationsCubit>().refresh(),
                );
              }

              if (state is PaginationLoaded<NotificationModelData>) {
                if (state.data.isEmpty) {
                  return EmptyStateWidget(
                    imagePath: AssetsConstants.noNotificationFound,
                    title: context.translate(LanguageLabelKeys.noNotifications),
                    subtitle: context.translate(
                      LanguageLabelKeys.notificationsEmpty,
                    ),
                  );
                }
                return _NotificationList(
                  items: state.data,
                  isLoadingMore: state.isFetchingMore,
                  hasMore: state.hasMore,
                  scrollCtrl: _scrollCtrl,
                  onRefresh: () => context.read<NotificationsCubit>().refresh(),
                );
              }

              return AppSpacing.shrink;
            },
          ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final List<NotificationModelData> items;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollCtrl;
  final Future<void> Function() onRefresh;

  const _NotificationList({
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollCtrl,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.cs.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingM,
          ThemeConstants.paddingL,
          ThemeConstants.paddingM + context.bottomSafePadding,
        ),
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => AppSpacing.h8,
        itemBuilder: (context, i) {
          if (i == items.length) {
            return PaginatedListFooter(
              isLoadingMore: isLoadingMore,
              hasMore: hasMore,
              skeletonBuilder: (_) => const NotificationListSkeletonLoader(
                itemCount: 1,
                shrinkWrap: true,
              ),
            );
          }
          return _NotificationCard(item: items[i]);
        },
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationModelData item;

  const _NotificationCard({required this.item});

  Widget _iconBox(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: AppDecorations.box(
        color: context.cs.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.r10,
      ),
      child: AppSvgIcon(
        AssetsConstants.notificationIcon,
        size: ThemeConstants.iconM,
        color: context.cs.primary,
        fit: BoxFit.scaleDown,
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (item.notificationType) {
      case NotificationType.url:
        openExternalUrl(item.linkUrl);
      case NotificationType.product:
        AppNavigator.pushNamed(
          context,
          RouteNames.productDetail,
          arguments: item.typeId,
        );
      case NotificationType.category:
        final category = Category(
          id: item.typeId,
          hasChild: false,
          name: item.categoryName,
        );
        AppNavigator.push(
          context,
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => SubCategoryCubit(parentCategoryId: item.typeId),
              ),
              BlocProvider(
                create: (_) =>
                    ProductCubit()..loadProducts(categoryId: item.typeId),
              ),
              BlocProvider(
                create: (_) =>
                    FilterCubit()..loadFilters(categoryId: item.typeId),
              ),
            ],
            child: SubCategoryScreen(
              parentCategory: category,
              showSidebar: false,
            ),
          ),
        );
      case NotificationType.wallet:
        AppNavigator.pushNamed(context, RouteNames.walletTransactions);
      case NotificationType.chat:
        // List payload only carries the conversation id (no
        // chatType/recipient) — chat pushes are always admin support chat,
        // same as ProfileScreen's "Chat with Support" entry point.
        AppNavigator.pushNamed(
          context,
          RouteNames.chat,
          arguments: ChatScreenArgs(
            chatType: ChatType.adminChat,
            recipientName: context.translate(LanguageLabelKeys.chatWithSupport),
            recipientId: AuthHiveBox.instance.userId,
            conversationId: item.typeId,
          ),
        );
      case NotificationType.order:
      case NotificationType.returnRequest:
        AppNavigator.pushNamed(
          context,
          RouteNames.orderDetail,
          arguments: item.typeId,
        );
      case NotificationType.cart:
        AppNavigator.pushNamed(context, RouteNames.checkout);
      case NotificationType.defaultType:
      case NotificationType.user:
      case NotificationType.unknown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBouncing(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        decoration: AppDecorations.shadowedCard(
          color: context.cs.surface,
          shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
          borderRadius: AppRadius.r16,
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        child: Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceM,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AppText(
                    item.title,
                    style: context.tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                  if (item.message.isNotEmpty) ...[
                    AppSpacing.h4,
                    AppText(
                      item.message,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: .ellipsis,
                    ),
                  ],
                  if (item.dateSent.isNotEmpty) ...[
                    AppSpacing.h6,
                    Row(
                      spacing: ThemeConstants.spaceXS,
                      children: [
                        AppSvgIcon(
                          AssetsConstants.timeIcon,
                          size: ThemeConstants.iconXS,
                          color: context.cs.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        AppText(
                          AppDateFormatter.formatDateTime(item.dateSent),
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            item.imageUrl.isNotEmpty
                ? AppNetworkImage(
                    url: item.imageUrl,
                    width: context.screenWidth * 0.13,
                    height: context.screenWidth * 0.13,
                    borderRadius: AppRadius.r10,
                  )
                : _iconBox(context),
          ],
        ),
      ),
    );
  }
}
