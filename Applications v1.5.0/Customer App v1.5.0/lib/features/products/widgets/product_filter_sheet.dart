import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/models/filter_model.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_filter_skeleton_loader.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';

void showProductFilterSheet(
  BuildContext context,
  PaginationLoaded<ProductDataModel> state,
) {
  final cubit = context.read<ProductCubit>();
  final filterCubit = context.read<FilterCubit>();
  showAppBottomSheet(
    context,
    showDragHandle: false,
    padding: null,
    builder: (sheetContext) => BlocProvider.value(
      value: filterCubit,
      child: _ProductFilterSheet(
        cubit: cubit,
        onApply: (minPrice, maxPrice, brandIds, attributeValueIds) {
          cubit.applyProductFilters(
            minPrice: minPrice,
            maxPrice: maxPrice,
            brandIds: brandIds,
            attributeValueIds: attributeValueIds,
          );
          AppNavigator.pop(sheetContext);
        },
        onClear: () {
          cubit.clearFilters();
          AppNavigator.pop(sheetContext);
        },
      ),
    ),
  );
}

/// One left-rail entry — either the brand group, the price group, or an
/// attribute group (e.g. "Pack Type", "Flavour").
class _FilterGroup {
  final String label;
  final int? attributeIndex; // null for brand/price groups
  final bool isPrice;
  final bool isBrand;
  const _FilterGroup({
    required this.label,
    this.attributeIndex,
    this.isPrice = false,
    this.isBrand = false,
  });
}

class _ProductFilterSheet extends StatefulWidget {
  final ProductCubit cubit;
  final void Function(
    double minPrice,
    double maxPrice,
    Set<String> brandIds,
    Set<String> attributeValueIds,
  )
  onApply;
  final VoidCallback onClear;

