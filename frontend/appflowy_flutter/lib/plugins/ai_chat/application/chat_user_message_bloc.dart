import 'package:appflowy/plugins/ai_chat/application/chat_message_stream.dart';
import 'package:appflowy_backend/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_user_message_bloc.freezed.dart';

/// 用户消息状态管理器 - 负责管理用户发送的聊天消息
/// 
/// 主要功能：
/// 1. 实时更新用户消息文本（流式传输）
/// 2. 跟踪消息ID
/// 3. 监听文件索引进度
/// 4. 管理问题消息状态（索引中、完成等）
/// 
/// 设计思想：
/// - 支持流式消息更新，实现打字机效果
/// - 通过QuestionStream接收实时数据
/// - 状态管理包括文本内容、消息ID和处理状态
/// - 防止在BLoC关闭后更新状态
class ChatUserMessageBloc
    extends Bloc<ChatUserMessageEvent, ChatUserMessageState> {
  ChatUserMessageBloc({
    required this.questionStream,
    required String text,
  }) : super(ChatUserMessageState.initial(text)) {
    _dispatch();
    _startListening();
  }

  /// 问题流 - 用于接收实时的消息更新和状态变化
  final QuestionStream? questionStream;

  /// 注册事件处理器
  /// 
  /// 处理四种事件类型：
  /// - updateText: 更新消息文本
  /// - updateMessageId: 更新消息ID
  /// - receiveError: 接收错误（当前未处理）
  /// - updateQuestionState: 更新问题处理状态
  void _dispatch() {
    on<ChatUserMessageEvent>(
      (event, emit) {
        event.when(
          updateText: (String text) {
            emit(state.copyWith(text: text));
          },
          updateMessageId: (String messageId) {
            emit(state.copyWith(messageId: messageId));
          },
          receiveError: (String error) {
            // 错误事件当前未处理，可扩展用于显示错误状态
          },
          updateQuestionState: (QuestionMessageState newState) {
            emit(state.copyWith(messageState: newState));
          },
        );
      },
    );
  }

  /// 开始监听问题流
  /// 
  /// 监听多种回调事件：
  /// - onData: 接收文本更新（流式传输）
  /// - onMessageId: 接收消息ID
  /// - onError: 处理错误
  /// - onFileIndexStart/End/Fail: 文件索引状态
  /// - onIndexStart/End: 整体索引进度
  /// - onDone: 处理完成
  /// 
  /// 所有事件都会检查BLoC是否已关闭，避免内存泄漏
  void _startListening() {
    questionStream?.listen(
      onData: (text) {
        // 接收流式文本更新
        if (!isClosed) {
          add(ChatUserMessageEvent.updateText(text));
        }
      },
      onMessageId: (messageId) {
        // 更新消息ID，用于后续操作
        if (!isClosed) {
          add(ChatUserMessageEvent.updateMessageId(messageId));
        }
      },
      onError: (error) {
        // 处理流错误
        if (!isClosed) {
          add(ChatUserMessageEvent.receiveError(error.toString()));
        }
      },
      onFileIndexStart: (indexName) {
        // 单个文件索引开始
        Log.debug("index start: $indexName");
      },
      onFileIndexEnd: (indexName) {
        // 单个文件索引完成
        Log.info("index end: $indexName");
      },
      onFileIndexFail: (indexName) {
        // 单个文件索引失败
        Log.debug("index fail: $indexName");
      },
      onIndexStart: () {
        // 整体索引过程开始
        if (!isClosed) {
          add(
            const ChatUserMessageEvent.updateQuestionState(
              QuestionMessageState.indexStart(),
            ),
          );
        }
      },
      onIndexEnd: () {
        // 整体索引过程结束
        if (!isClosed) {
          add(
            const ChatUserMessageEvent.updateQuestionState(
              QuestionMessageState.indexEnd(),
            ),
          );
        }
      },
      onDone: () {
        // 所有处理完成
        if (!isClosed) {
          add(
            const ChatUserMessageEvent.updateQuestionState(
              QuestionMessageState.finish(),
            ),
          );
        }
      },
    );
  }
}

/// 用户消息事件
/// 
/// 定义了用户消息可能触发的所有事件类型
@freezed
class ChatUserMessageEvent with _$ChatUserMessageEvent {
  /// 更新消息文本内容
  const factory ChatUserMessageEvent.updateText(String text) = _UpdateText;
  
  /// 更新问题处理状态（索引中、完成等）
  const factory ChatUserMessageEvent.updateQuestionState(
    QuestionMessageState newState,
  ) = _UpdateQuestionState;
  
  /// 更新消息ID
  const factory ChatUserMessageEvent.updateMessageId(String messageId) =
      _UpdateMessageId;
  
  /// 接收错误信息
  const factory ChatUserMessageEvent.receiveError(String error) = _ReceiveError;
}

/// 用户消息状态
/// 
/// 包含用户消息的完整状态信息
@freezed
class ChatUserMessageState with _$ChatUserMessageState {
  const factory ChatUserMessageState({
    /// 消息文本内容
    required String text,
    /// 消息ID（可选）
    required String? messageId,
    /// 消息处理状态
    required QuestionMessageState messageState,
  }) = _ChatUserMessageState;

  /// 创建初始状态
  factory ChatUserMessageState.initial(String message) => ChatUserMessageState(
        text: message,
        messageId: null,
        messageState: const QuestionMessageState.finish(),
      );
}

/// 问题消息状态
/// 
/// 表示问题处理的不同阶段，主要用于文件索引过程
@freezed
class QuestionMessageState with _$QuestionMessageState {
  /// 开始索引特定文件
  const factory QuestionMessageState.indexFileStart(String fileName) =
      _IndexFileStart;
  
  /// 完成索引特定文件
  const factory QuestionMessageState.indexFileEnd(String fileName) =
      _IndexFileEnd;
  
  /// 索引特定文件失败
  const factory QuestionMessageState.indexFileFail(String fileName) =
      _IndexFileFail;

  /// 开始整体索引过程
  const factory QuestionMessageState.indexStart() = _IndexStart;
  
  /// 结束整体索引过程
  const factory QuestionMessageState.indexEnd() = _IndexEnd;
  
  /// 所有处理完成
  const factory QuestionMessageState.finish() = _Finish;
}

/// QuestionMessageState扩展方法
extension QuestionMessageStateX on QuestionMessageState {
  /// 判断是否处理完成
  bool get isFinish => this is _Finish;
}
