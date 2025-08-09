/// AI提示词输入状态管理
/// 
/// 管理AI提示词输入的各种功能，包括：
/// - 预定义格式选择
/// - 文件附件管理
/// - 页面提及功能
/// - AI模型状态同步

import 'dart:async';

import 'package:appflowy/ai/service/ai_model_state_notifier.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ai_entities.dart';

part 'ai_prompt_input_bloc.freezed.dart';

/// AI提示词输入BLoC
/// 
/// 处理提示词输入相关的业务逻辑，包括：
/// - 管理输出格式设置
/// - 处理文件附件
/// - 管理页面提及
/// - 同步AI模型状态
class AIPromptInputBloc extends Bloc<AIPromptInputEvent, AIPromptInputState> {
  AIPromptInputBloc({
    required String objectId,
    required PredefinedFormat? predefinedFormat,
  })  : aiModelStateNotifier = AIModelStateNotifier(objectId: objectId),
        super(AIPromptInputState.initial(predefinedFormat)) {
    _dispatch();      // 注册事件处理器
    _startListening(); // 开始监听AI模型状态
    _init();          // 初始化状态
  }

  // AI模型状态通知器
  final AIModelStateNotifier aiModelStateNotifier;

  // 当前选中的提示词ID（可选）
  String? promptId;

  /// 释放资源
  @override
  Future<void> close() async {
    await aiModelStateNotifier.dispose();
    return super.close();
  }

  /// 注册事件处理器
  void _dispatch() {
    on<AIPromptInputEvent>(
      (event, emit) {
        event.when(
          // 更新AI模型状态
          updateAIState: (modelState) {
            emit(
              state.copyWith(
                modelState: modelState,
              ),
            );
          },
          // 切换显示预定义格式选项
          toggleShowPredefinedFormat: () {
            final showPredefinedFormats = !state.showPredefinedFormats;
            // 如果首次显示且没有选中格式，设置默认格式
            final predefinedFormat =
                showPredefinedFormats && state.predefinedFormat == null
                    ? PredefinedFormat(
                        imageFormat: ImageFormat.text,        // 默认仅文本
                        textFormat: TextFormat.paragraph,     // 默认段落格式
                      )
                    : null;
            emit(
              state.copyWith(
                showPredefinedFormats: showPredefinedFormats,
                predefinedFormat: predefinedFormat,
              ),
            );
          },
          // 更新预定义格式
          updatePredefinedFormat: (format) {
            // 仅在显示格式选项时才允许更新
            if (!state.showPredefinedFormats) {
              return;
            }
            emit(state.copyWith(predefinedFormat: format));
          },
          // 附加文件
          attachFile: (filePath, fileName) {
            // 创建文件对象
            final newFile = ChatFile.fromFilePath(filePath);
            if (newFile != null) {
              // 添加到附件列表
              emit(
                state.copyWith(
                  attachedFiles: [...state.attachedFiles, newFile],
                ),
              );
            }
          },
          // 移除文件
          removeFile: (file) {
            final files = [...state.attachedFiles];
            files.remove(file);
            emit(
              state.copyWith(
                attachedFiles: files,
              ),
            );
          },
          // 更新提及的页面
          updateMentionedViews: (views) {
            emit(
              state.copyWith(
                mentionedPages: views,
              ),
            );
          },
          // 更新提示词ID
          updatePromptId: (promptId) {
            this.promptId = promptId;
          },
          // 清空元数据
          clearMetadata: () {
            promptId = null;
            emit(
              state.copyWith(
                attachedFiles: [],   // 清空附件
                mentionedPages: [],  // 清空提及页面
              ),
            );
          },
        );
      },
    );
  }

  /// 开始监听AI模型状态变化
  void _startListening() {
    aiModelStateNotifier.addListener(
      onStateChanged: (modelState) {
        // 当AI模型状态变化时，更新本地状态
        add(
          AIPromptInputEvent.updateAIState(modelState),
        );
      },
    );
  }

  /// 初始化AI模型状态
  void _init() {
    // 获取当前的AI模型状态
    final modelState = aiModelStateNotifier.getState();
    add(
      AIPromptInputEvent.updateAIState(modelState),
    );
  }

  /// 消费元数据
  /// 
  /// 获取并清空所有附件和提及页面
  /// 用于发送提示词时携带相关上下文
  Map<String, dynamic> consumeMetadata() {
    // 收集所有元数据
    final metadata = {
      for (final file in state.attachedFiles) file.filePath: file,
      for (final page in state.mentionedPages) page.id: page,
    };

    // 如果有元数据且BLoC未关闭，清空它们
    if (metadata.isNotEmpty && !isClosed) {
      add(const AIPromptInputEvent.clearMetadata());
    }

    return metadata;
  }
}

/// AI提示词输入事件
/// 
/// 使用freezed生成的不可变事件类
@freezed
class AIPromptInputEvent with _$AIPromptInputEvent {
  // 更新AI模型状态
  const factory AIPromptInputEvent.updateAIState(
    AIModelState modelState,
  ) = _UpdateAIState;

  // 切换显示预定义格式选项
  const factory AIPromptInputEvent.toggleShowPredefinedFormat() =
      _ToggleShowPredefinedFormat;
  
  // 更新预定义格式
  const factory AIPromptInputEvent.updatePredefinedFormat(
    PredefinedFormat format,
  ) = _UpdatePredefinedFormat;
  
  // 附加文件
  const factory AIPromptInputEvent.attachFile(
    String filePath,
    String fileName,
  ) = _AttachFile;
  
  // 移除文件
  const factory AIPromptInputEvent.removeFile(ChatFile file) = _RemoveFile;
  
  // 更新提及的页面
  const factory AIPromptInputEvent.updateMentionedViews(List<ViewPB> views) =
      _UpdateMentionedViews;
  
  // 清空元数据
  const factory AIPromptInputEvent.clearMetadata() = _ClearMetadata;
  
  // 更新提示词ID
  const factory AIPromptInputEvent.updatePromptId(String promptId) =
      _UpdatePromptId;
}

/// AI提示词输入状态
/// 
/// 使用freezed生成的不可变状态类
@freezed
class AIPromptInputState with _$AIPromptInputState {
  const factory AIPromptInputState({
    // AI模型状态
    required AIModelState modelState,
    // 是否支持文件对话
    required bool supportChatWithFile,
    // 是否显示预定义格式选项
    required bool showPredefinedFormats,
    // 当前选中的预定义格式（可选）
    required PredefinedFormat? predefinedFormat,
    // 附件文件列表
    required List<ChatFile> attachedFiles,
    // 提及的页面列表
    required List<ViewPB> mentionedPages,
  }) = _AIPromptInputState;

  /// 初始状态工厂方法
  /// 
  /// 根据提供的预定义格式创建初始状态
  factory AIPromptInputState.initial(PredefinedFormat? format) =>
      AIPromptInputState(
        modelState: AIModelState(
          type: AiType.cloud,        // 默认使用云端AI
          isEditable: true,          // 允许编辑
          hintText: '',              // 无提示文本
          localAIEnabled: false,     // 本地AI未启用
          tooltip: null,             // 无工具提示
        ),
        supportChatWithFile: false,             // 默认不支持文件对话
        showPredefinedFormats: format != null,  // 有格式时显示选项
        predefinedFormat: format,
        attachedFiles: [],                      // 初始无附件
        mentionedPages: [],                     // 初始无提及页面
      );
}
