import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/features/address/cubit/save_address_cubit.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

class SaveButton extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onSubmit;

  const SaveButton({super.key, required this.isEdit, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<SaveAddressCubit>().state is SaveAddressLoading;
    return AppButton(
      label: isEdit
          ? context.translate(LanguageLabelKeys.updateAddress)
          : context.translate(LanguageLabelKeys.saveAddress),
      onPressed: isLoading ? null : onSubmit,
      isLoading: isLoading,
    );
  }
}
