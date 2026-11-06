import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import '../../../commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  /// Called when the user taps a failed message's status icon to resend it.
  final VoidCallback? onRetry;

  const ChatBubble({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Align(
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.screenWidth * 0.72),
        child: Container(
          margin: EdgeInsetsDirectional.only(
            top: ThemeConstants.paddingXS,
            bottom: ThemeConstants.paddingXS,
            start: isMe ? 48 : 0,
            end: isMe ? 0 : 48,
          ),
          decoration: AppDecorations.box(
            color: isMe
                ? context.cs.primary
                : context.cs.surfaceContainerHighest,
            borderRadius: BorderRadiusDirectional.only(
              topStart: AppRadius.lg,
              topEnd: AppRadius.lg,
              bottomStart: isMe ? AppRadius.lg : AppRadius.xs,
              bottomEnd: isMe ? AppRadius.xs : AppRadius.lg,
            ),
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadiusDirectional.only(
              topStart: AppRadius.lg,
              topEnd: AppRadius.lg,
              bottomStart: isMe ? AppRadius.lg : AppRadius.xs,
              bottomEnd: isMe ? AppRadius.xs : AppRadius.lg,
            ),
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                if (message.attachment != null)
                  _AttachmentView(attachment: message.attachment!, isMe: isMe),
                if (message.message.isNotEmpty || message.attachment == null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ThemeConstants.paddingM,
                      ThemeConstants.paddingS,
                      ThemeConstants.paddingM,
                      ThemeConstants.paddingXS,
                    ),
                    child: AppText(
                      message.message,
                      style: context.tt.bodyMedium?.copyWith(
                        color: isMe
                            ? context.cs.onPrimary
                            : context.cs.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingM,
                    0,
                    ThemeConstants.paddingM,
                    ThemeConstants.paddingS,
                  ),
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      AppText(
                        AppDateFormatter.formatTime(message.timestamp),
                        style: context.tt.labelSmall?.copyWith(
                          fontSize: 10,
                          color: isMe
                              ? context.cs.onPrimary.withValues(alpha: 0.7)
                              : context.cs.onSurfaceVariant,
                        ),
                      ),
                      if (isMe) ...[
                        AppSpacing.w4,
                        _StatusIcon(
                          status: message.status,
                          onRetry: message.status == MessageStatus.failed
                              ? onRetry
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Attachment View ───────────────────────────────────────────────────────────

class _AttachmentView extends StatelessWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const _AttachmentView({required this.attachment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return _ImageAttachment(attachment: attachment, isMe: isMe);
    }
    if (attachment.isAudio) {
      return _AudioAttachment(attachment: attachment, isMe: isMe);
    }
    return _FileAttachment(attachment: attachment, isMe: isMe);
  }
}

// ── Image Attachment ──────────────────────────────────────────────────────────

class _ImageAttachment extends StatelessWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const _ImageAttachment({required this.attachment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (attachment.hasLocal) {
      img = Image.file(
        File(attachment.localPath!),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    } else if (attachment.hasRemote) {
      img = AppNetworkImage(
        url: attachment.remoteUrl!,
        width: double.infinity,
        height: context.screenHeight * 0.27,
        placeholder: Container(
          width: double.infinity,
          height: context.screenHeight * 0.27,
          color: isMe
              ? context.cs.primary.withValues(alpha: 0.3)
              : context.cs.surfaceContainerHighest,
          child: LoadingWidget(),
        ),
        errorWidget: _brokenImage(context),
      );
    } else {
      img = _brokenImage(context);
    }
    return GestureDetector(
      onTap: () =>
          AppNavigator.push(context, _FullScreenImage(attachment: attachment)),
      child: img,
    );
  }

  Widget _brokenImage(BuildContext context) => Container(
    width: double.infinity,
    height: 120,
    color: isMe
        ? context.cs.primary.withValues(alpha: 0.3)
        : context.cs.surfaceContainerHighest,
    alignment: Alignment.center,
    child: FractionallySizedBox(
      widthFactor: 0.3,
      heightFactor: 0.3,
      child: AppSvgIcon(AssetsConstants.placeholder, fit: BoxFit.contain),
    ),
  );
}

// ── Audio Attachment ──────────────────────────────────────────────────────────

class _AudioAttachment extends StatefulWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const _AudioAttachment({required this.attachment, required this.isMe});

  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
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
    } catch (_) {}
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingM,
        ThemeConstants.paddingS,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXS,
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: AppDecorations.box(color: iconBg, shape: .circle),
              child: AppSvgIcon(
                isPlaying
                    ? AssetsConstants.pauseIcon
                    : AssetsConstants.playIcon,
                color: iconColor,
                size: ThemeConstants.iconL,
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
          AppSpacing.w10,
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

// ── File Attachment ───────────────────────────────────────────────────────────

class _FileAttachment extends StatefulWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const _FileAttachment({required this.attachment, required this.isMe});

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _FileAttachmentState extends State<_FileAttachment> {
  bool _downloading = false;

  Future<void> _open() async {
    final att = widget.attachment;
    if (_downloading) return;
    if (att.hasLocal) {
      await OpenFile.open(att.localPath!);
      return;
    }
    if (!att.hasRemote) return;
    setState(() => _downloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final fileName = att.fileName ?? att.remoteUrl!.split('/').last;
      final savePath = '${dir.path}/$fileName';
      await ApiClient.external.download(att.remoteUrl!, savePath);
      if (mounted) await OpenFile.open(savePath);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.couldNotDownloadFile),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final attachment = widget.attachment;
    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingM,
          ThemeConstants.paddingS,
          ThemeConstants.paddingM,
          ThemeConstants.paddingXS,
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: AppDecorations.box(
                color: isMe
                    ? context.cs.onPrimary.withValues(alpha: 0.2)
                    : context.cs.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.r8,
              ),
              child: _downloading
                  ? Padding(
                      padding: const EdgeInsetsDirectional.all(
                        ThemeConstants.paddingS,
                      ),
                      child: LoadingWidget(),
                    )
                  : AppSvgIcon(
                      attachment.isVideo
                          ? AssetsConstants.playCircleIcon
                          : AssetsConstants.fileIcon,
                      color: isMe ? context.cs.onPrimary : context.cs.primary,
                      size: ThemeConstants.iconL,
                      fit: BoxFit.scaleDown,
                    ),
            ),
            AppSpacing.w10,
            Flexible(
              child: AppText(
                attachment.fileName ??
                    context.translate(LanguageLabelKeys.file),
                style: context.tt.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isMe ? context.cs.onPrimary : context.cs.onSurface,
                ),
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full Screen Image ─────────────────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final ChatAttachment attachment;
  const _FullScreenImage({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: context.cs.inverseSurface,
      appBar: CustomAppBar(
        backgroundColor: context.cs.inverseSurface,
        foregroundColor: context.cs.onInverseSurface,
      ),
      body: Center(
        child: InteractiveViewer(
          child: attachment.hasLocal
              ? Image.file(File(attachment.localPath!))
              : attachment.hasRemote
              ? AppNetworkImage(url: attachment.remoteUrl!)
              : AppSvgIcon(
                  AssetsConstants.fileBrokenIcon,
                  color: context.cs.onInverseSurface,
                  size: ThemeConstants.iconL,
                  fit: BoxFit.scaleDown,
                ),
        ),
      ),
    );
  }
}

// ── Status Icon ───────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final VoidCallback? onRetry;
  const _StatusIcon({required this.status, this.onRetry});

  @override
  Widget build(BuildContext context) => switch (status) {
    MessageStatus.sending => LoadingWidget(size: ThemeConstants.loaderSizeS),
    MessageStatus.sent => AppSvgIcon(
      AssetsConstants.checkReadIcon,
      size: ThemeConstants.iconXS,
      color: context.cs.onPrimary.withValues(alpha: 0.7),
    ),
    MessageStatus.failed => GestureDetector(
      onTap: onRetry,
      child: AppSvgIcon(
        AssetsConstants.infoCircleIcon,
        size: ThemeConstants.iconXS,
        color: context.cs.error,
      ),
    ),
  };
}

// ── Date Divider ──────────────────────────────────────────────────────────────

class ChatDateDivider extends StatelessWidget {
  final DateTime date;
  const ChatDateDivider({super.key, required this.date});

  String _label(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    if (msgDay == today) return context.translate(LanguageLabelKeys.today);
    if (msgDay == today.subtract(const Duration(days: 1))) {
      return context.translate(LanguageLabelKeys.yesterday);
    }
    return AppDateFormatter.formatDateTime(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingM,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.cs.outlineVariant, height: 1)),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingM,
            ),
            child: AppText(
              _label(context),
              style: context.tt.labelSmall?.copyWith(
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.cs.outlineVariant, height: 1)),
        ],
      ),
    );
  }
}
