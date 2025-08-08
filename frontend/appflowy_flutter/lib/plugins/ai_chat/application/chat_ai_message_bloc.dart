import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_message_stream.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_message_service.dart';

part 'chat_ai_message_bloc.freezed.dart';

/// AI消息状态管理器 - 负责管理AI回复消息的状态和行为
/// 
/// 主要功能：
/// 1. 实时更新AI回复文本（流式传输）
/// 2. 处理重试机制
/// 3. 管理AI回复限制（频率限制、图片限制等）
/// 4. 处理元数据（引用源、处理进度）
/// 5. 管理后续问题推荐
/// 6. 本地AI初始化状态
/// 
/// 设计思想：
/// - 通过AnswerStream实现流式回复
/// - 支持多种状态（加载中、就绪、错误、限制等）
/// - 集成元数据解析和显示
/// - 安全地处理BLoC生命周期
class ChatAIMessageBloc extends Bloc<ChatAIMessageEvent, ChatAIMessageState> {
  ChatAIMessageBloc({
    dynamic message,
    String? refSourceJsonString,
    required this.chatId,
    required this.questionId,
  }) : super(
          ChatAIMessageState.initial(
            message,
            parseMetadata(refSourceJsonString),
          ),
        ) {
    _registerEventHandlers();
    _initializeStreamListener();
    _checkInitialStreamState();
  }

  /// 聊天会话ID
  final String chatId;
  
  /// 问题ID，用于重试和获取回答
  final Int64? questionId;

  /// 注册所有事件处理器
  /// 
  /// 处理的事件类型：
  /// - 文本更新：流式更新AI回复内容
  /// - 错误处理：接收并显示错误
  /// - 重试机制：重新获取AI回答
  /// - 频率限制：处理AI回复频率限制
  /// - 图片限制：处理AI图片生成限制
  /// - 订阅限制：处理AI Max订阅要求
  /// - 本地AI：显示本地AI初始化状态
  /// - 元数据：更新引用源和处理进度
  /// - 后续问题：接收AI推荐的后续问题
  void _registerEventHandlers() {
    // 更新文本内容
    on<_UpdateText>((event, emit) {
      emit(
        state.copyWith(
          text: event.text,
          messageState: const MessageState.ready(),
        ),
      );
    });

    // 处理错误
    on<_ReceiveError>((event, emit) {
      emit(state.copyWith(messageState: MessageState.onError(event.error)));
    });

    // 重试获取回答
    on<_Retry>((event, emit) async {
      if (questionId == null) {
        Log.error("Question id is not valid: $questionId");
        return;
      }
      emit(state.copyWith(messageState: const MessageState.loading()));
      final payload = ChatMessageIdPB(
        chatId: chatId,
        messageId: questionId,
      );
      // 调用后端获取回答
      final result = await AIEventGetAnswerForQuestion(payload).send();
      if (!isClosed) {
        result.fold(
          (answer) => add(ChatAIMessageEvent.retryResult(answer.content)),
          (err) {
            Log.error("Failed to get answer: $err");
            add(ChatAIMessageEvent.receiveError(err.toString()));
          },
        );
      }
    });

    // 处理重试结果
    on<_RetryResult>((event, emit) {
      emit(
        state.copyWith(
          text: event.text,
          messageState: const MessageState.ready(),
        ),
      );
    });

    // AI回复频率限制
    on<_OnAIResponseLimit>((event, emit) {
      emit(
        state.copyWith(
          messageState: const MessageState.onAIResponseLimit(),
        ),
      );
    });

    // AI图片生成限制
    on<_OnAIImageResponseLimit>((event, emit) {
      emit(
        state.copyWith(
          messageState: const MessageState.onAIImageResponseLimit(),
        ),
      );
    });

    // AI Max订阅要求
    on<_OnAIMaxRquired>((event, emit) {
      emit(
        state.copyWith(
          messageState: MessageState.onAIMaxRequired(event.message),
        ),
      );
    });

    // 本地AI初始化中
    on<_OnLocalAIInitializing>((event, emit) {
      emit(
        state.copyWith(
          messageState: const MessageState.onInitializingLocalAI(),
        ),
      );
    });

    // 接收元数据（引用源和进度）
    on<_ReceiveMetadata>((event, emit) {
      Log.debug("AI Steps: ${event.metadata.progress?.step}");
      emit(
        state.copyWith(
          sources: event.metadata.sources,
          progress: event.metadata.progress,
        ),
      );
    });

    // AI推荐的后续问题
    on<_OnAIFollowUp>((event, emit) {
      emit(
        state.copyWith(
          messageState: MessageState.aiFollowUp(event.followUpData),
        ),
      );
    });
  }