  const _ProductFilterSheet({
    required this.cubit,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<_ProductFilterSheet>
    with TickerProviderStateMixin {
  late RangeValues _priceRange;
  late Set<String> _selectedBrandIds;
  late Set<String> _selectedAttributeValueIds;
  late List<_FilterGroup> _groups;
  late List<ProductFilterBrand> _brands;
  late List<Attributes> _attributes;
  late double _totalMinPrice;
  late double _totalMaxPrice;
  bool _appliedFilterData = false;
  late AnimationController _railAnimationController;
  late AnimationController _contentAnimationController;
  int _activeGroup = 0;
  static const double _kRailItemHeight = 56;
  static const double _kRailVerticalPadding = ThemeConstants.paddingS;

  bool get _hasPriceRange => _totalMaxPrice > _totalMinPrice;

  @override
  void initState() {
    super.initState();
    final filters = widget.cubit.currentFilters;
    _brands = widget.cubit.brands;
    _attributes = const [];
    _totalMinPrice = widget.cubit.totalMinPrice;
    _totalMaxPrice = widget.cubit.totalMaxPrice;
    _priceRange = RangeValues(
      (filters.minPrice ?? _totalMinPrice).clamp(
        _totalMinPrice,
        _totalMaxPrice,
      ),
      (filters.maxPrice ?? _totalMaxPrice).clamp(
        _totalMinPrice,
        _totalMaxPrice,
      ),
    );
    _selectedBrandIds = {...filters.brandIds};
    _selectedAttributeValueIds = {...filters.attributeValueIds};
    _rebuildGroups();

    _railAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // FilterCubit may still be loading (brands/attributes/price range) when
    // the sheet is opened — pick up its data reactively once it lands
    // instead of freezing on whatever snapshot existed at open-time.
    final filterState = context.read<FilterCubit>().state;
    if (filterState is FilterLoaded) _applyFilterData(filterState.data);
  }

  void _rebuildGroups() {
    _groups = [
      if (_brands.isNotEmpty) const _FilterGroup(label: '', isBrand: true),
      for (var i = 0; i < _attributes.length; i++)
        if ((_attributes[i].values ?? []).isNotEmpty)
          _FilterGroup(label: _attributes[i].name ?? '', attributeIndex: i),
      if (_hasPriceRange) const _FilterGroup(label: '', isPrice: true),
    ];
    if (_activeGroup >= _groups.length) _activeGroup = 0;
  }

  void _applyFilterData(FilterModelData data) {
    final filters = widget.cubit.currentFilters;
    final hasActivePriceFilter =
        filters.minPrice != null || filters.maxPrice != null;
    final filterBrands = data.brands;
    final brands = (filterBrands != null && filterBrands.isNotEmpty)
        ? filterBrands
              .map(
                (b) => ProductFilterBrand(
                  id: b.id?.toString(),
                  name: b.name,
                  imageUrl: b.imageUrl,
                ),
              )
              .toList()
        : widget.cubit.brands;
    final attributes = data.attributes ?? const [];
    final hasFilterPriceRange =
        data.minPrice != null &&
        data.maxPrice != null &&
        data.maxPrice! > data.minPrice!;
    final totalMinPrice = hasFilterPriceRange
        ? data.minPrice!.toDouble()
        : widget.cubit.totalMinPrice;
    final totalMaxPrice = hasFilterPriceRange
        ? data.maxPrice!.toDouble()
        : widget.cubit.totalMaxPrice;

    setState(() {
      _brands = brands;
      _attributes = attributes;
      _totalMinPrice = totalMinPrice;
      _totalMaxPrice = totalMaxPrice;
      // Slider spans the response's full range; handles sit at the applied
      // bounds (e.g. a banner's max_price) — re-read from the filter, since
      // _priceRange was clamped to the narrower list-derived range.
      _priceRange = hasActivePriceFilter
          ? RangeValues(
              (filters.minPrice ?? totalMinPrice).clamp(
                totalMinPrice,
                totalMaxPrice,
              ),
              (filters.maxPrice ?? totalMaxPrice).clamp(
                totalMinPrice,
                totalMaxPrice,
              ),
            )
          : RangeValues(totalMinPrice, totalMaxPrice);
      _rebuildGroups();
      _appliedFilterData = true;
    });
  }

  @override
  void dispose() {
    _railAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  void _selectGroup(int i) {
    setState(() => _activeGroup = i);
    _contentAnimationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FilterCubit, FilterState>(
      listenWhen: (prev, next) => !_appliedFilterData && next is FilterLoaded,
      listener: (context, state) {
        if (state is FilterLoaded) _applyFilterData(state.data);
      },
      child: _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final filterState = context.watch<FilterCubit>().state;
    final isFilterDataLoading =
        !_appliedFilterData &&
        (filterState is FilterInitial || filterState is FilterLoading);
    return SizedBox(
      height: context.screenHeight * 0.78,
      child: Column(
        children: [
          AppSpacing.h10,
          Container(
            width: 40,
            height: 4,
            decoration: AppDecorations.dragHandle(color: context.cs.outline),
          ),
          AppSpacing.h12,
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
              ),
              child: AppText(
                context.translate(LanguageLabelKeys.filters),
                style: context.tt.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ),
          ),
          AppSpacing.h8,
          Divider(height: 1, color: context.cs.outlineVariant),
          Expanded(
            child: isFilterDataLoading
                ? const ProductFilterSkeletonLoader()
                : _groups.isEmpty
                ? Center(
                    child: AppText(
                      context.translate(LanguageLabelKeys.noFiltersAvailable),
                      style: context.tt.bodyMedium?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: .start,
                    children: [
                      // ── Left rail: filter categories ──
                      SizedBox(
                        width: 110,
                        child: SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.symmetric(
                            vertical: _kRailVerticalPadding,
                          ),
                          child: Stack(
                            children: [
                              // Sliding selection indicator — one shared
                              // background + accent bar that moves between
                              // items instead of each item toggling its own.
                              AnimatedPositionedDirectional(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                top: _activeGroup * _kRailItemHeight,
                                start: 0,
                                end: 0,
                                height: _kRailItemHeight,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: AppDecorations.box(
                                        gradient: LinearGradient(
                                          begin:
                                              AlignmentDirectional.centerStart,
                                          end: AlignmentDirectional.centerEnd,
                                          colors: [
                                            context.cs.primary.withValues(
                                              alpha: 0.02,
                                            ),
                                            context.cs.primary.withValues(
                                              alpha: 0.16,
                                            ),
                                          ],
                                        ),
                                        borderRadius:
                                            const BorderRadiusDirectional.only(
                                              topStart: Radius.circular(5),
                                              bottomStart: Radius.circular(5),
                                            ),
                                      ),
                                    ),
                                    PositionedDirectional(
                                      top: 0,
                                      bottom: 0,
                                      end: 0,
                                      child: Container(
                                        width: 3,
                                        decoration: AppDecorations.box(
                                          color: context.cs.primary,
                                          borderRadius:
                                              const BorderRadiusDirectional.only(
                                                topStart: Radius.circular(16),
                                                bottomStart: Radius.circular(
                                                  16,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  for (var i = 0; i < _groups.length; i++)
                                    Builder(
                                      builder: (context) {
                                        final group = _groups[i];
                                        final label = group.isBrand
                                            ? context.translate(
                                                LanguageLabelKeys.brand,
                                              )
                                            : group.isPrice
                                            ? context.translate(
                                                LanguageLabelKeys.priceRange,
                                              )
                                            : group.label;
                                        final selected = i == _activeGroup;
                                        final count = group.isBrand
                                            ? _selectedBrandIds.length
                                            : group.isPrice
                                            ? 0
                                            : (group.attributeIndex != null
                                                  ? (_attributes[group
                                                                    .attributeIndex!]
                                                                .values ??
                                                            [])
                                                        .where(
                                                          (
                                                            v,
                                                          ) => _selectedAttributeValueIds
                                                              .contains(
                                                                v.id?.toString() ??
                                                                    '',
                                                              ),
                                                        )
                                                        .length
                                                  : 0);
                                        return SlideAnimation(
                                          position: i,
                                          slideDirection:
                                              SlideDirection.fromBottom,
                                          itemCount: _groups.length,
                                          animationController:
                                              _railAnimationController,
                                          child: SizedBox(
                                            height: _kRailItemHeight,
                                            child: InkWell(
                                              onTap: () => _selectGroup(i),
                                              splashFactory:
                                                  NoSplash.splashFactory,
                                              splashColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsetsDirectional.symmetric(
                                                      horizontal: ThemeConstants
                                                          .paddingM,
                                                    ),
                                                child: Row(
                                                  spacing:
                                                      ThemeConstants.spaceXS,
                                                  children: [
                                                    Expanded(
                                                      child: AppText(
                                                        label,
                                                        style: context
                                                            .tt
                                                            .bodySmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  selected
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w500,
                                                              color: selected
                                                                  ? context
                                                                        .cs
                                                                        .primary
                                                                  : context
                                                                        .cs
                                                                        .onSurface,
                                                            ),
                                                      ),
                                                    ),
                                                    if (count > 0) ...[
                                                      Container(
                                                        padding:
                                                            const EdgeInsetsDirectional.symmetric(
                                                              horizontal:
                                                                  ThemeConstants
                                                                      .paddingXS,
                                                              vertical: 1,
                                                            ),
                                                        decoration:
                                                            AppDecorations.box(
                                                              color: context
                                                                  .cs
                                                                  .primary,
                                                              borderRadius:
                                                                  AppRadius.r20,
                                                            ),
                                                        child: AppText(
                                                          '$count',
                                                          style: context
                                                              .tt
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: context
                                                                    .cs
                                                                    .onPrimary,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: context.cs.outlineVariant,
                      ),
                      // ── Right pane: options for the active category ──
                      Expanded(
                        child: _buildGroupContent(
                          context,
                          _groups[_activeGroup],
                        ),
                      ),
                    ],
                  ),
          ),
          _BottomActions(onClear: widget.onClear, onApply: _apply),
        ],
      ),
    );
  }

  void _apply() => widget.onApply(
    _priceRange.start,
    _priceRange.end,
    _selectedBrandIds,
    _selectedAttributeValueIds,
  );

  Widget _buildGroupContent(BuildContext context, _FilterGroup group) {
    if (group.isPrice) return _buildPriceContent(context);
    if (group.isBrand) return _buildBrandContent(context);
    return _buildAttributeContent(context, _attributes[group.attributeIndex!]);
  }

  Widget _buildBrandContent(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingXS,
      ),
      itemCount: _brands.length,
      itemBuilder: (context, i) {
        final brand = _brands[i];
        final id = brand.id ?? '';
        final selected = _selectedBrandIds.contains(id);
        return SlideAnimation(
          position: i,
          slideDirection: SlideDirection.fromBottom,
          itemCount: _brands.length,
          animationController: _contentAnimationController,
          child: Column(
            children: [
              _FilterOptionTile(
                selected: selected,
                label: brand.name ?? '',
                leading: (brand.imageUrl ?? '').isNotEmpty
                    ? ClipRRect(
                        borderRadius: AppRadius.r6,
                        child: AppNetworkImage(
                          url: brand.imageUrl!,
                          width: 32,
                          height: 32,
                        ),
                      )
                    : null,
                onTap: () => setState(() {
                  if (selected) {
                    _selectedBrandIds.remove(id);
                  } else {
                    _selectedBrandIds.add(id);
                  }
                }),
              ),
              if (i < _brands.length - 1)
                Divider(height: 1, color: context.cs.outlineVariant),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttributeContent(BuildContext context, Attributes attribute) {
    final values = attribute.values ?? [];
    return ListView.builder(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingXS,
      ),
      itemCount: values.length,
      itemBuilder: (context, i) {
        final value = values[i];
        final id = value.id?.toString() ?? '';
        final selected = _selectedAttributeValueIds.contains(id);
        return SlideAnimation(
          position: i,
          slideDirection: SlideDirection.fromBottom,
          itemCount: values.length,
          animationController: _contentAnimationController,
          child: Column(
            children: [
              _FilterOptionTile(
                selected: selected,
                label: value.value ?? '',
                onTap: () => setState(() {
                  if (selected) {
                    _selectedAttributeValueIds.remove(id);
                  } else {
                    _selectedAttributeValueIds.add(id);
                  }
                }),
              ),
              if (i < values.length - 1)
                Divider(height: 1, color: context.cs.outlineVariant),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.priceRange),
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.cs.onSurface,
            ),
          ),
          RangeSlider(
            values: _priceRange,
            min: _totalMinPrice,
            max: _totalMaxPrice,
            activeColor: context.cs.primary,
            labels: RangeLabels(
              _priceRange.start.toStringAsFixed(0),
              _priceRange.end.toStringAsFixed(0),
            ),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              AppText(
                _priceRange.start.toStringAsFixed(0),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              AppText(
                _priceRange.end.toStringAsFixed(0),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? leading;
  final VoidCallback onTap;

  const _FilterOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingM,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, AppSpacing.w10],
            Expanded(
              child: AppText(
                label,
                style: context.tt.bodySmall?.copyWith(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: context.cs.onSurface,
                ),
              ),
            ),
            AppSpacing.w8,
            Container(
              width: 20,
              height: 20,
              decoration: AppDecorations.box(
                borderRadius: AppRadius.r4,
                border: Border.all(
                  color: selected ? context.cs.primary : context.cs.outline,
                  width: 1.5,
                ),
                color: selected ? context.cs.primary : Colors.transparent,
              ),
              child: selected
                  ? AppSvgIcon(
                      AssetsConstants.checkIcon,
                      size: ThemeConstants.iconXS,
                      color: context.cs.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onApply;

  const _BottomActions({required this.onClear, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        context.bottomSafePadding + ThemeConstants.paddingM,
      ),
      decoration: AppDecorations.bottomSheetFooter(
        color: context.cs.surface,
        borderColor: context.cs.outlineVariant,
      ),
      child: Row(
        spacing: ThemeConstants.spaceM,
        children: [
          Expanded(
            child: AppButton(
              label: context.translate(LanguageLabelKeys.clearAll),
              onPressed: onClear,
              height: 46,
              variant: AppButtonVariant.outline,
            ),
          ),
          Expanded(
            child: AppButton(
              label: context.translate(LanguageLabelKeys.apply),
              onPressed: onApply,
              height: 46,
            ),
          ),
        ],
      ),
    );
  }
}
