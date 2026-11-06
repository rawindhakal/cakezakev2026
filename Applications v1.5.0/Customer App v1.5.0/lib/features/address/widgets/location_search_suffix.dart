import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/features/address/cubit/place_autocomplete_cubit.dart';

class LocationSearchSuffix extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const LocationSearchSuffix({
    super.key,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaceAutocompleteCubit, PlaceAutocompleteState>(
      builder: (context, state) {
        if (state is PlaceAutocompleteLoading) return _clearBtn(context);
        if (controller.text.isNotEmpty) return _clearBtn(context);
        return AppSpacing.shrink;
      },
    );
  }

  Widget _clearBtn(BuildContext context) {
    return IconButton(
      icon: const AppSvgIcon(
        AssetsConstants.closeIcon,
        size: ThemeConstants.iconS,
      ),
      color: context.cs.onSurfaceVariant,
      onPressed: onClear,
    );
  }
}
