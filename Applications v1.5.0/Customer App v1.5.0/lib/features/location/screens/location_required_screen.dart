import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/address/widgets/location_permission_dialog.dart';
import 'package:customer/features/location/cubit/user_location_cubit.dart';
import 'package:customer/features/location/screens/location_search_screen.dart';
import 'package:customer/features/location/widgets/location_required_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Full-screen "set your location" gate shown before entering [RouteNames.main]
/// whenever [SettingsHiveBox.hasLocation] is false (post-onboarding, post-login, etc).
/// Replaces the current route once location is set.
class LocationRequiredScreen extends StatelessWidget {
  const LocationRequiredScreen({super.key});

  Future<void> _openSearch(BuildContext context) async {
    final saved = await AppNavigator.push<bool>(
      context,
      const LocationSearchScreen(),
    );
    if (!context.mounted) return;
    if (saved == true) _goToMainIfLocationSet(context);
  }

  void _goToMainIfLocationSet(BuildContext context) {
    if (SettingsHiveBox.instance.hasLocation) {
      AppNavigator.pushReplacementNamed(context, RouteNames.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserLocationCubit(),
      child: BlocConsumer<UserLocationCubit, UserLocationState>(
        listener: (context, state) async {
          if (state is UserLocationDetected) {
            if (SettingsHiveBox.instance.hasLocation) {
              AppNavigator.pushReplacementNamed(context, RouteNames.main);
            }
          } else if (state is UserLocationPermissionDenied) {
            await showLocationPermissionDialog(context);
            if (context.mounted) {
              context.read<UserLocationCubit>().reset();
            }
          } else if (state is UserLocationError) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
            context.read<UserLocationCubit>().reset();
          }
        },
        builder: (context, state) {
          return LocationRequiredView(
            isSettingLocation: state is UserLocationDetecting,
            onSetLocation: () =>
                context.read<UserLocationCubit>().detectCurrentLocation(),
            onSearchManually: () => _openSearch(context),
            onLocationConfirmed: () => _goToMainIfLocationSet(context),
          );
        },
      ),
    );
  }
}
