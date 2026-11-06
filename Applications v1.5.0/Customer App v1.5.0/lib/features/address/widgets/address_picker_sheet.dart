import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/cubit/delete_address_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/address/widgets/add_new_address_button.dart';
import 'package:customer/features/address/widgets/address_actions.dart';
import 'package:customer/features/address/widgets/address_card.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reusable saved-address picker bottom sheet.
///
/// Used by the checkout screen and the order return flow. Besides selecting an
/// address it also supports adding a new one and editing/deleting existing
/// ones. Expects an [AddressCubit] to be provided above it; it supplies its own
/// [DeleteAddressCubit] internally so callers don't need to.
class AddressPickerSheet extends StatelessWidget {
  const AddressPickerSheet({
    super.key,
    required this.selectedId,
    required this.onSelect,
    required this.onAddNew,
  });

  final String? selectedId;
  final ValueChanged<AddressData> onSelect;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeleteAddressCubit(),
      child: BlocListener<DeleteAddressCubit, DeleteAddressState>(
        listener: (context, state) {
          if (state is DeleteAddressSuccess) {
            context.read<AddressCubit>().removeLocally(state.id);
          } else if (state is DeleteAddressError) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : context.screenHeight * 0.6;
            return Container(
              height: maxHeight * 0.8,
              decoration: AppDecorations.bottomSheet(
                color: context.cs.surfaceContainer,
                borderRadius: AppRadius.top20,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: context.bottomSafePadding,
                ),
                child: Column(
                  children: [
                    AppSpacing.h8,
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: AppDecorations.dragHandle(
                          color: context.cs.outline.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingS,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: AppText(
                          context.translate(LanguageLabelKeys.selectAddress),
                          style: context.tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingL,
                        0,
                      ),
                      child: AddNewAddressButton(onTap: onAddNew),
                    ),
                    Expanded(
                      child:
                          BlocBuilder<
                            AddressCubit,
                            PaginationState<AddressData>
                          >(
                            builder: (ctx, state) {
                              if (state is PaginationLoading<AddressData>) {
                                return const LoadingWidget();
                              }
                              if (state is PaginationError<AddressData>) {
                                return Center(child: AppText(state.message));
                              }
                              if (state is PaginationLoaded<AddressData>) {
                                if (state.data.isEmpty) {
                                  return EmptyStateWidget(
                                    imagePath: AssetsConstants.noAddressFound,
                                    title: context.translate(
                                      LanguageLabelKeys.noAddressesFound,
                                    ),
                                    subtitle: context.translate(
                                      LanguageLabelKeys.addAddressPrompt,
                                    ),
                                    onRetry: onAddNew,
                                    retryLabel: context.translate(
                                      LanguageLabelKeys.addNewAddress,
                                    ),
                                  );
                                }
                                return SlideAnimationScope(
                                  builder: (_, animationController) =>
                                      ListView.separated(
                                        padding:
                                            const EdgeInsetsDirectional.all(
                                              ThemeConstants.paddingL,
                                            ),
                                        itemCount: state.data.length,
                                        separatorBuilder: (_, _) =>
                                            AppSpacing.h8,
                                        itemBuilder: (_, i) => SlideAnimation(
                                          position: i,
                                          itemCount: state.data.length,
                                          slideDirection:
                                              SlideDirection.fromBottom,
                                          animationController:
                                              animationController,
                                          child: AddressCard(
                                            address: state.data[i],
                                            isSelected:
                                                state.data[i].id == selectedId,
                                            onTap: () =>
                                                onSelect(state.data[i]),
                                            onEdit: () => openAddressEditor(
                                              ctx,
                                              address: state.data[i],
                                            ),
                                            onDelete: () =>
                                                confirmDeleteAddress(
                                                  ctx,
                                                  state.data[i],
                                                ),
                                          ),
                                        ),
                                      ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
