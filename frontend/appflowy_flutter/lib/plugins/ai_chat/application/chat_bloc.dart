import 'dart:async';

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_entity.dart';
import 'chat_message_handler.dart';
import 'chat_message_listener.dart';
import 'chat_message_stream.dart';
import 'chat_settings_manager.dart';
import 'chat_stream_manager.dart';

part 'chat_bloc.freezed.dart';

/// 获取当前Unix时间戳（从纪元开始的秒数）
int timestamp() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// AI聊天管理BLoC - 负责管理AI聊天会话的核心业务逻辑
/// 
/// 主要功能：
/// 1. 消息的发送、接收和流式传输
/// 2. 历史消息的加载和分页
/// 3. AI回答的重新生成
/// 4. 相关问题的生成和展示
/// 5. 聊天设置管理（RAG源选择等）
/// 6. 错误处理和状态管理
/// 
/// 设计思想：
/// - 使用管理器模式分离不同职责（消息处理、流管理、设置管理）
/// - 支持流式响应以提供实时的AI回答
/// - 通过监听器模式实时同步后端消息变化
/// - 实现消息的本地缓存和远程同步
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this.chatId,
    required this.userId,
  })  : chatController = InMemoryChatController(), // 内存消息控制器
        listener = ChatMessageListener(chatId: chatId), // 消息监听器
        super(ChatState.initial()) {
    // 初始化各个管理器
    _messageHandler = ChatMessageHandler( // 消息处理器
      chatId: chatId,
      userId: userId,
      chatController: chatController,
    );

    _streamManager = ChatStreamManager(chatId); // 流管理器
    _settingsManager = ChatSettingsManager(chatId: chatId); // 设置管理器

    _startListening(); // 启动消息监听
    _dispatch(); // 设置事件分发
    _loadMessages(); // 加载历史消息
    _loadSettings(); // 加载聊天设置
  }

  final String chatId; // 聊天会话ID
  final String userId; // 用户ID
  final ChatMessageListener listener; // 消息监听器
  final ChatController chatController; // 聊天控制器

  // 管理器实例
  late final ChatMessageHandler _messageHandler; // 消息处理管理器
  late final ChatStreamManager _streamManager; // 流式传输管理器
  late final ChatSettingsManager _settingsManager; // 设置管理器

  ChatMessagePB? lastSentMessage; // 最后发送的消息

  bool isLoadingPreviousMessages = false; // 是否正在加载历史消息
  bool hasMorePreviousMessages = true; // 是否还有更多历史消息
  bool isFetchingRelatedQuestions = false; // 是否正在获取相关问题
  bool shouldFetchRelatedQuestions = false; // 是否应该获取相关问题

  // 获取选中的RAG数据源
  ValueNotifier<List<String>> get selectedSourcesNotifier =>
      _settingsManager.selectedSourcesNotifier;

  @override
  Future<void> close() async {
    // 安全释放所有资源
    await _streamManager.dispose(); // 释放流管理器
    await listener.stop(); // 停止消息监听

    // 关闭聊天视图
    final request = ViewIdPB(value: chatId);
    unawaited(FolderEventCloseView(request).send());

    _settingsManager.dispose(); // 释放设置管理器
    chatController.dispose(); // 释放聊天控制器
    return super.close();
  }

  /// 事件分发器 - 处理所有聊天相关事件
  void _dispatch() {
    on<ChatEvent>((event, emit) async {
      await event.when(
        // 聊天设置相关
        didReceiveChatSettings: (settings) async =>
            _handleChatSettings(settings),
        updateSelectedSources: (selectedSourcesIds) async =>
            _handleUpdateSources(selectedSourcesIds),

        // 消息加载相关
        didLoadLatestMessages: (messages) async =>
            _handleLatestMessages(messages, emit),
        loadPreviousMessages: () async => _loadPreviousMessagesIfNeeded(),
        didLoadPreviousMessages: (messages, hasMore) async =>
            _handlePreviousMessages(messages, hasMore),

        // Message handling
        receiveMessage: (message) async => _handleReceiveMessage(message),

        // Sending messages
        sendMessage: (message, format, metadata, promptId) async =>
            _handleSendMessage(message, format, metadata, promptId, emit),
        finishSending: () async => emit(
          state.copyWith(
            promptResponseState: PromptResponseState.streamingAnswer,
          ),
        ),

        // Stream control
        stopStream: () async => _handleStopStream(emit),
        failedSending: () async => _handleFailedSending(emit),

        // Answer regeneration
        regenerateAnswer: (id, format, model) async =>
            _handleRegenerateAnswer(id, format, model, emit),

        // Streaming completion
        didFinishAnswerStream: () async => emit(
          state.copyWith(
            promptResponseState: PromptResponseState.ready,
          ),
        ),

        // Related questions
        didReceiveRelatedQuestions: (questions) async =>
            _handleRelatedQuestions(
          questions,
          emit,
        ),

        // Message management
        deleteMessage: (message) async => chatController.remove(message),

        // AI follow-up
        onAIFollowUp: (followUpData) async {
          shouldFetchRelatedQuestions =
              followUpData.shouldGenerateRelatedQuestion;
        },
      );
    });
  }

  // 聊天设置处理
  /// 处理接收到的聊天设置
  void _handleChatSettings(ChatSettingsPB settings) {
    _settingsManager.selectedSourcesNotifier.value = settings.ragIds;
  }

  /// 更新选中的RAG数据源
  Future<void> _handleUpdateSources(List<String> selectedSourcesIds) async {
    await _settingsManager.updateSelectedSources(selectedSourcesIds);
  }

  // 消息加载处理
  /// 处理最新消息的加载
  Future<void> _handleLatestMessages(
    List<Message> messages,
    Emitter<ChatState> emit,
  ) async {
    // 将消息插入到列表开头
    for (final message in messages) {
      await chatController.insert(message, index: 0);
    }

    // 检查异步操作后emit是否仍有效
    if (emit.isDone) {
      return;
    }

    // 根据当前状态更新加载状态
    switch (state.loadingState) {
      case LoadChatMessageStatus.loading when chatController.messages.isEmpty:
        // 本地无消息，从远程加载
        emit(state.copyWith(loadingState: LoadChatMessageStatus.loadingRemote));
        break;
      case LoadChatMessageStatus.loading:
      case LoadChatMessageStatus.loadingRemote:
        // 加载完成
        emit(state.copyWith(loadingState: LoadChatMessageStatus.ready));
        break;
      default:
        break;
    }
  }

  /// 处理历史消息的加载
  void _handlePreviousMessages(List<Message> messages, bool hasMore) {
    // 将历史消息插入到列表开头
    for (final message in messages) {
      chatController.insert(message, index: 0);
    }

    isLoadingPreviousMessages = false; // 结束加载状态
    hasMorePreviousMessages = hasMore; // 更新是否还有更多消息
  }

  // 消息处理
  /// 处理接收到的消息，支持新增和更新
  void _handleReceiveMessage(Message message) {
    final oldMessage =
        chatController.messages.firstWhereOrNull((m) => m.id == message.id);
    if (oldMessage == null) {
      // 新消息，直接插入
      chatController.insert(message);
    } else {
      // 已存在的消息，进行更新
      chatController.update(oldMessage, message);
    }
  }

  // 消息发送处理
  /// 处理发送消息的逻辑
  void _handleSendMessage(
    String message,
    PredefinedFormat? format, // 预定义格式（图片、文本等）
    Map<String, dynamic>? metadata, // 元数据
    String? promptId, // 提示词ID
    Emitter<ChatState> emit,
  ) {
    // 清除错误消息
    _messageHandler.clearErrorMessages();
    emit(state.copyWith(clearErrorMessages: !state.clearErrorMessages));

    // 清除相关问题
    _messageHandler.clearRelatedQuestions();
    // 开始流式传输消息
    _startStreamingMessage(message, format, metadata, promptId);
    lastSentMessage = null;

    // 设置相关问题获取状态
    isFetchingRelatedQuestions = false;
    shouldFetchRelatedQuestions = format == null || format.imageFormat.hasText;

    // 更新状态为发送中
    emit(
      state.copyWith(
        promptResponseState: PromptResponseState.sendingQuestion,
      ),
    );
  }

  // 流控制处理
  /// 处理停止流式传输
  Future<void> _handleStopStream(Emitter<ChatState> emit) async {
    await _streamManager.stopStream();

    // 允许用户输入
    emit(state.copyWith(promptResponseState: PromptResponseState.ready));

    // 如果流已经开始，不需要移除消息
    if (_streamManager.hasAnswerStreamStarted) {
      return;
    }

    // 移除未开始的消息
    final message = chatController.messages.lastWhereOrNull(
      (e) => e.id == _messageHandler.answerStreamMessageId,
    );
    if (message != null) {
      await chatController.remove(message);
    }

    await _streamManager.disposeAnswerStream();
  }

  /// 处理发送失败
  void _handleFailedSending(Emitter<ChatState> emit) {
    // 移除失败的消息
    final lastMessage = chatController.messages.lastOrNull;
    if (lastMessage != null) {
      chatController.remove(lastMessage);
    }
    // 恢复到就绪状态
    emit(state.copyWith(promptResponseState: PromptResponseState.ready));
  }

  // 回答重新生成处理
  /// 处理重新生成AI回答
  void _handleRegenerateAnswer(
    String id, // 要重新生成的消息ID
    PredefinedFormat? format, // 预定义格式
    AIModelPB? model, // AI模型
    Emitter<ChatState> emit,
  ) {
    _messageHandler.clearRelatedQuestions(); // 清除相关问题
    _regenerateAnswer(id, format, model); // 执行重新生成
    lastSentMessage = null;

    // 重置相关问题状态
    isFetchingRelatedQuestions = false;
    shouldFetchRelatedQuestions = false;

    // 更新状态为发送中
    emit(
      state.copyWith(
        promptResponseState: PromptResponseState.sendingQuestion,
      ),
    );
  }

  // 相关问题处理
  /// 处理接收到的相关问题
  void _handleRelatedQuestions(
    List<String> questions,
    Emitter<ChatState> emit,
  ) {
    if (questions.isEmpty) {
      return;
    }

    // 构建相关问题消息的元数据
    final metadata = {
      onetimeShotType: OnetimeShotType.relatedQuestion,
      'questions': questions,
    };

    // 创建相关问题消息
    final createdAt = DateTime.now();
    final message = TextMessage(
      id: "related_question_$createdAt",
      text: '',
      metadata: metadata,
      author: const User(id: systemUserId), // 系统用户作为作者
      createdAt: createdAt,
    );

    chatController.insert(message);

    // 更新状态为相关问题就绪
    emit(
      state.copyWith(
        promptResponseState: PromptResponseState.relatedQuestionsReady,
      ),
    );
  }

  /// 启动消息监听
  /// 
  /// 设置各种回调以处理不同类型的消息和事件
  void _startListening() {
    listener.start(
      // 聊天消息回调
      chatMessageCallback: (pb) {
        if (isClosed) {
          return;
        }

        _messageHandler.processReceivedMessage(pb); // 处理接收到的消息
        final message = _messageHandler.createTextMessage(pb); // 创建文本消息
        add(ChatEvent.receiveMessage(message)); // 触发接收消息事件
      },
      // 错误消息回调
      chatErrorMessageCallback: (err) {
        if (!isClosed) {
          Log.error("chat error: ${err.errorMessage}");
          add(const ChatEvent.didFinishAnswerStream()); // 结束答案流
        }
      },
      // 最新消息回调
      latestMessageCallback: (list) {
        if (!isClosed) {
          final messages =
              list.messages.map(_messageHandler.createTextMessage).toList();
          add(ChatEvent.didLoadLatestMessages(messages)); // 触发加载最新消息事件
        }
      },
      prevMessageCallback: (list) {
        if (!isClosed) {
          final messages =
              list.messages.map(_messageHandler.createTextMessage).toList();
          add(ChatEvent.didLoadPreviousMessages(messages, list.hasMore));
        }
      },
      // 流式传输完成回调
      finishStreamingCallback: () async {
        if (isClosed) {
          return;
        }

        add(const ChatEvent.didFinishAnswerStream()); // 触发答案流完成事件
        unawaited(_fetchRelatedQuestionsIfNeeded()); // 异步获取相关问题
      },
    );
  }

  /// 根据需要获取相关问题
  /// 
  /// 在AI回答完成后，根据用户的问题生成相关推荐问题
  Future<void> _fetchRelatedQuestionsIfNeeded() async {
    // 检查是否满足获取相关问题的条件
    if (_streamManager.answerStream == null ||
        lastSentMessage == null ||
        !shouldFetchRelatedQuestions) {
      return;
    }

    final payload = ChatMessageIdPB(
      chatId: chatId,
      messageId: lastSentMessage!.messageId,
    );

    isFetchingRelatedQuestions = true;
    await AIEventGetRelatedQuestion(payload).send().fold(
      (list) {
        // while fetching related questions, the user might enter a new
        // question or regenerate a previous response. In such cases, don't
        // display the relatedQuestions
        if (!isClosed && isFetchingRelatedQuestions) {
          add(
            ChatEvent.didReceiveRelatedQuestions(
              list.items.map((e) => e.content).toList(),
            ),
          );
          isFetchingRelatedQuestions = false;
        }
      },
      (err) => Log.error("Failed to get related questions: $err"),
    );
  }

  /// 加载聊天设置
  void _loadSettings() async {
    final getChatSettingsPayload =
        AIEventGetChatSettings(ChatId(value: chatId));

    await getChatSettingsPayload.send().fold(
      (settings) {
        if (!isClosed) {
          add(ChatEvent.didReceiveChatSettings(settings: settings)); // 触发设置接收事件
        }
      },
      (err) => Log.error("Failed to load chat settings: $err"),
    );
  }

  /// 加载初始消息
  void _loadMessages() async {
    final loadMessagesPayload = LoadNextChatMessagePB(
      chatId: chatId,
      limit: Int64(10), // 加载10条消息
    );

    await AIEventLoadNextMessage(loadMessagesPayload).send().fold(
      (list) {
        if (!isClosed) {
          // 转换并触发消息加载事件
          final messages =
              list.messages.map(_messageHandler.createTextMessage).toList();
          add(ChatEvent.didLoadLatestMessages(messages));
        }
      },
      (err) => Log.error("Failed to load messages: $err"),
    );
  }

  /// 按需加载历史消息
  void _loadPreviousMessagesIfNeeded() {
    if (isLoadingPreviousMessages) {
      return; // 已在加载中，避免重复加载
    }

    final oldestMessage = _messageHandler.getOldestMessage();

    if (oldestMessage != null) {
      final oldestMessageId = Int64.tryParseInt(oldestMessage.id);
      if (oldestMessageId == null) {
        Log.error("Failed to parse message_id: ${oldestMessage.id}");
        return;
      }
      isLoadingPreviousMessages = true;
      _loadPreviousMessages(oldestMessageId); // 加载更早的消息
    }
  }

  void _loadPreviousMessages(Int64? beforeMessageId) {
    final payload = LoadPrevChatMessagePB(
      chatId: chatId,
      limit: Int64(10),
      beforeMessageId: beforeMessageId,
    );
    AIEventLoadPrevMessage(payload).send();
  }

  /// 开始流式传输消息
  /// 
  /// 创建问题和答案的流式传输，实现实时的AI对话
  Future<void> _startStreamingMessage(
    String message,
    PredefinedFormat? format,
    Map<String, dynamic>? metadata,
    String? promptId,
  ) async {
    // 准备流式传输
    await _streamManager.prepareStreams();

    // 创建并添加问题消息
    final questionStreamMessage = _messageHandler.createQuestionStreamMessage(
      _streamManager.questionStream!,
      metadata,
    );
    add(ChatEvent.receiveMessage(questionStreamMessage));

    // Send stream request
    await _streamManager.sendStreamRequest(message, format, promptId).fold(
      (question) {
        if (!isClosed) {
          // Create and add answer stream message
          final streamAnswer = _messageHandler.createAnswerStreamMessage(
            stream: _streamManager.answerStream!,
            questionMessageId: question.messageId,
            fakeQuestionMessageId: questionStreamMessage.id,
          );

          lastSentMessage = question;
          add(const ChatEvent.finishSending());
          add(ChatEvent.receiveMessage(streamAnswer));
        }
      },
      (err) {
        if (!isClosed) {
          Log.error("Failed to send message: ${err.msg}");

          final metadata = {
            onetimeShotType: OnetimeShotType.error,
            if (err.code != ErrorCode.Internal) errorMessageTextKey: err.msg,
          };

          final error = TextMessage(
            text: '',
            metadata: metadata,
            author: const User(id: systemUserId),
            id: systemUserId,
            createdAt: DateTime.now(),
          );

          add(const ChatEvent.failedSending());
          add(ChatEvent.receiveMessage(error));
        }
      },
    );
  }

  /// 重新生成AI回答
  /// 
  /// 对指定的回答进行重新生成，支持切换AI模型
  void _regenerateAnswer(
    String answerMessageIdString, // 回答消息ID
    PredefinedFormat? format, // 预定义格式
    AIModelPB? model, // AI模型
  ) async {
    final id = _messageHandler.getEffectiveMessageId(answerMessageIdString);
    final answerMessageId = Int64.tryParseInt(id);
    if (answerMessageId == null) {
      return;
    }

    await _streamManager.prepareStreams();
    await _streamManager
        .sendRegenerateRequest(
      answerMessageId,
      format,
      model,
    )
        .fold(
      (_) {
        if (!isClosed) {
          final streamAnswer = _messageHandler
              .createAnswerStreamMessage(
                stream: _streamManager.answerStream!,
                questionMessageId: answerMessageId - 1,
              )
              .copyWith(id: answerMessageIdString);

          add(ChatEvent.receiveMessage(streamAnswer));
          add(const ChatEvent.finishSending());
        }
      },
      (err) => Log.error("Failed to regenerate answer: ${err.msg}"),
    );
  }
}

