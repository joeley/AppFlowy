/// AI模型选择状态管理
/// 
/// 管理AI模型的选择，包括可用模型列表和当前选中的模型
/// 支持多种模型（如GPT-3.5、GPT-4、Claude等）的动态切换

import 'dart:async';

import 'package:appflowy/ai/service/ai_model_state_notifier.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pbserver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'select_model_bloc.freezed.dart';

/// AI模型选择BLoC
/// 
/// 处理AI模型选择的业务逻辑，包括：
/// - 管理可用模型列表
/// - 处理模型选择事件
/// - 与后端同步模型选择状态
class SelectModelBloc extends Bloc<SelectModelEvent, SelectModelState> {
  SelectModelBloc({
    required AIModelStateNotifier aiModelStateNotifier,
  })  : _aiModelStateNotifier = aiModelStateNotifier,
        super(SelectModelState.initial(aiModelStateNotifier)) {
    // 注册事件处理器
    on<SelectModelEvent>(
      (event, emit) {
        event.when(
          // 处理选择模型事件
          selectModel: (model) {
            // 向后端发送更新选中模型的请求
            AIEventUpdateSelectedModel(
              UpdateSelectedModelPB(
                source: _aiModelStateNotifier.objectId,  // 数据源标识
                selectedModel: model,                    // 新选中的模型
              ),
            ).send();

            // 更新本地状态
            emit(state.copyWith(selectedModel: model));
          },
          // 处理加载模型列表事件
          didLoadModels: (models, selectedModel) {
            emit(
              SelectModelState(
                models: models,                // 可用模型列表
                selectedModel: selectedModel,  // 当前选中的模型
              ),
            );
          },
        );
      },
    );

    // 监听AI模型状态变化
    _aiModelStateNotifier.addListener(
      onAvailableModelsChanged: _onAvailableModelsChanged,
    );
  }

  // AI模型状态通知器，用于监听模型变化
  final AIModelStateNotifier _aiModelStateNotifier;

  /// 释放资源
  /// 
  /// 移除监听器并关闭BLoC
  @override
  Future<void> close() async {
    // 移除模型变化监听器
    _aiModelStateNotifier.removeListener(
      onAvailableModelsChanged: _onAvailableModelsChanged,
    );
    await super.close();
  }

  /// 处理可用模型变化
  /// 
  /// 当可用模型列表或选中模型变化时被调用
  /// 通过添加事件更新UI状态
  void _onAvailableModelsChanged(
    List<AIModelPB> models,
    AIModelPB? selectedModel,
  ) {
    // 仅在BLoC未关闭时添加事件
    if (!isClosed) {
      add(SelectModelEvent.didLoadModels(models, selectedModel));
    }
  }
}

/// 模型选择事件
/// 
/// 使用freezed生成的不可变事件类
@freezed
class SelectModelEvent with _$SelectModelEvent {
  // 选择模型事件：用户选择了一个新的AI模型
  const factory SelectModelEvent.selectModel(
    AIModelPB model,
  ) = _SelectModel;

  // 加载模型事件：模型列表已加载完成
  const factory SelectModelEvent.didLoadModels(
    List<AIModelPB> models,      // 可用模型列表
    AIModelPB? selectedModel,    // 当前选中的模型（可选）
  ) = _DidLoadModels;
}

/// 模型选择状态
/// 
/// 使用freezed生成的不可变状态类
@freezed
class SelectModelState with _$SelectModelState {
  const factory SelectModelState({
    // 可用的AI模型列表
    required List<AIModelPB> models,
    // 当前选中的模型（可选）
    required AIModelPB? selectedModel,
  }) = _SelectModelState;

  /// 初始状态工厂方法
  /// 
  /// 从通知器获取初始模型选择状态
  factory SelectModelState.initial(AIModelStateNotifier notifier) {
    // 获取当前的模型选择状态
    final (models, selectedModel) = notifier.getModelSelection();
    return SelectModelState(
      models: models,
      selectedModel: selectedModel,
    );
  }
}
