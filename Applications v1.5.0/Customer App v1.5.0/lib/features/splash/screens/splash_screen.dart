import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/utils/force_update_helper.dart';
import 'package:customer/commons/widgets/force_update_dialog.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/cubit/language_cubit.dart';
import 'package:customer/core/localization/cubit/localization_cubit.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/features/splash/widgets/ultra_loader.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  AppSettingsData? _pendingForceUpdateData;
  bool _dialogShowing = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendingForceUpdateData != null &&
        !_dialogShowing &&
        mounted) {
      _checkAndHandleUpdate(_pendingForceUpdateData!);
    }
  }

  void _navigateToMaintenance(String? remark) {
    if (!mounted || _navigated) return;
    _navigated = true;
    AppNavigator.pushReplacementNamed(
      context,
      RouteNames.maintenance,
      arguments: remark,
    );
    AppNavigator.markReady();
  }

  void _navigate() {
    if (!mounted || _navigated) return;
    final settingsState = context.read<SettingsCubit>().state;
    if (settingsState is! SettingsLoaded) return;
    final data = settingsState.settings.data;
    if (data?.appModeCustomer == '1') {
      _navigateToMaintenance(data?.appModeCustomerRemark);
      return;
    }
    _pendingForceUpdateData = null;
    if (!mounted) return;
    _navigated = true;
    if (!SettingsHiveBox.instance.onboardingSeen) {
      AppNavigator.pushReplacementNamed(context, RouteNames.onboarding);
    } else if (!SettingsHiveBox.instance.hasLocation) {
      AppNavigator.pushReplacementNamed(context, RouteNames.locationRequired);
    } else {
      AppNavigator.pushReplacementNamed(context, RouteNames.main);
    }
    AppNavigator.markReady();
  }

  Future<void> _checkAndHandleUpdate(AppSettingsData data) async {
    final status = await ForceUpdateHelper.getStatus(data);

    if (!mounted) return;

    if (status == UpdateStatus.none) {
      _pendingForceUpdateData = null;
      _navigate();
      return;
    }

    _pendingForceUpdateData = data;
    _dialogShowing = true;

    await ForceUpdateDialog.show(
      context: context,
      data: data,
      status: status,
      onContinue: () {
        _dialogShowing = false;
        _pendingForceUpdateData = null;
        _loadLanguages();
      },
    );

    _dialogShowing = false;
  }

  void _loadLanguages() {
    if (mounted) context.read<LanguageCubit>().loadLanguages();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: context.cs.primary,
      body: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listener: (context, state) async {
              final localizationCubit = context.read<LocalizationCubit>();
              if (state is SettingsLoaded) {
                final data = state.settings.data;
                if (data != null) {
                  if (data.appModeCustomer == '1') {
                    _navigateToMaintenance(data.appModeCustomerRemark);
                    return;
                  }
                  await _checkAndHandleUpdate(data);
                } else {
                  _loadLanguages();
                }
              }
              if (state is SettingsError) {
                localizationCubit.loadFromCache();
              }
            },
          ),
          BlocListener<ConnectivityCubit, ConnectivityState>(
            listener: (context, state) {
              if (state is ConnectivityConnected) {
                final settingsState = context.read<SettingsCubit>().state;
                if (settingsState is! SettingsLoaded) {
                  context.read<SettingsCubit>().loadSettings();
                }
              }
            },
          ),
          BlocListener<LanguageCubit, LanguageState>(
            listener: (context, state) {
              if (state is LanguageLoaded) {
                final id = state.selectedId ?? '';
                if (id.isNotEmpty) {
                  context.read<LocalizationCubit>().loadForLanguage(id);
                } else {
                  _navigate();
                }
              }
              if (state is LanguageError) {
                context.read<LocalizationCubit>().loadFromCache();
              }
            },
          ),
          BlocListener<LocalizationCubit, LocalizationState>(
            listener: (context, state) {
              if (state is LocalizationLoaded || state is LocalizationError) {
                _navigate();
              }
            },
          ),
        ],
        child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
          builder: (context, connectivityState) {
            return Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: AppSvgIcon(
                    AssetsConstants.splashLogo,
                    size: context.screenWidth * 0.40,
                  ),
                ),
                Align(
                  alignment: const AlignmentDirectional(0, 0.75),
                  child: UltraLoader(),
                ),
                // View, not FullScreen — this already sits inside the splash's
                // own AppScaffold, so a second scaffold here would nest.
                if (connectivityState is ConnectivityDisconnected)
                  const Positioned.fill(child: AppNoInternetView()),
              ],
            );
          },
        ),
      ),
    );
  }
}
