import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/notifications/notification_setting/models/notification_setting_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_switch.dart';

import '../cubit/notification_settings_cubit.dart';
import '../cubit/notification_settings_save_cubit.dart';
import '../widgets/notification_settings_skeleton_loader.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
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
        BlocProvider(create: (_) => NotificationSettingsCubit()),
        BlocProvider(create: (_) => NotificationSettingsSaveCubit()),
      ],
      child: BlocConsumer<ConnectivityCubit, ConnectivityState>(
        listener: (context, state) {
          if (state is ConnectivityConnected) {
            context.read<NotificationSettingsCubit>().getNotificationSettings();
          }
        },
        builder: (context, connectivityState) {
          return AppScaffold(
            appBar: CustomAppBar(
              title: context.translate(LanguageLabelKeys.notificationSettings),
              shadowListenable: _appBarShadow,
              bottom: _NotifTabBar(controller: _tabController),
            ),
            // Offline replaces the body only, so the app bar's back button
            // keeps working.
            body: connectivityState is ConnectivityDisconnected
                ? const AppNoInternetView()
                : MultiBlocListener(
                    listeners: [
                      BlocListener<
                        NotificationSettingsSaveCubit,
                        NotificationSettingsSaveState
                      >(
                        listener: (context, saveState) {
                          if (saveState is NotificationSettingsSaveLoaded) {
                            AppSnackBar.show(
                              context: context,
                              message: context.translate(
                                LanguageLabelKeys.settingsSaved,
                              ),
                              type: SnackBarType.success,
                            );
                            context
                                .read<NotificationSettingsCubit>()
                                .getNotificationSettings();
                          } else if (saveState
                              is NotificationSettingsSaveError) {
                            AppSnackBar.show(
                              context: context,
                              message: saveState.message,
                              type: SnackBarType.error,
                            );
                          }
                        },
                      ),
                    ],
                    child:
                        BlocBuilder<
                          NotificationSettingsCubit,
                          NotificationSettingsState
                        >(
                          builder: (context, state) {
                            if (state is NotificationSettingsInitial) {
                              context
                                  .read<NotificationSettingsCubit>()
                                  .getNotificationSettings();
                              return const NotificationSettingsSkeletonLoader();
                            }
                            if (state is NotificationSettingsLoading) {
                              return const NotificationSettingsSkeletonLoader();
                            }
                            if (state is NotificationSettingsError) {
                              return EmptyStateWidget(
                                imagePath: AssetsConstants.noNotificationFound,
                                title: state.message,
                                subtitle: context.translate(
                                  LanguageLabelKeys.pullToRefresh,
                                ),
                                onRetry: () => context
                                    .read<NotificationSettingsCubit>()
                                    .getNotificationSettings(),
                              );
                            }
                            if (state is NotificationSettingsLoaded) {
                              return _buildBody(context, state);
                            }
                            return AppSpacing.shrink;
                          },
                        ),
                  ),
            bottomNavigationBar: _SaveBar(),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationSettingsLoaded state) {
    final statuses = state.notificationSettings.data ?? [];

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
          channel: _NotifChannel.notification,
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

enum _NotifChannel { email, notification, sms }

bool? _channelValue(Events event, _NotifChannel channel) {
  final channels = event.channels;
  return switch (channel) {
    _NotifChannel.email => channels?.mail,
    _NotifChannel.notification => channels?.push,
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
      margin: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingXS,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
      ),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
      height: 44,
      decoration: AppDecorations.box(
        color: context.cs.surfaceContainer,
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: AppDecorations.box(
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
          context.read<NotificationSettingsCubit>().getNotificationSettings(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
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
                  padding: const EdgeInsetsDirectional.only(
                    top: ThemeConstants.paddingS,
                    bottom: ThemeConstants.paddingS,
                  ),
                  child: AppText(
                    category.category!,
                    style: context.tt.bodyMedium?.copyWith(
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
      case _NotifChannel.notification:
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
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingS),
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
          vertical: ThemeConstants.paddingM,
        ),
        child: Row(
          children: [
            // Name
            Expanded(
              child: AppText(
                widget.event.label ??
                    context.translate(LanguageLabelKeys.unknown),
                style: context.tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
              ),
            ),
            AppSwitch(
              value: value,
              onChanged: (val) => setState(() => _setValue(val)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Save bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
      builder: (context, state) {
        if (state is! NotificationSettingsLoaded) return AppSpacing.shrink;
        if (state.notificationSettings.data?.isEmpty ?? true) {
          return AppSpacing.shrink;
        }

        return BlocBuilder<
          NotificationSettingsSaveCubit,
          NotificationSettingsSaveState
        >(
          builder: (context, saveState) {
            final isLoading = saveState is NotificationSettingsSaveLoading;
            return Container(
              padding: EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingL,
                ThemeConstants.paddingM,
                ThemeConstants.paddingL,
                context.bottomSafePadding + ThemeConstants.paddingM,
              ),
              decoration: AppDecorations.box(
                color: context.cs.surface,
                border: Border(
                  top: BorderSide(
                    color: context.cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: AppButton(
                label: context.translate(LanguageLabelKeys.saveSettings),
                height: 52,
                isLoading: isLoading,
                onPressed: () => _save(context, state),
              ),
            );
          },
        );
      },
    );
  }

  void _save(BuildContext context, NotificationSettingsLoaded state) {
    final categories = state.notificationSettings.data ?? [];
    final preferences = <Events>[
      for (final category in categories) ...?category.events,
    ];

    context.read<NotificationSettingsSaveCubit>().saveNotificationSettings(
      preferences: preferences,
    );
  }
}
