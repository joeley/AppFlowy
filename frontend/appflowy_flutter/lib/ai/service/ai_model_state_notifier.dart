// AI相关导入
import 'package:appflowy/ai/ai.dart';
// 国际化键值
import 'package:appflowy/generated/locale_keys.g.dart';
// AI模型切换监听器
import 'package:appflowy/plugins/ai_chat/application/ai_model_switch_listener.dart';
// 本地LLM监听器
import 'package:appflowy/workspace/application/settings/ai/local_llm_listener.dart';
// 消息分发系统
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
// AI相关Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
// 结果包装器
import 'package:appflowy_result/appflowy_result.dart';
// 国际化工具
import 'package:easy_localization/easy_localization.dart';
// 跨平台工具
import 'package:universal_platform/universal_platform.dart';

/* AI模型状态变化回调函数类型
 * 
 * 当AI模型状态发生变化时调用
 * 参数：state - 新的AI模型状态
 */
typedef OnModelStateChangedCallback = void Function(AIModelState state);

/* 可用模型列表变化回调函数类型
 * 
 * 当可用的AI模型列表发生变化时调用
 * 参数：
 * - 第一个参数：可用模型列表
 * - 第二个参数：当前选中的模型（可能为null）
 */
typedef OnAvailableModelsChangedCallback = void Function(
  List<AIModelPB>,
  AIModelPB?,
);

/* AI模型状态类
 * 
 * 表示AI模型的当前状态信息
 * 
 * 用于UI层展示和交互控制：
 * - 输入框的提示文本
 * - 工具提示信息
 * - 是否可编辑状态
 * - 本地AI是否启用
 */
class AIModelState {
  const AIModelState({
    required this.type,
    required this.hintText,
    required this.tooltip,
    required this.isEditable,
    required this.localAIEnabled,
  });
  
  // AI类型（云端AI或本地AI）
  final AiType type;

  // 输入框显示的占位符/提示文本
  // 根据AI状态显示不同消息（已启用、初始化中、已禁用）
  final String hintText;

  // 可选的工具提示文本，悬停时显示
  // 提供关于AI当前状态的附加上下文信息
  // 当不需要显示工具提示时为null
  final String? tooltip;

  // 是否可编辑（输入框是否可用）
  final bool isEditable;
  
  // 本地AI是否已启用
  final bool localAIEnabled;
}

/* AI模型状态通知器
 * 
 * 管理AI模型的状态和配置，提供统一的状态通知机制
 * 
 * 核心职责：
 * 1. 监听本地AI服务状态变化（仅桌面端）
 * 2. 监听AI模型选择变化
 * 3. 计算和维护当前的AI状态
 * 4. 通知订阅者状态变化
 * 5. 管理可用模型列表
 * 
 * 状态管理：
 * - 本地AI状态：是否启用、是否就绪
 * - 模型选择状态：可用模型、选中模型
 * - 计算状态：综合考虑平台、配置等因素
 * 
 * 平台差异：
 * - 桌面端：支持本地AI，完整功能
 * - 移动端：仅支持云端AI，简化功能
 * 
 * 观察者模式：
 * - 支持多个回调函数订阅
 * - 状态变化时自动通知所有订阅者
 * - 提供注册和注销机制
 */
class AIModelStateNotifier {
  /* 构造函数
   * 
   * 初始化AI模型状态通知器
   * 
   * 参数：
   * - objectId: 关联的对象ID（文档、聊天等）
   * 
   * 初始化过程：
   * 1. 根据平台创建相应的监听器
   * 2. 启动监听
   * 3. 加载初始状态
   */
  AIModelStateNotifier({required this.objectId})
      : _localAIListener =
            UniversalPlatform.isDesktop ? LocalAIStateListener() : null,
        _aiModelSwitchListener = AIModelSwitchListener(objectId: objectId) {
    _startListening();
    _init();
  }

  // 关联的对象ID
  final String objectId;
  
  // 本地AI状态监听器（仅桌面端）
  final LocalAIStateListener? _localAIListener;
  
  // AI模型切换监听器
  final AIModelSwitchListener _aiModelSwitchListener;

  // 本地AI状态数据
  LocalAIPB? _localAIState;
  
  // 模型选择数据
  ModelSelectionPB? _modelSelection;

  // 当前计算出的AI状态
  AIModelState _currentState = _defaultState();
  
  // 可用的AI模型列表
  List<AIModelPB> _availableModels = [];
  
  // 当前选中的AI模型
  AIModelPB? _selectedModel;

  // 状态变化回调函数列表
  final List<OnModelStateChangedCallback> _stateChangedCallbacks = [];
  
