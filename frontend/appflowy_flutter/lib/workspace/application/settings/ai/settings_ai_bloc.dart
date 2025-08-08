import 'package:appflowy/plugins/ai_chat/application/ai_model_switch_listener.dart';
import 'package:appflowy/user/application/user_listener.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_ai_bloc.freezed.dart';

// AI模型全局激活标识符，用于标记当前全局使用的AI模型
// 这个常量作为对象ID传递给监听器，用于区分不同场景下的模型切换
const String aiModelsGlobalActiveModel = "global_active_model";

/// AI设置管理BLoC - 负责管理应用中的AI相关设置
/// 
/// 主要功能：
/// 1. AI模型选择和切换（支持多种AI模型：OpenAI、Claude、本地模型等）
/// 2. AI搜索索引开关控制（决定是否对文档内容建立搜索索引）
/// 3. 工作区AI设置同步（与后端同步工作区级别的AI配置）
/// 4. 用户配置监听（监听用户配置变化并更新UI）
/// 
/// 设计思想：
/// - 采用事件驱动架构，通过事件触发状态更新
/// - 使用监听器模式实时感知后端配置变化
/// - 将AI设置与工作区绑定，支持不同工作区使用不同AI配置
class SettingsAIBloc extends Bloc<SettingsAIEvent, SettingsAIState> {
  SettingsAIBloc(
    this.userProfile,
    this.workspaceId,
  )   // 初始化用户监听器，监听用户配置变化
      : _userListener = UserListener(userProfile: userProfile),
        // 初始化AI模型切换监听器，监听全局模型切换事件
        _aiModelSwitchListener =
            AIModelSwitchListener(objectId: aiModelsGlobalActiveModel),
        super(
          SettingsAIState(
            userProfile: userProfile,
          ),
        ) {
    // 启动AI模型切换监听器
    // 当用户在任何地方切换AI模型时，这里会收到通知并重新加载模型列表
    _aiModelSwitchListener.start(
      onUpdateSelectedModel: (model) {
        // 避免在BLoC关闭后继续更新状态
        if (!isClosed) {
          _loadModelList();
        }
      },
    );
    _dispatch();
  }

  final UserListener _userListener; // 用户配置变化监听器
  final UserProfilePB userProfile; // 当前用户配置文件
  final String workspaceId; // 当前工作区ID
  final AIModelSwitchListener _aiModelSwitchListener; // AI模型切换监听器

  @override
  Future<void> close() async {
    // 清理资源：停止所有监听器，防止内存泄漏
    await _userListener.stop();
    await _aiModelSwitchListener.stop();
    return super.close();
  }

  /// 事件分发器 - 处理所有AI设置相关事件
  void _dispatch() {
    on<SettingsAIEvent>((event, emit) async {
      await event.when(
        // 初始化事件：启动监听器并加载初始数据
        started: () {
          // 启动用户监听器，监听两种变化：
          // 1. 用户配置文件更新（如用户信息变更）
          // 2. 工作区设置更新（如AI模型、搜索索引等设置变更）
          _userListener.start(
            onProfileUpdated: _onProfileUpdated,
            onUserWorkspaceSettingUpdated: (settings) {
              if (!isClosed) {
                add(SettingsAIEvent.didLoadWorkspaceSetting(settings));
              }
            },
          );
          _loadModelList(); // 加载可用的AI模型列表
          _loadUserWorkspaceSetting(); // 加载用户工作区设置
        },
        // 接收到用户配置文件更新事件
        didReceiveUserProfile: (userProfile) {
          emit(state.copyWith(userProfile: userProfile));
        },
        // 切换AI搜索索引功能开关
        // 搜索索引允许AI对文档内容进行语义搜索，提高搜索准确性
        toggleAISearch: () {
          // 先更新UI状态
          emit(
            state.copyWith(enableSearchIndexing: !state.enableSearchIndexing),
          );
          // 再同步到后端（注意：后端使用的是disable语义，需要取反）
          _updateUserWorkspaceSetting(
            disableSearchIndexing:
                !(state.aiSettings?.disableSearchIndexing ?? false),
          );
        },
        // 选择AI模型事件
        // 通过后端API更新全局选中的AI模型
        selectModel: (AIModelPB model) async {
          await AIEventUpdateSelectedModel(
            UpdateSelectedModelPB(
              source: aiModelsGlobalActiveModel, // 标识这是全局模型切换
              selectedModel: model,
            ),
          ).send();
        },
        // 加载工作区设置完成事件
        didLoadWorkspaceSetting: (WorkspaceSettingsPB settings) {
          emit(
            state.copyWith(
              aiSettings: settings,
              // 将后端的disable语义转换为前端的enable语义
              enableSearchIndexing: !settings.disableSearchIndexing,
            ),
          );
        },
        // 加载可用AI模型列表完成事件
        didLoadAvailableModels: (ModelSelectionPB models) {
          emit(
            state.copyWith(
              availableModels: models,
            ),
          );
        },
      );
    });
  }

