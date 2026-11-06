import 'package:customer/commons/widgets/app_confirm_dialog.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/cubit/delete_address_cubit.dart';
import 'package:customer/features/address/cubit/geocoding_cubit.dart';
import 'package:customer/features/address/cubit/place_autocomplete_cubit.dart';
import 'package:customer/features/address/cubit/place_details_cubit.dart';
import 'package:customer/features/address/cubit/save_address_cubit.dart';
import 'package:customer/features/address/cubit/zone_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/address/screens/location_picker_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared add/edit/delete actions for saved addresses so the listing screen
/// and the address picker sheet drive the exact same flows.

/// Opens the add ([address] == null) or edit address flow.
///
/// Reuses the existing [AddressCubit] from [context] (passed down via
/// [BlocProvider.value]) so the underlying list stays in sync after saving.
void openAddressEditor(
  BuildContext context, {
  AddressData? address,
  AddressCubit? addressCubit,
}) {
  addressCubit ??= context.read<AddressCubit>();
  AppNavigator.push(
    context,
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: addressCubit),
        BlocProvider(create: (_) => SaveAddressCubit()),
        BlocProvider(create: (_) => GeocodingCubit()),
        BlocProvider(create: (_) => PlaceAutocompleteCubit()),
        BlocProvider(create: (_) => PlaceDetailsCubit()),
        BlocProvider(create: (_) => ZoneCubit()),
      ],
      child: LocationPickerScreen(address: address),
    ),
  );
}

/// Shows a bottom sheet with Edit/Delete options for a saved address.
/// Tapping an option closes the sheet then invokes the same [onEdit] /
/// [onDelete] callbacks the caller already wires up — flow unchanged.
void showAddressOptionsSheet(
  BuildContext context, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.selectOption),
    backgroundColor: context.cs.surfaceContainer,
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingXL,
      ThemeConstants.paddingL,
      ThemeConstants.paddingL,
    ),
    builder: (sheetContext) => Container(
      decoration: AppDecorations.box(
        color: sheetContext.cs.surface,
        borderRadius: AppRadius.r12,
      ),
      clipBehavior: Clip.antiAlias,
      child: SlideAnimationList(
        crossAxisAlignment: .stretch,
        children: [
          _AddressOptionTile(
            icon: AssetsConstants.deleteIcon,
            label: sheetContext.translate(LanguageLabelKeys.deleteAddress),
            onTap: () {
              AppNavigator.pop(sheetContext);
              onDelete();
            },
          ),
          Divider(height: 1, color: sheetContext.cs.outline),
          _AddressOptionTile(
            icon: AssetsConstants.editIcon,
            label: sheetContext.translate(LanguageLabelKeys.editAddress),
            onTap: () {
              AppNavigator.pop(sheetContext);
              onEdit();
            },
          ),
        ],
      ),
    ),
  );
}

class _AddressOptionTile extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _AddressOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: ThemeConstants.paddingM,
        ),
        child: Row(
          children: [
            AppSvgIcon(
              icon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurfaceVariant,
            ),
            AppSpacing.w12,
            Expanded(
              child: AppText(
                label,
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.cs.onSurface,
                ),
              ),
            ),
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                size: ThemeConstants.iconS,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the delete-address confirmation dialog. On confirm it triggers the
/// [DeleteAddressCubit] which must be provided above [context]; the caller is
/// responsible for listening to the result (remove from list / show error).
void confirmDeleteAddress(BuildContext context, AddressData address) {
  showDialog(
    context: context,
    builder: (_) => AppConfirmDialog(
      icon: AppConfirmDialogIcon.danger,
      isDestructive: true,
      title: context.translate(LanguageLabelKeys.deleteAddress),
      message: context.translate(LanguageLabelKeys.deleteAddressConfirm),
      cancelLabel: context.translate(LanguageLabelKeys.cancel),
      confirmLabel: context.translate(LanguageLabelKeys.delete),
      onCancel: () => AppNavigator.pop(context),
      onConfirm: () {
        AppNavigator.pop(context);
        context.read<DeleteAddressCubit>().deleteAddress(id: address.id!);
      },
    ),
  );
}
