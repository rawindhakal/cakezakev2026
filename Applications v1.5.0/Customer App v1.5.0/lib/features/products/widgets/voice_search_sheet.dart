import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum _VoiceStep { listening, notHeard, recognized }

/// Opens a step-wise voice search sheet: listening → recognized (or not
/// heard, with retry). Owns its own [stt.SpeechToText] session so the
/// caller only gets the final recognized query via [onResult].
Future<void> showVoiceSearchSheet(
  BuildContext context, {
  required ValueChanged<String> onResult,
}) {
  return showAppBottomSheet(
    context,
    isDismissible: true,
    builder: (sheetContext) => _VoiceSearchSheet(onResult: onResult),
  );
}

class _VoiceSearchSheet extends StatefulWidget {
  final ValueChanged<String> onResult;

  const _VoiceSearchSheet({required this.onResult});

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late final AnimationController _pulseController;

  _VoiceStep _step = _VoiceStep.listening;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_speech.isListening) _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    setState(() {
      _step = _VoiceStep.listening;
      _recognizedText = '';
    });
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if ((status == 'done' || status == 'notListening') &&
            _step == _VoiceStep.listening) {
          setState(() => _step = _VoiceStep.notHeard);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _step = _VoiceStep.notHeard);
      },
    );
    if (!available) {
      if (mounted) setState(() => _step = _VoiceStep.notHeard);
      return;
    }
    _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          if (text.isEmpty) {
            setState(() => _step = _VoiceStep.notHeard);
            return;
          }
          setState(() {
            _step = _VoiceStep.recognized;
            _recognizedText = text;
          });
          Future.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            widget.onResult(text);
            Navigator.of(context).pop();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Center(child: _buildStepContent(context)),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case _VoiceStep.listening:
        return SlideAnimationList(
          children: [
            AppText(
              context.translate(LanguageLabelKeys.voiceSearchListening),
              style: context.tt.titleMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.h24,
            _pulsingMic(context),
          ],
        );
      case _VoiceStep.notHeard:
        return SlideAnimationList(
          children: [
            AppText(
              context.translate(LanguageLabelKeys.voiceSearchNotHeard),
              textAlign: TextAlign.center,
              style: context.tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
            AppSpacing.h8,
            AppText(
              context.translate(LanguageLabelKeys.voiceSearchNotHeardSubtitle),
              textAlign: TextAlign.center,
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
            AppSpacing.h24,
            InkWell(
              onTap: _startListening,
              customBorder: const CircleBorder(),
              child: _micCircle(context, radius: 40, iconSize: 26),
            ),
            AppSpacing.h16,
            AppText(
              context.translate(LanguageLabelKeys.voiceSearchTapToRetry),
              textAlign: TextAlign.center,
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _VoiceStep.recognized:
        return SlideAnimationList(
          children: [
            AppText(
              _recognizedText,
              textAlign: TextAlign.center,
              style: context.tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
            AppSpacing.h24,
            CircleAvatar(
              radius: 40,
              backgroundColor: context.cs.onSecondaryContainer,
              child: AppSvgIcon(
                AssetsConstants.checkIcon,
                size: ThemeConstants.iconL,
                color: context.cs.surface,
              ),
            ),
          ],
        );
    }
  }

  Widget _pulsingMic(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1 + (_pulseController.value * 0.18);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.cs.primary.withValues(
                    alpha: 0.15 * (1 - _pulseController.value),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: _micCircle(context, radius: 40, iconSize: 26),
    );
  }

  Widget _micCircle(
    BuildContext context, {
    required double radius,
    required double iconSize,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.cs.primary,
      child: AppSvgIcon(
        AssetsConstants.microphoneIcon,
        size: iconSize,
        color: context.cs.onPrimary,
      ),
    );
  }
}
