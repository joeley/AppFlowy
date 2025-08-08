import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

// 国际化字符串键值
import 'package:appflowy/generated/locale_keys.g.dart';
// AI写作器相关实体
import 'package:appflowy/plugins/document/presentation/editor_plugins/ai/operations/ai_writer_entities.dart';
// 列表扩展工具
import 'package:appflowy/shared/list_extension.dart';
// 消息分发系统
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
// AI相关的Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart'
    hide CustomPromptDatabaseConfigurationPB;
// 数据库相关定义
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
// 结果包装器
import 'package:appflowy_result/appflowy_result.dart';
// 国际化工具
import 'package:easy_localization/easy_localization.dart';
// 64位整数类型
import 'package:fixnum/fixnum.dart' as fixnum;
// Flutter资源加载
import 'package:flutter/services.dart';

// AI实体定义
import 'ai_entities.dart';
// AI错误定义
import 'error.dart';

/* 本地AI流式传输状态枚举
 * 
 * 用于表示本地AI服务的可用状态
 */
enum LocalAIStreamingState {
  notReady,  // 未就绪状态（模型未加载或初始化中）
  disabled,  // 已禁用状态（用户关闭或系统限制）
}

/* AI仓储接口
 * 
 * 定义了AppFlowy AI功能的核心接口规范
 * 
 * 主要功能：
 * 1. 流式文本完成 - 支持实时AI对话和内容生成
 * 2. 提示词管理 - 内置提示词和数据库提示词
 * 3. 用户偏好管理 - 收藏提示词等个性化功能
 * 
 * 设计模式：
 * - 仓储模式：抽象数据访问层
 * - 策略模式：支持多种AI后端实现
 * - 观察者模式：流式数据处理
 */
abstract class AIRepository {
  /* 流式文本完成
   * 
   * AppFlowy AI功能的核心方法，支持实时AI对话
   * 
   * 参数说明：
   * - objectId: 关联的对象ID（文档、数据库等）
   * - text: 用户输入的文本内容
   * - format: 预定义格式（总结、翻译、改写等）
   * - promptId: 提示词ID，用于特定场景的AI响应
   * - sourceIds: 数据源ID列表，用于RAG（检索增强生成）
   * - history: 对话历史记录，维护上下文连续性
   * - completionType: 完成类型（对话、写作辅助等）
   * 
   * 回调函数：
   * - onStart: 开始生成时调用
   * - processMessage: 处理AI生成的消息内容
   * - processAssistMessage: 处理AI助手的辅助消息
   * - onEnd: 生成完成时调用
   * - onError: 错误处理回调
   * - onLocalAIStreamingStateChange: 本地AI状态变化回调
   * 
   * 返回值：
   * - (任务ID, 完成流)元组，失败时返回null
   */
  Future<(String, CompletionStream)?> streamCompletion({
    String? objectId,
    required String text,
    PredefinedFormat? format,
    String? promptId,
    List<String> sourceIds = const [],
    List<AiWriterRecord> history = const [],
    required CompletionTypePB completionType,
    required Future<void> Function() onStart,
    required Future<void> Function(String text) processMessage,
    required Future<void> Function(String text) processAssistMessage,
    required Future<void> Function() onEnd,
    required void Function(AIError error) onError,
    required void Function(LocalAIStreamingState state)
        onLocalAIStreamingStateChange,
  });

  /* 获取内置提示词
   * 
   * 从assets中加载预定义的提示词模板
   * 
   * 返回：提示词列表
   */
  Future<List<AiPrompt>> getBuiltInPrompts();

  /* 获取数据库提示词
   * 
   * 从用户数据库中获取自定义提示词
   * 
   * 参数：config - 数据库配置
   * 返回：提示词列表，失败时返回null
   */
  Future<List<AiPrompt>?> getDatabasePrompts(
    CustomPromptDatabaseConfigPB config,
  );

  /* 更新收藏提示词
   * 
   * 更新用户收藏的提示词列表
   * 
   * 参数：promptIds - 提示词ID列表
   */
  void updateFavoritePrompts(List<String> promptIds);
}

/* AppFlowy AI服务实现
 * 
 * AIRepository接口的具体实现，集成AppFlowy的AI功能
 * 
 * 核心特性：
 * 1. 与Rust后端的AI服务集成
 * 2. 支持流式响应处理
 * 3. 管理本地和云端AI模型
 * 4. 提供丰富的提示词系统
 * 5. 支持RAG（检索增强生成）
 * 
 * AI能力：
 * - 文本生成和完成
 * - 文档总结和改写
 * - 多语言翻译
 * - 代码生成和解释
 * - 基于上下文的智能问答
 * 
 * 技术实现：
 * - FFI与Rust AI引擎通信
 * - Protocol Buffers数据序列化
 * - 流式数据处理
 * - 异步并发处理
 */