  // 可用模型变化回调函数列表
  final List<OnAvailableModelsChangedCallback>
      _availableModelsChangedCallbacks = [];

  /// Starts platform-specific listeners
  void _startListening() {
    if (UniversalPlatform.isDesktop) {
      _localAIListener?.start(
        stateCallback: (state) async {
          _localAIState = state;
          _updateAll();
        },
      );
    }

    _aiModelSwitchListener.start(
      onUpdateSelectedModel: (model) async {
        _selectedModel = model;
        _updateAll();
        if (model.isLocal && UniversalPlatform.isDesktop) {
          await _loadLocalState();
          _updateAll();
        }
      },
    );
  }

  Future<void> _init() async {
    await Future.wait([
      if (UniversalPlatform.isDesktop) _loadLocalState(),
      _loadModelSelection(),
    ]);
    _updateAll();
  }

  /// Register callbacks for state or available-models changes
  void addListener({
    OnModelStateChangedCallback? onStateChanged,
    OnAvailableModelsChangedCallback? onAvailableModelsChanged,
  }) {
    if (onStateChanged != null) {
      _stateChangedCallbacks.add(onStateChanged);
    }
    if (onAvailableModelsChanged != null) {
      _availableModelsChangedCallbacks.add(onAvailableModelsChanged);
    }
  }

  /// Remove previously registered callbacks
  void removeListener({
    OnModelStateChangedCallback? onStateChanged,
    OnAvailableModelsChangedCallback? onAvailableModelsChanged,
  }) {
    if (onStateChanged != null) {
      _stateChangedCallbacks.remove(onStateChanged);
    }
    if (onAvailableModelsChanged != null) {
      _availableModelsChangedCallbacks.remove(onAvailableModelsChanged);
    }
  }

  Future<void> dispose() async {
    _stateChangedCallbacks.clear();
    _availableModelsChangedCallbacks.clear();
    await _localAIListener?.stop();
    await _aiModelSwitchListener.stop();
  }

  /// Returns current AIModelState
  AIModelState getState() => _currentState;

  /// Returns available models and the selected model
  (List<AIModelPB>, AIModelPB?) getModelSelection() =>
      (_availableModels, _selectedModel);

  void _updateAll() {
    _currentState = _computeState();
    for (final cb in _stateChangedCallbacks) {
      cb(_currentState);
    }
    for (final cb in _availableModelsChangedCallbacks) {
      cb(_availableModels, _selectedModel);
    }
  }

  Future<void> _loadModelSelection() async {
    await AIEventGetSourceModelSelection(
      ModelSourcePB(source: objectId),
    ).send().fold(
      (ms) {
        _modelSelection = ms;
        _availableModels = ms.models;
        _selectedModel = ms.selectedModel;
      },
      (e) => Log.error("Failed to fetch models: \$e"),
    );
  }

  Future<void> _loadLocalState() async {
    await AIEventGetLocalAIState().send().fold(
          (s) => _localAIState = s,
          (e) => Log.error("Failed to fetch local AI state: \$e"),
        );
  }

  static AIModelState _defaultState() => AIModelState(
        type: AiType.cloud,
        hintText: LocaleKeys.chat_inputMessageHint.tr(),
        tooltip: null,
        isEditable: true,
        localAIEnabled: false,
      );

  /// Core logic computing the state from local and selection data
  AIModelState _computeState() {
    if (UniversalPlatform.isMobile) return _defaultState();

    if (_modelSelection == null || _localAIState == null) {
      return _defaultState();
    }

    if (!_selectedModel!.isLocal) {
      return _defaultState();
    }

    final enabled = _localAIState!.enabled;
    final running = _localAIState!.isReady;
    final hintKey = enabled
        ? (running
            ? LocaleKeys.chat_inputLocalAIMessageHint
            : LocaleKeys.settings_aiPage_keys_localAIInitializing)
        : LocaleKeys.settings_aiPage_keys_localAIDisabled;
    final tooltipKey = enabled
        ? (running
            ? null
            : LocaleKeys.settings_aiPage_keys_localAINotReadyTextFieldPrompt)
        : LocaleKeys.settings_aiPage_keys_localAIDisabledTextFieldPrompt;

    return AIModelState(
      type: AiType.local,
      hintText: hintKey.tr(),
      tooltip: tooltipKey?.tr(),
      isEditable: running,
      localAIEnabled: enabled,
    );
  }
}

extension AIModelPBExtension on AIModelPB {
  bool get isDefault => name == 'Auto';
  String get i18n =>
      isDefault ? LocaleKeys.chat_switchModel_autoModel.tr() : name;
}
