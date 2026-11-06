import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Read-only "select" field — shows [value] with a trailing chevron and hands
/// tapping to [onTap], which is expected to open a picker sheet. Shared chrome
/// behind the country / delivery-zone dropdowns; pass a null [onTap] to make
/// the field inert (nothing to pick yet) and [isLoading] to swap the chevron
/// for a spinner while the options are being fetched.
class AppSelectField extends StatefulWidget {
  final String? value;
  final String? labelText;
  final String hintText;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isRequired;
  final String? Function(String?)? validator;

  const AppSelectField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onTap,
    this.labelText,
    this.isLoading = false,
    this.isRequired = false,
    this.validator,
  });

  @override
  State<AppSelectField> createState() => _AppSelectFieldState();
}

class _AppSelectFieldState extends State<AppSelectField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void didUpdateWidget(covariant AppSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.value ?? '';
    if (_controller.text != text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != text) _controller.text = text;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      labelText: widget.labelText,
      hintText: widget.hintText,
      isRequired: widget.isRequired,
      readOnly: true,
      validator: widget.validator,
      // Decorative chevron/spinner — excluded so it doesn't feed
      // InputDecorator's suffix sibling-merge group (Flutter 3.47 semantics
      // '!newChildren.any(child == this)' assertion).
      suffixIcon: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: ThemeConstants.paddingL,
            start: ThemeConstants.paddingS,
          ),
          child: widget.isLoading
              ? const LoadingWidget(size: ThemeConstants.loaderSizeS)
              : AppSvgIcon(
                  AssetsConstants.arrowDownIcon,
                  color: context.cs.onSurfaceVariant,
                  size: ThemeConstants.iconS,
                ),
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      onTap: widget.onTap,
    );
  }
}
