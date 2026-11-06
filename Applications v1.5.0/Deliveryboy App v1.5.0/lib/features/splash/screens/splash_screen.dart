import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/commons/utils/force_update_helper.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/localization_cubit.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/features/splash/widget/splash_visual.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/routes/route_names.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';

/// App entry screen — loads settings/language and routes to login or main.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  AppSettingsData? _pendingForceUpdateData;
  bool _dialogShowing = false;

  // Three separate BlocListeners can each land on a navigate call, and the
  // localization one in particular fires on both Loaded and Error — a settings
  // reload (reconnect on the splash screen) re-runs that whole chain and would
  // pushReplacement a second time, tearing down the screen that just replaced
  // splash. Splash navigates exactly once per app launch.
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
    _navigated = true;
    _pendingForceUpdateData = null;
    if (AuthHiveBox.instance.isLoggedIn) {
      AppNavigator.pushReplacementNamed(context, RouteNames.main);
    } else {
      AppNavigator.pushReplacementNamed(context, RouteNames.login);
    }
    AppNavigator.markReady();
  }

  Future<void> _checkAndHandleUpdate(AppSettingsData data) async {
    final status = await ForceUpdateHelper.getStatus(data);

    if (!mounted) return;

    if (status == UpdateStatus.none) {
      _pendingForceUpdateData = null;
      _loadLanguages();
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
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          final settingsState = context.read<SettingsCubit>().state;
          if (settingsState is! SettingsLoaded) {
            context.read<SettingsCubit>().loadSettings();
          }
        }
      },
      builder: (context, connectivityState) {
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
                      if (data.appModeDeliveryBoy == '1') {
                        _navigateToMaintenance(data.appModeDeliveryBoyRemark);
                        return;
                      }
                      await _checkAndHandleUpdate(data);
                    } else {
                      _loadLanguages();
                    }
                    return;
                  }
                  if (state is SettingsError) {
                    localizationCubit.loadFromCache();
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
                      context.read<LocalizationCubit>().loadFromCache();
                    }
                  }
                  if (state is LanguageError) {
                    context.read<LocalizationCubit>().loadFromCache();
                  }
                },
              ),
              BlocListener<LocalizationCubit, LocalizationState>(
                listener: (context, state) {
                  if (state is LocalizationLoaded ||
                      state is LocalizationError) {
                    _navigate();
                  }
                },
              ),
            ],
            child: SplashVisual(
              showNoInternet: connectivityState is ConnectivityDisconnected,
            ),
          ),
        );
      },
    );
  }
}
