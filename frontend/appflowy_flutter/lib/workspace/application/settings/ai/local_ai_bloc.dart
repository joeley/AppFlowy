import 'dart:async';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_llm_listener.dart';

part 'local_ai_bloc.freezed.dart';

/// 本地AI插件管理BLoC - 负责管理本地运行的AI模型
/// 
/// 主要功能：
/// 1. 本地AI服务状态管理（启用/禁用、就绪状态）
/// 2. 资源检查（检测本地是否有足够资源运行AI）
/// 3. 本地AI服务控制（启动、停止、重启）
/// 4. 实时状态监听（通过Rust后端的事件流）
/// 
/// 设计思想：
/// - 支持完全离线的AI功能，数据不会发送到云端
/// - 通过资源检查确保用户设备能够运行本地模型
/// - 提供实时状态反馈，让用户了解本地AI的运行状态
class LocalAiPluginBloc extends Bloc<LocalAiPluginEvent, LocalAiPluginState> {
  LocalAiPluginBloc() : super(const LoadingLocalAiPluginState()) { // 初始状态为加载中
    on<LocalAiPluginEvent>(_handleEvent);
    _startListening(); // 启动状态监听器
    _getLocalAiState(); // 获取初始状态
  }

  final listener = LocalAIStateListener(); // 本地AI状态监听器

  @override
  Future<void> close() async {
    // 清理资源：停止监听器
    await listener.stop();
    return super.close();
  }

  /// 事件处理器 - 处理所有本地AI相关事件
  Future<void> _handleEvent(
    LocalAiPluginEvent event,
    Emitter<LocalAiPluginState> emit,
  ) async {
    // 防止在BLoC关闭后处理事件
    if (isClosed) {
      return;
    }

    await event.when(
      // 接收到AI状态更新事件
      didReceiveAiState: (aiState) {
        emit(
          LocalAiPluginState.ready(
            isEnabled: aiState.enabled, // 是否启用本地AI
            isReady: aiState.isReady, // AI服务是否就绪
            lackOfResource: // 缺少的资源信息（如内存、磁盘空间等）
                aiState.hasLackOfResource() ? aiState.lackOfResource : null,
          ),
        );
      },
      // 接收到资源不足通知
      didReceiveLackOfResources: (resources) {
        // 只在ready状态下更新资源信息
        state.maybeMap(
          ready: (readyState) {
            emit(readyState.copyWith(lackOfResource: resources));
          },
          orElse: () {},
        );
      },
      // 切换本地AI启用/禁用状态
      toggle: () async {
        emit(LocalAiPluginState.loading()); // 先显示加载状态
        // 发送切换请求到后端
        await AIEventToggleLocalAI().send().fold(
          (aiState) {
            // 切换成功后，触发状态更新事件
            if (!isClosed) {
              add(LocalAiPluginEvent.didReceiveAiState(aiState));
            }
          },
          Log.error,
        );
      },
      // 重启本地AI服务
      // 用于解决AI服务异常或更新配置后需要重启的情况
      restart: () async {
        emit(LocalAiPluginState.loading());
        await AIEventRestartLocalAI().send();
      },
    );
  }

  /// 启动本地AI状态监听
  /// 监听两种类型的回调：状态变化和资源变化
  void _startListening() {
    listener.start(
      // AI状态变化回调（启用/禁用、就绪状态等）
      stateCallback: (pluginState) {
        if (!isClosed) {
          add(LocalAiPluginEvent.didReceiveAiState(pluginState));
        }
      },
      // 资源不足回调（内存、CPU、磁盘等资源不足时触发）
      resourceCallback: (data) {
        if (!isClosed) {
          add(LocalAiPluginEvent.didReceiveLackOfResources(data));
        }
      },
    );
  }

  /// 获取本地AI的初始状态
  /// 在BLoC初始化时调用，用于同步当前状态
  void _getLocalAiState() {
    AIEventGetLocalAIState().send().fold(
      (aiState) {
        if (!isClosed) {
          add(LocalAiPluginEvent.didReceiveAiState(aiState));
        }
      },
      Log.error,
    );
  }
}

/// 本地AI插件事件定义
@freezed
class LocalAiPluginEvent with _$LocalAiPluginEvent {
  // 接收到AI状态更新
  const factory LocalAiPluginEvent.didReceiveAiState(LocalAIPB aiState) =
      _DidReceiveAiState;
  // 接收到资源不足通知
  const factory LocalAiPluginEvent.didReceiveLackOfResources(
    LackOfAIResourcePB resources,
  ) = _DidReceiveLackOfResources;
  const factory LocalAiPluginEvent.toggle() = _Toggle; // 切换启用/禁用
  const factory LocalAiPluginEvent.restart() = _Restart; // 重启服务
}

/// 本地AI插件状态定义
/// 使用sealed class模式，确保状态的完整性
@freezed
class LocalAiPluginState with _$LocalAiPluginState {
  const LocalAiPluginState._();

  // 就绪状态 - 包含本地AI的完整状态信息
  const factory LocalAiPluginState.ready({
    required bool isEnabled, // 是否启用本地AI
    required bool isReady, // AI服务是否就绪可用
    required LackOfAIResourcePB? lackOfResource, // 缺少的资源信息
  }) = ReadyLocalAiPluginState;

  // 加载状态 - 正在启动、停止或重启AI服务
  const factory LocalAiPluginState.loading() = LoadingLocalAiPluginState;

  /// 获取本地AI是否启用
  /// 只有在ready状态下才返回实际值，其他状态返回false
  bool get isEnabled {
    return maybeWhen(
      ready: (isEnabled, _, ___) => isEnabled,
      orElse: () => false,
    );
  }

  /// 是否显示状态指示器
  /// 当AI服务就绪或存在资源问题时显示指示器，让用户了解当前状态
  bool get showIndicator {
    return maybeWhen(
      ready: (isEnabled, isReady, lackOfResource) =>
          isReady || lackOfResource != null,
      orElse: () => false,
    );
  }
}