/// 聊天事件定义
@freezed
class ChatEvent with _$ChatEvent {
  // 聊天设置相关
  const factory ChatEvent.didReceiveChatSettings({
    required ChatSettingsPB settings, // 聊天设置
  }) = _DidReceiveChatSettings;
  const factory ChatEvent.updateSelectedSources({
    required List<String> selectedSourcesIds, // 选中的RAG数据源ID
  }) = _UpdateSelectedSources;

  // 发送消息相关
  const factory ChatEvent.sendMessage({
    required String message, // 消息内容
    PredefinedFormat? format, // 预定义格式
    Map<String, dynamic>? metadata, // 元数据
    String? promptId, // 提示词ID
  }) = _SendMessage;
  const factory ChatEvent.finishSending() = _FinishSendMessage; // 完成发送
  const factory ChatEvent.failedSending() = _FailSendMessage; // 发送失败

  // regenerate
  const factory ChatEvent.regenerateAnswer(
    String id,
    PredefinedFormat? format,
    AIModelPB? model,
  ) = _RegenerateAnswer;

  // streaming answer
  const factory ChatEvent.stopStream() = _StopStream;
  const factory ChatEvent.didFinishAnswerStream() = _DidFinishAnswerStream;

  // receive message
  const factory ChatEvent.receiveMessage(Message message) = _ReceiveMessage;

