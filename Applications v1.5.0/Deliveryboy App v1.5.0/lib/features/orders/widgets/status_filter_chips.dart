import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../cubit/order_cubit.dart';
import '../cubit/ecommerce_order_cubit.dart';
import '../cubit/return_order_cubit.dart';
import '../models/order_model.dart';
import '../models/ecommerce_order_model.dart';
import '../models/order_status_model.dart';
import '../models/return_order_model.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'order_date_filter_row.dart';

/// Generic horizontal status chip bar shared by orders and return-orders screens.
class StatusFilterChips extends StatelessWidget {
  final List<OrderStatusData> statuses;
  final String? selectedId;
  final ValueChanged<String> onStatusChanged;
  final double height;

  const StatusFilterChips({
    super.key,
    required this.statuses,
    required this.selectedId,
    required this.onStatusChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.cs.surface,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ListView.separated(
          scrollDirection: .horizontal,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: 15,
            vertical: height > 44 ? 6 : 5,
          ),
          itemCount: statuses.length,
          separatorBuilder: (_, _) => AppSpacing.w8,
          itemBuilder: (context, index) {
            final entry = statuses[index];
            final isSelected = selectedId == entry.id;
            return ChoiceChip(
              showCheckmark: false,
              label: AppText(entry.statusName ?? ''),
              selected: isSelected,
              onSelected: (_) => onStatusChanged(entry.id ?? ''),
              selectedColor: context.cs.primary,
              backgroundColor: context.cs.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r25),
              labelStyle: context.tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? context.cs.onPrimary
                    : context.cs.onSurfaceVariant,
              ),
              side: BorderSide(
                color: isSelected ? context.cs.primary : context.cs.outline,
              ),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: ThemeConstants.paddingXS),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }
}

/// Shared status-chip bar for the Quick Order and Ecommerce Order tabs.
/// [isEcommerce] picks which cubit's [selectedStatus] drives the highlighted
/// chip — the two tabs share this one widget but track separate cubits, so
/// the selection must follow whichever tab is active.
class OrderStatusChips extends StatelessWidget {
  final ValueChanged<String> onStatusChanged;
  final bool isEcommerce;
  const OrderStatusChips({
    super.key,
    required this.onStatusChanged,
    this.isEcommerce = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderStatusListFilterCubit, OrderStatusListFilterState>(
      builder: (context, filterState) {
        if (filterState is! OrderStatusListFilterLoaded) {
          return ColoredBox(
            color: context.cs.surface,
            child: const SizedBox(
              height: 44,
              width: double.infinity,
            ),
          );
        }
        if (isEcommerce) {
          return BlocBuilder<
            EcommerceOrderCubit,
            PaginationState<EcommerceOrderDataModel>
          >(
            builder: (context, _) => StatusFilterChips(
              statuses: filterState.data,
              selectedId: context.read<EcommerceOrderCubit>().selectedStatus,
              onStatusChanged: onStatusChanged,
            ),
          );
        }
        return BlocBuilder<OrderCubit, PaginationState<OrderData>>(
          builder: (context, _) => StatusFilterChips(
            statuses: filterState.data,
            selectedId: context.read<OrderCubit>().selectedStatus,
            onStatusChanged: onStatusChanged,
          ),
        );
      },
    );
  }
}

class DateFilterActions extends StatelessWidget {
  final VoidCallback onPickDate;
  final VoidCallback onClear;
  const DateFilterActions({
    super.key,
    required this.onPickDate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderCubit, PaginationState<OrderData>>(
      builder: (context, _) {
        final cubit = context.read<OrderCubit>();
        final hasDate = cubit.startDate != null || cubit.endDate != null;
        return OrderDateFilterRow(
          hasDate: hasDate,
          hasActiveFilters: cubit.hasActiveFilters,
          dateTooltip: hasDate
              ? '${cubit.startDate} → ${cubit.endDate}'
              : context.translate(LanguageLabelKeys.dateRange),
          onPickDate: onPickDate,
          onClear: onClear,
        );
      },
    );
  }
}

class ReturnStatusChips extends StatelessWidget {
  final ValueChanged<String> onStatusChanged;
  const ReturnStatusChips({super.key, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      ReturnOrderStatusListFilterCubit,
      ReturnOrderStatusListFilterState
    >(
      builder: (context, filterState) {
        if (filterState is! ReturnOrderStatusListFilterLoaded) {
          return ColoredBox(
            color: context.cs.surface,
            child: SizedBox(
              height: context.screenHeight * 0.059,
              width: double.infinity,
            ),
          );
        }
        return BlocBuilder<
          ReturnOrderCubit,
          PaginationState<ReturnRequestData>
        >(
          builder: (context, _) => StatusFilterChips(
            statuses: filterState.data,
            selectedId: context.read<ReturnOrderCubit>().selectedStatus,
            onStatusChanged: onStatusChanged,
            height: context.screenHeight * 0.059,
          ),
        );
      },
    );
  }
}

class ReturnDateFilterActions extends StatelessWidget {
  final ReturnOrderCubit cubit;
  final VoidCallback onPickDate;
  final VoidCallback onClear;

  const ReturnDateFilterActions({
    super.key,
    required this.cubit,
    required this.onPickDate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReturnOrderCubit, PaginationState<ReturnRequestData>>(
      builder: (context, _) {
        final hasDate = cubit.startDate != null || cubit.endDate != null;
        return OrderDateFilterRow(
          hasDate: hasDate,
          hasActiveFilters: cubit.hasActiveFilters,
          dateTooltip: hasDate
              ? '${cubit.startDate} → ${cubit.endDate}'
              : context.translate(LanguageLabelKeys.dateRange),
          onPickDate: onPickDate,
          onClear: onClear,
        );
      },
    );
  }
}
