import 'package:audioplayers/audioplayers.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/utils/app_logger.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/chat_message.dart';
import '../../../commons/widgets/app_text.dart';

class ChatAudioAttachment extends StatefulWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const ChatAudioAttachment({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  State<ChatAudioAttachment> createState() => _ChatAudioAttachmentState();
}

class _ChatAudioAttachmentState extends State<ChatAudioAttachment> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
    _preload();
  }

  Future<void> _preload() async {
    final att = widget.attachment;
    try {
      if (att.hasLocal) {
        await _player.setSource(DeviceFileSource(att.localPath!));
      } else if (att.hasRemote) {
        await _player.setSource(UrlSource(att.remoteUrl!));
      } else {
        return;
      }
      final dur = await _player.getDuration();
      if (dur != null && mounted) setState(() => _duration = dur);
    } catch (e) {
      logDebug(() => 'ChatAudioAttachment._preload failed: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    final att = widget.attachment;
    if (att.hasLocal) {
      await _player.play(DeviceFileSource(att.localPath!));
    } else if (att.hasRemote) {
      await _player.play(UrlSource(att.remoteUrl!));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final isPlaying = _state == PlayerState.playing;
    final fg = isMe ? context.cs.onPrimary : context.cs.onSurface;
    final iconBg = isMe
        ? context.cs.onPrimary.withValues(alpha: 0.15)
        : context.cs.primary.withValues(alpha: 0.12);
    final iconColor = isMe ? context.cs.onPrimary : context.cs.primary;
    final total = _duration > Duration.zero
        ? _duration
        : const Duration(seconds: 1);
    final progress = (_position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingM, 10, ThemeConstants.paddingM, ThemeConstants.paddingXS),
      child: Row(
        mainAxisSize: .min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: context.screenWidth * 0.101,
              height: context.screenWidth * 0.101,
              decoration: AppDecorations.circle(color: iconBg),
              child: AppSvgIcon(
                isPlaying
                    ? AssetsConstants.pauseIcon
                    : AssetsConstants.playIcon,
                color: iconColor,
                size: ThemeConstants.iconL, fit: BoxFit.scaleDown,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.r2,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: fg.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
                AppSpacing.h4,
                AppText(
                  _duration > Duration.zero
                      ? '${_fmt(_position)} / ${_fmt(_duration)}'
                      : _fmt(_position),
                  style: context.tt.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
