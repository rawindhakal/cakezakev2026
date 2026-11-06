import 'dart:io';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/widgets/attachment_preview.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import '../../../commons/widgets/app_text.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String text, {ChatAttachment? attachment}) onSend;
  final bool enabled;

  const ChatInputBar({super.key, required this.onSend, this.enabled = true});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _hasText = false;
  bool _isRecording = false;
  bool _showEmojiPicker = false;
  ChatAttachment? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focusNode.addListener(() {
      // When keyboard appears by tapping TextField, close emoji picker
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.somethingWentWrong),
          type: SnackBarType.warning,
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) setState(() => _isRecording = true);
  }

  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _maxAttachmentBytes = 20 * 1024 * 1024;

  bool _isWithinSizeLimit(String path, {bool isImage = false}) {
    final size = File(path).lengthSync();
    final limit = isImage ? _maxImageBytes : _maxAttachmentBytes;
    if (size <= limit) return true;
    if (mounted) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.fileTooLarge),
        type: SnackBarType.warning,
      );
    }
    return false;
  }

  Future<void> _stopAndSend() async {
    final path = await _recorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (path == null || !File(path).existsSync()) return;
    if (!_isWithinSizeLimit(path)) return;
    widget.onSend(
      '',
      attachment: ChatAttachment(
        localPath: path,
        type: AttachmentType.audio,
        fileName: p.basename(path),
      ),
    );
  }

  bool get _hasContent => _hasText || _pendingAttachment != null;
  bool get _canSend => _hasContent && widget.enabled;

  void _send() {
    if (!_canSend) return;
    final text = _controller.text.trim();
    final attachment = _pendingAttachment;
    _controller.clear();
    setState(() => _pendingAttachment = null);
    widget.onSend(text, attachment: attachment);
  }

  Future<void> _pickImage(ImageSource source, {bool fromSheet = false}) async {
    if (fromSheet) AppNavigator.pop(context);
    final xfile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xfile == null) return;
    if (!_isWithinSizeLimit(xfile.path, isImage: true)) return;
    setState(() {
      _pendingAttachment = ChatAttachment(
        localPath: xfile.path,
        type: AttachmentType.image,
        fileName: p.basename(xfile.path),
      );
    });
  }

  Future<void> _pickFile({bool fromSheet = false}) async {
    if (fromSheet) AppNavigator.pop(context);
    final result = await FilePicker.pickFile();
    final path = result?.path;
    if (path == null) return;
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    if (!_isWithinSizeLimit(
      path,
      isImage: ChatAttachment.imageExtensions.contains(ext),
    )) {
      return;
    }
    final type = ChatAttachment.imageExtensions.contains(ext)
        ? AttachmentType.image
        : ChatAttachment.videoExtensions.contains(ext)
        ? AttachmentType.video
        : ChatAttachment.audioExtensions.contains(ext)
        ? AttachmentType.audio
        : AttachmentType.file;
    setState(() {
      _pendingAttachment = ChatAttachment(
        localPath: path,
        type: type,
        fileName: p.basename(path),
      );
    });
  }

  void _showAttachMenu() {
    showAppBottomSheet(
      context,
      title: context.translate(LanguageLabelKeys.attachment),
      builder: (ctx) {
        final options = [
          _AttachOption(
            icon: AssetsConstants.cameraIcon,
            label: context.translate(LanguageLabelKeys.camera),
            color: ctx.cs.onSurfaceVariant,
            onTap: () => _pickImage(ImageSource.camera, fromSheet: true),
          ),
          _AttachOption(
            icon: AssetsConstants.galleryIcon,
            label: context.translate(LanguageLabelKeys.gallery),
            color: ctx.cs.onSurfaceVariant,
            onTap: () => _pickImage(ImageSource.gallery, fromSheet: true),
          ),
          _AttachOption(
            icon: AssetsConstants.fileIcon,
            label: context.translate(LanguageLabelKeys.file),
            color: ctx.cs.onSurfaceVariant,
            onTap: () => _pickFile(fromSheet: true),
          ),
        ];

        return SlideAnimationScope(
          builder: (context, animationController) => Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              for (var i = 0; i < options.length; i++)
                SlideAnimation(
                  position: i,
                  slideDirection: SlideDirection.fromBottom,
                  itemCount: options.length,
                  animationController: animationController,
                  child: options[i],
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        if (_pendingAttachment != null)
          AttachmentPreviewBar(
            attachment: _pendingAttachment!,
            onRemove: () => setState(() => _pendingAttachment = null),
          ),
        if (_showEmojiPicker)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              textEditingController: _controller,
              config: Config(
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: context.cs.surfaceContainerLow,
                  noRecents: AppText(
                    context.translate(LanguageLabelKeys.noRecentEmojis),
                    style: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: context.cs.surfaceContainerLow,
                  iconColorSelected: context.cs.primary,
                  iconColor: context.cs.onSurfaceVariant,
                  indicatorColor: context.cs.primary,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: context.cs.surfaceContainerLow,
                  buttonIconColor: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Container(
          padding: EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingM,
            ThemeConstants.paddingS,
            ThemeConstants.paddingM,
            context.bottomSafePadding + ThemeConstants.paddingS,
          ),
          child: Row(
            crossAxisAlignment: .end,
            spacing: ThemeConstants.spaceS,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 120,
                  ),
                  decoration: AppDecorations.box(
                    color: context.cs.surfaceContainerHighest,
                    borderRadius: AppRadius.r32,
                    border: Border.all(
                      color: context.cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: .end,
                    children: [
                      IconButton(
                        onPressed: _toggleEmojiPicker,
                        icon: AppSvgIcon(
                          _showEmojiPicker
                              ? AssetsConstants.keyboardIcon
                              : AssetsConstants.emojiIcon,
                          color: context.cs.onSurfaceVariant,
                          size: ThemeConstants.iconM,
                        ),
                        padding: EdgeInsetsDirectional.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          hintText: context.translate(
                            LanguageLabelKeys.typeMessage,
                          ),
                          cursorColor: context.cs.onSurface,
                          style: context.tt.bodyMedium?.copyWith(
                            color: context.cs.onSurface,
                          ),
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                            vertical: ThemeConstants.paddingM,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showAttachMenu,
                        icon: AppSvgIcon(
                          AssetsConstants.attachmentIcon,
                          size: ThemeConstants.iconM,
                          color: context.cs.onSurfaceVariant,
                        ),
                        padding: EdgeInsetsDirectional.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 40,
                        ),
                      ),
                      AppSpacing.w4,
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isRecording
                    ? _stopAndSend
                    : _hasContent
                    ? _send
                    : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: AppDecorations.box(
                    color: _isRecording ? context.cs.error : context.cs.primary,
                    shape: .circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: AppSvgIcon(
                      _isRecording
                          ? AssetsConstants.stopIcon
                          : _hasContent
                          ? AssetsConstants.sendIcon
                          : AssetsConstants.microphoneIcon,
                      key: ValueKey(
                        _isRecording
                            ? 'stop'
                            : _hasContent
                            ? 'send'
                            : 'mic',
                      ),
                      size: ThemeConstants.iconM,
                      color: context.cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachOption extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: .min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: AppDecorations.box(
              color: color.withValues(alpha: 0.12),
              shape: .circle,
            ),
            child: AppSvgIcon(
              icon,
              size: ThemeConstants.iconL,
              color: color,
              fit: BoxFit.scaleDown,
            ),
          ),
          AppSpacing.h8,
          AppText(
            label,
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