  // loading messages
  const factory ChatEvent.didLoadLatestMessages(List<Message> messages) =
      _DidLoadMessages;
  const factory ChatEvent.loadPreviousMessages() = _LoadPreviousMessages;
  const factory ChatEvent.didLoadPreviousMessages(
    List<Message> messages,
    bool hasMore,
  ) = _DidLoadPreviousMessages;

  // related questions
  const factory ChatEvent.didReceiveRelatedQuestions(
    List<String> questions,
  ) = _DidReceiveRelatedQueston;

  const factory ChatEvent.deleteMessage(Message message) = _DeleteMessage;

  const factory ChatEvent.onAIFollowUp(AIFollowUpData followUpData) =
      _OnAIFollowUp;
}

/// 聊天状态定义
@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    required LoadChatMessageStatus loadingState, // 消息加载状态
    required PromptResponseState promptResponseState, // 提示响应状态
    required bool clearErrorMessages, // 是否清除错误消息
  }) = _ChatState;

  /// 创建初始状态
  factory ChatState.initial() => const ChatState(
        loadingState: LoadChatMessageStatus.loading,
        promptResponseState: PromptResponseState.ready,
        clearErrorMessages: false,
      );
}

/// 判断是否为其他用户的消息
/// 
/// 排除AI回复、系统消息和流式消息
bool isOtherUserMessage(Message message) {
  return message.author.id != aiResponseUserId && // 非AI回复
      message.author.id != systemUserId && // 非系统消息
      !message.author.id.startsWith("streamId:"); // 非流式消息
}
