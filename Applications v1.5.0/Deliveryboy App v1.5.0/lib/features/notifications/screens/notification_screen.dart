import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/features/notifications/widgets/notification_settings_skeleton_loader.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/features/notifications/models/notification_settings_model.dart';
import 'package:deliveryboy/features/notifications/widgets/notification_save_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_save_cubit.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Screen with tabs for email/mobile/SMS notification status preferences.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _appBarShadow = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appBarShadow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => NotificationCubit()),
        BlocProvider(create: (context) => NotificationSaveCubit()),
      ],
      child: BlocConsumer<ConnectivityCubit, ConnectivityState>(
        listener: (context, state) {
          if (state is ConnectivityConnected) {
            context.read<NotificationCubit>().getNotificationSettings();
          }
        },
        builder: (context, connectivityState) {
          final isOffline = connectivityState is ConnectivityDisconnected;
          return AppScaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: CustomAppBar(
              title: context.translate(LanguageLabelKeys.notifications),
              shadowListenable: _appBarShadow,
              // Tabs would sit above an empty body while offline.
              bottom: isOffline
                  ? null
                  : _NotifTabBar(controller: _tabController),
            ),
            // Save bar hidden while offline — there is nothing to save against
            // and its tap would only queue a failing request.
            bottomNavigationBar: isOffline ? null : const NotificationSaveBar(),
            // Offline state lives in the body so the app bar — and its back
            // button — stays available on this pushed route.
            body: isOffline
                ? AppNoInternetFullScreen(
                    embedded: true,
                    onRetry: () => context
                        .read<NotificationCubit>()
                        .getNotificationSettings(),
                  )
                : MultiBlocListener(
                    listeners: [
                      BlocListener<
                        NotificationSaveCubit,
                        NotificationSaveState
                      >(
                        listener: (context, saveState) {
                          if (saveState is NotificationSaveLoaded) {
                            AppSnackBar.show(
                              context: context,
                              message: context.translate(
                                LanguageLabelKeys.settingsSaved,
                              ),
                              type: SnackBarType.success,
                            );
                            context
                                .read<NotificationCubit>()
                                .getNotificationSettings();
                          } else if (saveState is NotificationSaveError) {
                            AppSnackBar.show(
                              context: context,
                              message: saveState.message,
                              type: SnackBarType.error,
                            );
                          }
                        },
                      ),
                    ],
                    child: BlocBuilder<NotificationCubit, NotificationState>(
                      builder: (context, state) {
                        if (state is NotificationLoading) {
                          return const NotificationSettingsSkeletonLoader();
                        }
                        if (state is NotificationError) {
                          return EmptyStateWidget(
                            imagePath: AssetsConstants.noNotificationFound,
                            title: state.message,
                            subtitle: context.translate(
                              LanguageLabelKeys.pullDownToRefresh,
                            ),
                            onRetry: () => context
                                .read<NotificationCubit>()
                                .getNotificationSettings(),
                          );
                        }
                        if (state is NotificationInitial) {
                          context
                              .read<NotificationCubit>()
                              .getNotificationSettings();
                          return const NotificationSettingsSkeletonLoader();
                        }
                        if (state is NotificationLoaded) {
                          return _buildBody(context, state);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationLoaded state) {
    final statuses = state.data.data ?? [];

    if (statuses.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noNotificationFound,
        title: context.translate(LanguageLabelKeys.noNotificationSettings),
        subtitle: context.translate(LanguageLabelKeys.noNotificationSettings),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _ChannelList(
          statuses: statuses,
          channel: _NotifChannel.email,
          onScrolledChanged: (v) => _appBarShadow.value = v,
        ),
        _ChannelList(
          statuses: statuses,
          channel: _NotifChannel.mobile,
          onScrolledChanged: (v) => _appBarShadow.value = v,
        ),
        _ChannelList(
          statuses: statuses,
          channel: _NotifChannel.sms,
          onScrolledChanged: (v) => _appBarShadow.value = v,
        ),
      ],
    );
  }
}

// ── Notification channel ─────────────────────────────────────────────────────

enum _NotifChannel { email, mobile, sms }

bool? _channelValue(Events event, _NotifChannel channel) {
  final channels = event.channels;
  return switch (channel) {
    _NotifChannel.email => channels?.mail,
    _NotifChannel.mobile => channels?.push,
    _NotifChannel.sms => channels?.sms,
  };
}

// ── Pill tab bar for AppBar bottom ───────────────────────────────────────────

class _NotifTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  const _NotifTabBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingXS, ThemeConstants.paddingL, ThemeConstants.paddingM),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
      height: context.screenHeight * 0.054,
      decoration: AppDecorations.card(
        color: context.cs.surfaceContainer,
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: AppDecorations.card(
          color: context.cs.primary,
          borderRadius: AppRadius.r10,
          boxShadow: [
            BoxShadow(
              color: context.cs.primary.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: AppRadius.r10,
        labelColor: context.cs.onPrimary,
        unselectedLabelColor: context.cs.onSurfaceVariant,
        labelStyle: context.tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: context.tt.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(text: context.translate(LanguageLabelKeys.email)),
          Tab(text: context.translate(LanguageLabelKeys.notifications)),
          Tab(text: context.translate(LanguageLabelKeys.sms)),
        ],
      ),
    );
  }
}

// ── Channel list (one tab) ────────────────────────────────────────────────────

class _ChannelList extends StatefulWidget {
  final List<AppNotificationSettingsData> statuses;
  final _NotifChannel channel;
  final ValueChanged<bool>? onScrolledChanged;

  const _ChannelList({
    required this.statuses,
    required this.channel,
    this.onScrolledChanged,
  });

  @override
  State<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<_ChannelList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_notifyScrolled);
  }

  void _notifyScrolled() {
    widget.onScrolledChanged?.call(
      _scrollController.hasClients && _scrollController.offset > 0,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_notifyScrolled);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.statuses;
    final channel = widget.channel;
    return RefreshIndicator(
      color: context.cs.primary,
      onRefresh: () async =>
          context.read<NotificationCubit>().getNotificationSettings(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final category = statuses[index];
          final events = category.events ?? [];
          // Every event in this category is null for this channel (e.g. no
          // SMS variant anywhere) — the tiles all hide themselves, so the
          // category header would otherwise be left dangling with nothing
          // under it.
          final hasVisibleEvent = events.any(
            (e) => _channelValue(e, channel) != null,
          );
          if (!hasVisibleEvent) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (category.category != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: ThemeConstants.paddingS, bottom: ThemeConstants.paddingS),
                  child: AppText(
                    category.category!,
                    style: context.tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
              ...events.map(
                (event) => _ChannelTile(event: event, channel: channel),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Single channel tile ───────────────────────────────────────────────────────

class _ChannelTile extends StatefulWidget {
  final Events event;
  final _NotifChannel channel;

  const _ChannelTile({required this.event, required this.channel});

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  bool? _currentValue() => _channelValue(widget.event, widget.channel);

  void _setValue(bool val) {
    final channels = widget.event.channels;
    if (channels == null) return;
    switch (widget.channel) {
      case _NotifChannel.email:
        channels.mail = val;
      case _NotifChannel.mobile:
        channels.push = val;
      case _NotifChannel.sms:
        channels.sms = val;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _currentValue();
    // Channel isn't applicable to this event (e.g. no SMS variant) — skip
    // the row entirely instead of showing a placeholder "-".
    if (value == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow.withValues(alpha: 0.06),
        borderRadius: AppRadius.r14,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                widget.event.label ?? '',
                style: context.tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.88,
              child: Switch(
                value: value,
                onChanged: (val) => setState(() => _setValue(val)),
                activeThumbColor: context.cs.primary,
                activeTrackColor: context.cs.primary.withValues(alpha: 0.3),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
