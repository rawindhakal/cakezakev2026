import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/attachment_preview.dart';
import 'package:deliveryboy/features/chat/widgets/chat_attach_menu.dart';
import 'package:deliveryboy/features/chat/widgets/chat_emoji_picker.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
    if (!hasPermission) return;
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
        type: SnackBarType.error,
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
    final file = await FilePicker.pickFile();
    final path = file?.path;
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
    showChatAttachMenu(
      context,
      onCamera: () => _pickImage(.camera, fromSheet: true),
      onGallery: () => _pickImage(.gallery, fromSheet: true),
      onFile: () => _pickFile(fromSheet: true),
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
        if (_showEmojiPicker) ChatEmojiPicker(controller: _controller),
        Container(
          padding: EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingM,
            ThemeConstants.paddingS,
            ThemeConstants.paddingM,
            context.bottomSafePadding + 8,
          ),
          child: Row(
            crossAxisAlignment: .end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 120,
                  ),
                  decoration: AppDecorations.card(
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
                            LanguageLabelKeys.typeAMessage,
                          ),
                          variant: AppTextFieldVariant.plain,
                        ),
                      ),
                      IconButton(
                        onPressed: _showAttachMenu,
                        icon: AppSvgIcon(
                          AssetsConstants.attachmentIcon,
                          color: context.cs.onSurfaceVariant,
                          size: ThemeConstants.iconM,
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
              AppSpacing.w8,
              GestureDetector(
                onTap: _isRecording
                    ? _stopAndSend
                    : _hasContent
                    ? _send
                    : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: context.screenWidth * 0.128,
                  height: context.screenWidth * 0.128,
                  decoration: AppDecorations.circle(
                    color: _isRecording ? context.cs.error : context.cs.primary,
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
