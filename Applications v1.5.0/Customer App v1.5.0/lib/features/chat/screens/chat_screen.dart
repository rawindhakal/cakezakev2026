import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/chat/cubit/chat_cubit.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/widgets/chat_bubble.dart';
import 'package:customer/features/chat/widgets/chat_input_bar.dart';
import 'package:customer/features/chat/widgets/chat_skeleton_loader.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  late final ChatScreenArgs _args;
  late final ChatCubit _cubit;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _args = ModalRoute.of(context)!.settings.arguments as ChatScreenArgs;
    _cubit = ChatCubit(sendLocation: _args.sendLocation)
      ..connect(_args.roomId, conversationId: _args.conversationId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: AppScaffold(
        applyBottomInset: false,
        appBar: CustomAppBar(title: _args.recipientName),
        body: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatCubit, ChatState>(
                listener: (context, state) {
                  if (state is ChatConnected && !state.isOlderMessagesLoad) {
                    _scrollToBottom();
                  }
                },
                builder: (context, state) {
                  if (state is ChatInitial || state is ChatConnecting) {
                    return const ChatSkeletonLoader();
                  }

                  final messages = switch (state) {
                    ChatConnected s => s.messages,
                    ChatReconnecting s => s.messages,
                    ChatDisconnected s => s.messages,
                    _ => <ChatMessage>[],
                  };

                  if (messages.isEmpty) {
                    return EmptyStateWidget(
                      imagePath: AssetsConstants.noChatFound,
                      title: context.translate(LanguageLabelKeys.noMessages),
                      subtitle: context.translate(
                        LanguageLabelKeys.startConversation,
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<ChatCubit>().loadOlderMessages(),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingS,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final showDate =
                            index == 0 ||
                            !_sameDay(
                              messages[index - 1].timestamp,
                              msg.timestamp,
                            );
                        return Column(
                          children: [
                            if (showDate) ChatDateDivider(date: msg.timestamp),
                            ChatBubble(
                              message: msg,
                              onRetry: () => context
                                  .read<ChatCubit>()
                                  .retryMessage(msg.id),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) {
                if (state is ChatDisconnected) {
                  return _ReconnectBanner(
                    onTap: () =>
                        context.read<ChatCubit>().reconnect(_args.roomId),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) {
                // Sending is a REST call, independent of the socket's
                // real-time connection state — only block it before the
                // initial history load resolves the conversation.
                final ready =
                    state is ChatConnected ||
                    state is ChatReconnecting ||
                    state is ChatDisconnected;
                return ChatInputBar(
                  enabled: ready,
                  onSend: (text, {attachment}) => context
                      .read<ChatCubit>()
                      .sendMessage(text, attachment: attachment),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ReconnectBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: ThemeConstants.paddingM,
        ),
        color: context.cs.errorContainer,
        child: Row(
          mainAxisAlignment: .center,
          children: [
            AppSvgIcon(
              AssetsConstants.refreshIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onErrorContainer,
            ),
            const SizedBox(width: 8),
            AppText(
              context.translate(LanguageLabelKeys.chatConnectionLostTapToRetry),
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
