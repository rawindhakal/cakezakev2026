import 'dart:io';
import 'package:deliveryboy/commons/widgets/profile_avatar_picker.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Centered avatar picker for edit profile.
class EditProfileStepIndicator extends StatelessWidget {
  final int currentStep;
  final File? profileImage;
  final String? profileImageUrl;
  final ValueChanged<File> onProfileImagePicked;

  const EditProfileStepIndicator({
    super.key,
    required this.currentStep,
    required this.profileImage,
    required this.profileImageUrl,
    required this.onProfileImagePicked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingXL,
        vertical: ThemeConstants.paddingL,
      ),
      child: Center(
        child: ProfileAvatarPicker(
          image: profileImage,
          imageUrl: profileImageUrl,
          onPicked: onProfileImagePicked,
        ),
      ),
    );
  }
}
