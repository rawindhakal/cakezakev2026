import 'package:customer/commons/widgets/app_radio_option_tile.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Item count above which [SearchablePickerList] grows a search field — a
/// handful of items reads fine as a plain list.
const int _searchThreshold = 8;

/// Loading placeholder for picker bottom sheets.
class PickerLoadingView extends StatelessWidget {
  const PickerLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.symmetric(
      vertical: ThemeConstants.paddingXXL,
    ),
    child: LoadingWidget(),
  );
}

/// "Nothing found" line for picker bottom sheets.
class PickerEmptyView extends StatelessWidget {
  final String message;
  const PickerEmptyView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingL,
      ),
      child: AppText(
        message,
        style: context.tt.bodySmall?.copyWith(
          color: context.cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Error message + retry button for picker bottom sheets. Falls back to
/// [fallbackMessage] when [message] is empty.
class PickerErrorView extends StatelessWidget {
  final String message;
  final String fallbackMessage;
  final VoidCallback onRetry;

  const PickerErrorView({
    super.key,
    required this.message,
    required this.fallbackMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingL,
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          AppSvgIcon(
            AssetsConstants.locationOffIcon,
            size: ThemeConstants.iconL,
            color: context.cs.error,
          ),
          AppSpacing.h8,
          AppText(
            message.isNotEmpty ? message : fallbackMessage,
            textAlign: .center,
            style: context.tt.bodySmall?.copyWith(color: context.cs.error),
          ),
          AppSpacing.h8,
          TextButton.icon(
            onPressed: onRetry,
            icon: AppSvgIcon(
              AssetsConstants.refreshIcon,
              size: ThemeConstants.iconS,
              color: context.cs.primary,
            ),
            label: AppText(context.translate(LanguageLabelKeys.retry)),
          ),
        ],
      ),
    );
  }
}

/// Single-select, optionally searchable radio list used by the state/region
/// and delivery-zone picker sheets. Pops the sheet with the chosen item.
class SearchablePickerList<T> extends StatefulWidget {
  final List<T> items;
  final int? Function(T item) idOf;
  final String? Function(T item) nameOf;
  final int? selectedId;
  final String emptyMessage;

  const SearchablePickerList({
    super.key,
    required this.items,
    required this.idOf,
    required this.nameOf,
    required this.emptyMessage,
    this.selectedId,
  });

  @override
  State<SearchablePickerList<T>> createState() =>
      _SearchablePickerListState<T>();
}

class _SearchablePickerListState<T> extends State<SearchablePickerList<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return PickerEmptyView(message: widget.emptyMessage);

    final showSearch = items.length > _searchThreshold;
    final filtered = _query.isEmpty
        ? items
        : items
              .where(
                (e) => (widget.nameOf(e) ?? '').toLowerCase().contains(_query),
              )
              .toList();

    return Column(
      mainAxisSize: .min,
      children: [
        if (showSearch) ...[
          AppTextField(
            controller: _searchController,
            hintText: context.translate(LanguageLabelKeys.search),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ThemeConstants.paddingL,
                end: ThemeConstants.paddingS,
              ),
              child: AppSvgIcon(
                AssetsConstants.searchIcon,
                size: ThemeConstants.iconS,
                color: context.cs.onSurfaceVariant,
                fit: BoxFit.scaleDown,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            // No `border` override — the default outline set is what makes the
            // field visible against the sheet's surface-coloured background.
            contentPadding: const EdgeInsetsDirectional.symmetric(
              vertical: ThemeConstants.paddingS,
            ),
          ),
          AppSpacing.h12,
        ],
        if (filtered.isEmpty)
          PickerEmptyView(message: widget.emptyMessage)
        else
          Flexible(
            child: RadioGroup<int?>(
              groupValue: widget.selectedId,
              onChanged: (id) {
                final item = filtered.firstWhere(
                  (e) => widget.idOf(e) == id,
                  orElse: () => filtered.first,
                );
                AppNavigator.pop(context, item);
              },
              child: SlideAnimationScope(
                builder: (context, animationController) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final id = widget.idOf(item);
                    return SlideAnimation(
                      position: index,
                      itemCount: filtered.length,
                      slideDirection: SlideDirection.fromBottom,
                      animationController: animationController,
                      child: AppRadioOptionTile<int?>(
                        value: id,
                        title: widget.nameOf(item) ?? '',
                        selected: widget.selectedId == id,
                        // Selection reads from the radio and the tile border
                        // alone — icon and label keep the normal text colour.
                        highlightSelectedColor: false,
                        margin: const EdgeInsetsDirectional.only(bottom: 2),
                        leading: AppSvgIcon(
                          AssetsConstants.addressIcon,
                          size: ThemeConstants.iconS,
                          color: context.cs.onSurface,
                        ),
                        onTap: () => AppNavigator.pop(context, item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
