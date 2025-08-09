import 'dart:convert';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:collection/collection.dart';

typedef FeatureFlagMap = Map<FeatureFlag, bool>;

/// 功能开关管理系统
/// 
/// 用于控制应用前端功能的启用/禁用状态。
/// 允许在运行时动态控制功能的可见性，便于逐步发布新功能或进行A/B测试。
/// 
/// 主要用途：
/// 1. **渐进式发布**：新功能可以先隐藏，待稳定后再启用
/// 2. **版本控制**：不同版本可以启用不同的功能集
/// 3. **紧急关闭**：出现问题时可以快速关闭某个功能
/// 4. **A/B测试**：可以为不同用户组启用不同功能
/// 
/// 存储机制：
/// - 使用键值存储持久化功能开关状态
/// - 支持JSON序列化/反序列化
/// - 提供默认值机制
enum FeatureFlag {
  /// 协作工作区功能
  /// 启用后可以在应用左上角看到工作区列表和工作区设置
  collaborativeWorkspace,

  /// 成员设置功能
  /// 启用后可以在设置页面看到成员管理选项
  membersSettings,

  /// 文档同步功能
  /// 启用后文档会实时同步来自服务器的事件
  syncDocument,

  /// 数据库同步功能
  /// 启用后数据库中会显示协作者信息
  syncDatabase,

  /// 搜索功能
  /// 控制命令面板和搜索按钮的可见性
  search,

  /// 计费和订阅功能
  /// 控制设置中是否显示计费和订阅选项
  planBilling,

  /// 空间设计功能
  /// 新的UI设计系统
  spaceDesign,

  /// 内联子页面提及功能
  /// 允许在文档中提及和嵌入子页面
  inlineSubPageMention,

  /// 共享区域功能
  /// 控制共享内容区域的显示
  sharedSection,

  /// 未知标志
  /// 用于忽略冲突的功能标志
  unknown;

  /// 初始化功能开关系统
  /// 
  /// 从键值存储中加载已保存的功能开关状态
  /// 如果没有保存的状态，使用默认值
  static Future<void> initialize() async {
    final values = await getIt<KeyValueStorage>().getWithFormat<FeatureFlagMap>(
          KVKeys.featureFlag,
          (value) => Map.from(jsonDecode(value)).map(
            (key, value) {
              // 将字符串键转换为枚举
              final k = FeatureFlag.values.firstWhereOrNull(
                    (e) => e.name == key,
                  ) ??
                  FeatureFlag.unknown;
              return MapEntry(k, value as bool);
            },
          ),
        ) ??
        {};

    // 合并默认值和已保存的值
    _values = {
      ...{for (final flag in FeatureFlag.values) flag: false}, // 默认全部关闭
      ...values, // 覆盖已保存的值
    };
  }

  /// 获取所有功能开关数据的只读视图
  static UnmodifiableMapView<FeatureFlag, bool> get data =>
      UnmodifiableMapView(_values);

  /// 启用当前功能
  Future<void> turnOn() async {
    await update(true);
  }

  /// 禁用当前功能
  Future<void> turnOff() async {
    await update(false);
  }

  /// 更新功能开关状态
  /// 
  /// 同时更新内存缓存和持久化存储
  Future<void> update(bool value) async {
    _values[this] = value;

    // 持久化到键值存储
    await getIt<KeyValueStorage>().set(
      KVKeys.featureFlag,
      jsonEncode(
        _values.map((key, value) => MapEntry(key.name, value)),
      ),
    );
  }

  /// 清除所有功能开关设置
  static Future<void> clear() async {
    _values = {};
    await getIt<KeyValueStorage>().remove(KVKeys.featureFlag);
  }

  /// 检查功能是否启用
  /// 
  /// 判断逻辑：
  /// 1. 已发布功能默认启用（根据版本号判断）
  /// 2. 检查内存缓存中的值
  /// 3. 返回功能的默认状态
  bool get isOn {
    // 已发布的功能默认启用
    if ([
      FeatureFlag.planBilling,
      FeatureFlag.spaceDesign,        // 0.6.1版本发布
      FeatureFlag.search,              // 0.5.9版本发布
      FeatureFlag.collaborativeWorkspace,  // 0.5.6版本发布
      FeatureFlag.membersSettings,
      FeatureFlag.syncDatabase,       // 0.5.4版本发布
      FeatureFlag.syncDocument,
      FeatureFlag.inlineSubPageMention,
    ].contains(this)) {
      return true;
    }

    // 检查用户自定义的值
    if (_values.containsKey(this)) {
      return _values[this]!;
    }

    // 默认状态
    switch (this) {
      case FeatureFlag.planBilling:
      case FeatureFlag.search:
      case FeatureFlag.syncDocument:
      case FeatureFlag.syncDatabase:
      case FeatureFlag.spaceDesign:
      case FeatureFlag.inlineSubPageMention:
      case FeatureFlag.collaborativeWorkspace:
      case FeatureFlag.membersSettings:
        return true;  // 默认启用
      case FeatureFlag.sharedSection:
      case FeatureFlag.unknown:
        return false; // 默认禁用
    }
  }

  /// 获取功能描述
  /// 
  /// 返回功能的详细说明，用于调试和管理界面
  String get description {
    switch (this) {
      case FeatureFlag.collaborativeWorkspace:
        return '启用后可在应用左上角看到工作区列表和工作区设置';
      case FeatureFlag.membersSettings:
        return '启用后可在设置页面看到成员管理选项';
      case FeatureFlag.syncDocument:
        return '启用后文档将实时同步';
      case FeatureFlag.syncDatabase:
        return '启用后数据库中将显示协作者';
      case FeatureFlag.search:
        return '启用后命令面板和搜索按钮将可用';
      case FeatureFlag.planBilling:
        return '启用后设置中将显示计费和订阅页面';
      case FeatureFlag.spaceDesign:
        return '启用后空间设计功能将可用';
      case FeatureFlag.inlineSubPageMention:
        return '启用后内联子页面提及功能将可用';
      case FeatureFlag.sharedSection:
        return '启用后共享区域将可用';
      case FeatureFlag.unknown:
        return '';
    }
  }

  /// 生成功能开关的唯一键名
  String get key => 'appflowy_feature_flag_${toString()}';
}

/// 全局功能开关存储
FeatureFlagMap _values = {};