  /// 更新用户工作区设置
  /// 
  /// 参数：
  /// - [disableSearchIndexing]: 是否禁用搜索索引
  /// - [model]: AI模型标识符
  Future<FlowyResult<void, FlowyError>> _updateUserWorkspaceSetting({
    bool? disableSearchIndexing,
    String? model,
  }) async {
    // 构建更新请求payload
    final payload = UpdateUserWorkspaceSettingPB(
      workspaceId: workspaceId,
    );
    // 只更新传入的参数，未传入的保持原值
    if (disableSearchIndexing != null) {
      payload.disableSearchIndexing = disableSearchIndexing;
    }
    if (model != null) {
      payload.aiModel = model;
    }
    // 发送更新请求到后端
    final result = await UserEventUpdateWorkspaceSetting(payload).send();
    // 记录操作结果用于调试
    result.fold(
      (ok) => Log.info('Update workspace setting success'),
      (err) => Log.error('Update workspace setting failed: $err'),
    );
    return result;
  }

  /// 处理用户配置文件更新回调
  void _onProfileUpdated(
    FlowyResult<UserProfilePB, FlowyError> userProfileOrFailed,
  ) =>
      userProfileOrFailed.fold(
        (profile) => add(SettingsAIEvent.didReceiveUserProfile(profile)),
        (err) => Log.error(err),
      );

  /// 加载可用的AI模型列表
  /// 从后端获取当前用户可以使用的所有AI模型
  void _loadModelList() {
    // 请求全局模型列表
    final payload = ModelSourcePB(source: aiModelsGlobalActiveModel);
    AIEventGetSettingModelSelection(payload).send().then((result) {
      result.fold((models) {
        if (!isClosed) {
          add(SettingsAIEvent.didLoadAvailableModels(models));
        }
      }, (err) {
        Log.error(err);
      });
    });
  }

  /// 加载用户工作区设置
  /// 获取当前工作区的AI相关配置
  void _loadUserWorkspaceSetting() {
    final payload = UserWorkspaceIdPB(workspaceId: workspaceId);
    UserEventGetWorkspaceSetting(payload).send().then((result) {
      result.fold((settings) {
        if (!isClosed) {
          add(SettingsAIEvent.didLoadWorkspaceSetting(settings));
        }
      }, (err) {
        Log.error(err);
      });
    });
  }
}

/// AI设置事件定义
/// 使用freezed生成不可变的事件类
@freezed
class SettingsAIEvent with _$SettingsAIEvent {
  const factory SettingsAIEvent.started() = _Started; // 初始化事件
  const factory SettingsAIEvent.didLoadWorkspaceSetting(
    WorkspaceSettingsPB settings,
  ) = _DidLoadWorkspaceSetting; // 工作区设置加载完成

  const factory SettingsAIEvent.toggleAISearch() = _toggleAISearch; // 切换AI搜索开关

  const factory SettingsAIEvent.selectModel(AIModelPB model) = _SelectAIModel; // 选择AI模型

  const factory SettingsAIEvent.didReceiveUserProfile(
    UserProfilePB newUserProfile,
  ) = _DidReceiveUserProfile; // 接收用户配置更新

  const factory SettingsAIEvent.didLoadAvailableModels(
    ModelSelectionPB models,
  ) = _DidLoadAvailableModels; // 可用模型加载完成
}

/// AI设置状态定义
/// 包含AI设置页面所需的所有状态数据
@freezed
class SettingsAIState with _$SettingsAIState {
  const factory SettingsAIState({
    required UserProfilePB userProfile, // 用户配置文件
    WorkspaceSettingsPB? aiSettings, // 工作区AI设置
    ModelSelectionPB? availableModels, // 可用的AI模型列表
    @Default(true) bool enableSearchIndexing, // 搜索索引开关（默认开启）
  }) = _SettingsAIState;
}