  /// 初始化流监听器
  /// 
  /// 监听AnswerStream的各种回调：
  /// - onData: 流式文本更新
  /// - onError: 错误处理
  /// - onAIResponseLimit: AI回复频率限制
  /// - onAIImageResponseLimit: AI图片生成限制  
  /// - onMetadata: 元数据更新（引用源和进度）
  /// - onAIMaxRequired: AI Max订阅要求
  /// - onLocalAIInitializing: 本地AI初始化
  /// - onAIFollowUp: AI后续问题推荐
  void _initializeStreamListener() {
    if (state.stream != null) {
      state.stream!.listen(
        onData: (text) => _safeAdd(ChatAIMessageEvent.updateText(text)),
        onError: (error) =>
            _safeAdd(ChatAIMessageEvent.receiveError(error.toString())),
        onAIResponseLimit: () =>
            _safeAdd(const ChatAIMessageEvent.onAIResponseLimit()),
        onAIImageResponseLimit: () =>
            _safeAdd(const ChatAIMessageEvent.onAIImageResponseLimit()),
        onMetadata: (metadata) =>
            _safeAdd(ChatAIMessageEvent.receiveMetadata(metadata)),
        onAIMaxRequired: (message) {
          Log.info(message);
          _safeAdd(ChatAIMessageEvent.onAIMaxRequired(message));
        },
        onLocalAIInitializing: () =>
            _safeAdd(const ChatAIMessageEvent.onLocalAIInitializing()),
        onAIFollowUp: (data) {
          _safeAdd(ChatAIMessageEvent.onAIFollowUp(data));
        },
      );
    }
  }

  /// 检查初始流状态
  /// 
  /// 在初始化时检查流是否已经有错误或限制状态
  void _checkInitialStreamState() {
    if (state.stream != null) {
      if (state.stream!.aiLimitReached) {
        add(const ChatAIMessageEvent.onAIResponseLimit());
      } else if (state.stream!.error != null) {
        add(ChatAIMessageEvent.receiveError(state.stream!.error!));
      }
    }
  }

  /// 安全添加事件
  /// 
  /// 检查BLoC是否已关闭，避免在关闭后添加事件
  void _safeAdd(ChatAIMessageEvent event) {
    if (!isClosed) {
      add(event);
    }
  }
}

/// AI消息事件
/// 
/// 定义了AI消息可能触发的所有事件类型
@freezed
class ChatAIMessageEvent with _$ChatAIMessageEvent {
  /// 更新AI回复文本
  const factory ChatAIMessageEvent.updateText(String text) = _UpdateText;
  
  /// 接收错误信息
  const factory ChatAIMessageEvent.receiveError(String error) = _ReceiveError;
  
  /// 触发重试
  const factory ChatAIMessageEvent.retry() = _Retry;
  
  /// 重试结果
  const factory ChatAIMessageEvent.retryResult(String text) = _RetryResult;
  
  /// AI回复频率达到限制
  const factory ChatAIMessageEvent.onAIResponseLimit() = _OnAIResponseLimit;
  
  /// AI图片生成达到限制
  const factory ChatAIMessageEvent.onAIImageResponseLimit() =
      _OnAIImageResponseLimit;
  
  /// 需要AI Max订阅
  const factory ChatAIMessageEvent.onAIMaxRequired(String message) =
      _OnAIMaxRquired;
  
  /// 本地AI正在初始化
  const factory ChatAIMessageEvent.onLocalAIInitializing() =
      _OnLocalAIInitializing;
  
  /// 接收元数据（引用源和进度）
  const factory ChatAIMessageEvent.receiveMetadata(
    MetadataCollection metadata,
  ) = _ReceiveMetadata;
  
  /// AI推荐的后续问题
  const factory ChatAIMessageEvent.onAIFollowUp(
    AIFollowUpData followUpData,
  ) = _OnAIFollowUp;
}

/// AI消息状态
/// 
/// 包含AI消息的完整状态信息
@freezed
class ChatAIMessageState with _$ChatAIMessageState {
  const factory ChatAIMessageState({
    /// 回答流（可选）
    AnswerStream? stream,
    /// AI回复文本
    required String text,
    /// 消息状态（加载中、就绪、错误等）
    required MessageState messageState,
    /// 引用源列表
    required List<ChatMessageRefSource> sources,
    /// AI处理进度
    required AIChatProgress? progress,
  }) = _ChatAIMessageState;

  /// 创建初始状态
  /// 
  /// 参数：
  /// - text: 可以是字符串或AnswerStream
  /// - metadata: 元数据集合（包含引用源和进度）
  factory ChatAIMessageState.initial(
    dynamic text,
    MetadataCollection metadata,
  ) {
    return ChatAIMessageState(
      text: text is String ? text : "",
      stream: text is AnswerStream ? text : null,
      messageState: const MessageState.ready(),
      sources: metadata.sources,
      progress: metadata.progress,
    );
  }
}

/// 消息状态
/// 
/// 表示AI消息的不同状态
@freezed
class MessageState with _$MessageState {
  /// 错误状态
  const factory MessageState.onError(String error) = _Error;
  
  /// AI回复频率限制
  const factory MessageState.onAIResponseLimit() = _AIResponseLimit;
  
  /// AI图片生成限制
  const factory MessageState.onAIImageResponseLimit() = _AIImageResponseLimit;
  
  /// 需要AI Max订阅
  const factory MessageState.onAIMaxRequired(String message) = _AIMaxRequired;
  
  /// 本地AI初始化中
  const factory MessageState.onInitializingLocalAI() = _LocalAIInitializing;
  
  /// 就绪状态
  const factory MessageState.ready() = _Ready;
  
  /// 加载中
  const factory MessageState.loading() = _Loading;
  
  /// AI后续问题推荐
  const factory MessageState.aiFollowUp(AIFollowUpData followUpData) =
      _AIFollowUp;
}
