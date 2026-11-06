import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/cubit/chat_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/chat_bubble.dart';
import 'package:deliveryboy/features/chat/widgets/chat_date_divider.dart';
import 'package:deliveryboy/features/chat/widgets/chat_input_bar.dart';
import 'package:deliveryboy/features/chat/widgets/chat_skeleton_loader.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Chat conversation screen — message list, date dividers, and the input bar.
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
    _cubit = ChatCubit()
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
      // Deliberately not gated behind a full-screen offline state: that would
      // unmount the message list and the input bar, throwing away a typed
      // draft on a brief drop. The cubit already surfaces socket loss via
      // ChatReconnecting/ChatDisconnected, so all that's missing is re-
      // establishing the socket once the device is back — the same path used
      // after an app resume.
      child: BlocListener<ConnectivityCubit, ConnectivityState>(
        listener: (context, state) {
          if (state is ConnectivityConnected) _cubit.reconnect(_args.roomId);
        },
        child: AppScaffold(
          applyBottomInset: false,
          appBar: CustomAppBar(title: _args.recipientName),
          body: Column(
            children: [
              Expanded(
                child: BlocConsumer<ChatCubit, ChatState>(
                  listener: (context, state) {
                    if (state is ChatConnected) _scrollToBottom();
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
                      return RefreshIndicator(
                        onRefresh: () =>
                            context.read<ChatCubit>().loadOlderMessages(),
                        child: ListView(
                          children: [
                            SizedBox(
                              height: context.screenHeight * 0.7,
                              child: EmptyStateWidget(
                                title: context.translate(
                                  LanguageLabelKeys.noMessagesYet,
                                ),
                                subtitle: context.translate(
                                  LanguageLabelKeys.startConversation,
                                ),
                                imagePath: AssetsConstants.noChatFound,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () =>
                          context.read<ChatCubit>().loadOlderMessages(),
                      child: ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        controller: _scrollController,
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
                              if (showDate)
                                ChatDateDivider(date: msg.timestamp),
                              ChatBubble(message: msg),
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
                  return ChatInputBar(
                    // Sending uses REST, not the socket — only block input while
                    // the very first connect/history-load is in flight.
                    enabled: state is! ChatInitial && state is! ChatConnecting,
                    onSend: (text, {attachment}) => context
                        .read<ChatCubit>()
                        .sendMessage(text, attachment: attachment),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