class AppFlowyAIService implements AIRepository {
  @override
  Future<(String, CompletionStream)?> streamCompletion({
    String? objectId,
    required String text,
    PredefinedFormat? format,
    String? promptId,
    List<String> sourceIds = const [],
    List<AiWriterRecord> history = const [],
    required CompletionTypePB completionType,
    required Future<void> Function() onStart,
    required Future<void> Function(String text) processMessage,
    required Future<void> Function(String text) processAssistMessage,
    required Future<void> Function() onEnd,
    required void Function(AIError error) onError,
    required void Function(LocalAIStreamingState state)
        onLocalAIStreamingStateChange,
  }) async {
    final stream = AppFlowyCompletionStream(
      onStart: onStart,
      processMessage: processMessage,
      processAssistMessage: processAssistMessage,
      processError: onError,
      onLocalAIStreamingStateChange: onLocalAIStreamingStateChange,
      onEnd: onEnd,
    );

    final records = history.map((record) => record.toPB()).toList();

    final payload = CompleteTextPB(
      text: text,
      completionType: completionType,
      format: format?.toPB(),
      promptId: promptId,
      streamPort: fixnum.Int64(stream.nativePort),
      objectId: objectId ?? '',
      ragIds: [
        if (objectId != null) objectId,
        ...sourceIds,
      ].unique(),
      history: records,
    );

    return AIEventCompleteText(payload).send().fold(
      (task) => (task.taskId, stream),
      (error) {
        Log.error(error);
        return null;
      },
    );
  }

  @override
  Future<List<AiPrompt>> getBuiltInPrompts() async {
    final prompts = <AiPrompt>[];

    try {
      final jsonString =
          await rootBundle.loadString('assets/built_in_prompts.json');
      // final data = await rootBundle.load('assets/built_in_prompts.json');
      // final jsonString = utf8.decode(data.buffer.asUint8List());
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final promptJson = jsonData['prompts'] as List<dynamic>;
      prompts.addAll(
        promptJson
            .map((e) => AiPrompt.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      Log.error(e);
    }

    return prompts;
  }

  @override
  Future<List<AiPrompt>?> getDatabasePrompts(
    CustomPromptDatabaseConfigPB config,
  ) async {
    return DatabaseEventGetDatabaseCustomPrompts(config).send().fold(
      (databasePromptsPB) =>
          databasePromptsPB.items.map(AiPrompt.fromPB).toList(),
      (err) {
        Log.error(err);
        return null;
      },
    );
  }

  @override
  void updateFavoritePrompts(List<String> promptIds) {}
}

abstract class CompletionStream {
  CompletionStream({
    required this.onStart,
    required this.processMessage,
    required this.processAssistMessage,
    required this.processError,
    required this.onLocalAIStreamingStateChange,
    required this.onEnd,
  });

  final Future<void> Function() onStart;
  final Future<void> Function(String text) processMessage;
  final Future<void> Function(String text) processAssistMessage;
  final void Function(AIError error) processError;
  final void Function(LocalAIStreamingState state)
      onLocalAIStreamingStateChange;
  final Future<void> Function() onEnd;
}

class AppFlowyCompletionStream extends CompletionStream {
  AppFlowyCompletionStream({
    required super.onStart,
    required super.processMessage,
    required super.processAssistMessage,
    required super.processError,
    required super.onEnd,
    required super.onLocalAIStreamingStateChange,
  }) {
    _startListening();
  }

  final RawReceivePort _port = RawReceivePort();
  final StreamController<String> _controller = StreamController.broadcast();
  late StreamSubscription<String> _subscription;
  int get nativePort => _port.sendPort.nativePort;

  void _startListening() {
    _port.handler = _controller.add;
    _subscription = _controller.stream.listen(
      (event) async {
        await _handleEvent(event);
      },
    );
  }

  Future<void> dispose() async {
    await _controller.close();
    await _subscription.cancel();
    _port.close();
  }

  Future<void> _handleEvent(String event) async {
    // Check simple matches first
    if (event == AIStreamEventPrefix.aiResponseLimit) {
      processError(
        AIError(
          message: LocaleKeys.ai_textLimitReachedDescription.tr(),
          code: AIErrorCode.aiResponseLimitExceeded,
        ),
      );
      return;
    }

    if (event == AIStreamEventPrefix.aiImageResponseLimit) {
      processError(
        AIError(
          message: LocaleKeys.ai_imageLimitReachedDescription.tr(),
          code: AIErrorCode.aiImageResponseLimitExceeded,
        ),
      );
      return;
    }

    // Otherwise, parse out prefix:content
    if (event.startsWith(AIStreamEventPrefix.aiMaxRequired)) {
      processError(
        AIError(
          message: event.substring(AIStreamEventPrefix.aiMaxRequired.length),
          code: AIErrorCode.other,
        ),
      );
    } else if (event.startsWith(AIStreamEventPrefix.start)) {
      await onStart();
    } else if (event.startsWith(AIStreamEventPrefix.data)) {
      await processMessage(
        event.substring(AIStreamEventPrefix.data.length),
      );
    } else if (event.startsWith(AIStreamEventPrefix.comment)) {
      await processAssistMessage(
        event.substring(AIStreamEventPrefix.comment.length),
      );
    } else if (event.startsWith(AIStreamEventPrefix.finish)) {
      await onEnd();
    } else if (event.startsWith(AIStreamEventPrefix.localAIDisabled)) {
      onLocalAIStreamingStateChange(
        LocalAIStreamingState.disabled,
      );
    } else if (event.startsWith(AIStreamEventPrefix.localAINotReady)) {
      onLocalAIStreamingStateChange(
        LocalAIStreamingState.notReady,
      );
    } else if (event.startsWith(AIStreamEventPrefix.error)) {
      processError(
        AIError(
          message: event.substring(AIStreamEventPrefix.error.length),
          code: AIErrorCode.other,
        ),
      );
    } else {
      Log.debug('Unknown AI event: $event');
    }
  }
}
