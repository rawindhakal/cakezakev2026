import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/cubit/delete_address_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/address/widgets/add_new_address_button.dart';
import 'package:customer/features/address/widgets/address_actions.dart';
import 'package:customer/features/address/widgets/address_card.dart';
import 'package:customer/features/address/widgets/address_list_skeleton_loader.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/sticky_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/constants/theme_constants.dart';

typedef AddressPaginationState = PaginationState<AddressData>;
typedef AddressLoaded = PaginationLoaded<AddressData>;
typedef AddressError = PaginationError<AddressData>;
typedef AddressLoading = PaginationLoading<AddressData>;

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<AddressCubit>().fetchMore(),
  );

  @override
  void initState() {
    super.initState();
    context.read<AddressCubit>().fetchInitial();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goToAdd() => openAddressEditor(context);

  void _goToEdit(AddressData address) =>
      openAddressEditor(context, address: address);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<AddressCubit>().fetchInitial();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return BlocListener<DeleteAddressCubit, DeleteAddressState>(
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
          child: AppScaffold(
            applyBottomInset: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: CustomAppBar(
              title: context.translate(LanguageLabelKeys.myAddresses),
              scrollController: _pager.controller,
              hideShadowAfter: StickyBar.showAfter,
            ),
            // Offline replaces the body only, so the app bar's back button
            // keeps working.
            body: isOffline
                ? const AppNoInternetView()
                : BlocBuilder<AddressCubit, AddressPaginationState>(
                    builder: (context, state) {
                      if (state is AddressLoaded && state.data.isNotEmpty) {
                        return _buildList(context, state);
                      }
                      // Non-list states keep the add button fixed on top.
                      return Column(
                        children: [
                          _buildAddButton(),
                          Expanded(child: _buildStateBody(context, state)),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton() => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingL,
      ThemeConstants.paddingS,
    ),
    child: AddNewAddressButton(onTap: _goToAdd),
  );

  Widget _buildStateBody(BuildContext context, AddressPaginationState state) {
    if (state is AddressLoading) return const AddressListSkeletonLoader();
    if (state is AddressError) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noAddressFound,
        title: state.message,
        subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
        onRetry: () => context.read<AddressCubit>().refresh(),
      );
    }
    if (state is AddressLoaded) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noAddressFound,
        title: context.translate(LanguageLabelKeys.noAddressesFound),
        subtitle: context.translate(LanguageLabelKeys.addAddressPrompt),
      );
    }
    return AppSpacing.shrink;
  }

  Widget _buildList(BuildContext context, AddressLoaded state) {
    final list = RefreshIndicator(
      color: context.cs.primary,
      onRefresh: () async => context.read<AddressCubit>().refresh(),
      child: _pager.attach(
        ListView.builder(
          controller: _pager.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            0,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL + context.bottomSafePadding,
          ),
          // +1 for the add button at index 0.
          itemCount: state.data.length + 1 + (state.isFetchingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: ThemeConstants.paddingM,
                  bottom: ThemeConstants.paddingS,
                ),
                child: AddNewAddressButton(onTap: _goToAdd),
              );
            }
            final itemIndex = index - 1;
            if (itemIndex == state.data.length) {
              return PaginatedListFooter(
                isLoadingMore: state.isFetchingMore,
                hasMore: state.hasMore,
                skeletonBuilder: (_) => const AddressListSkeletonLoader(
                  itemCount: 1,
                  shrinkWrap: true,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: ThemeConstants.paddingS,
              ),
              child: AddressCard(
                address: state.data[itemIndex],
                onEdit: () => _goToEdit(state.data[itemIndex]),
                onDelete: () =>
                    confirmDeleteAddress(context, state.data[itemIndex]),
              ),
            );
          },
        ),
      ),
    );

    return Stack(
      children: [
        list,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: StickyBar(
            controller: _pager.controller,
            label: context.translate(LanguageLabelKeys.addNewAddress),
            iconAsset: AssetsConstants.addIcon,
            onTap: _goToAdd,
            trailing: Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                color: context.cs.onSurfaceVariant,
                size: ThemeConstants.iconM,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
