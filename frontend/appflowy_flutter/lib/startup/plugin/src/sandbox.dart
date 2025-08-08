import 'dart:collection';

import 'package:appflowy/plugins/blank/blank.dart';
import 'package:flutter/services.dart';

import '../plugin.dart';
import 'runner.dart';

/*
 * 插件沙箱
 * 
 * 插件系统的核心管理器，负责：
 * 1. 插件的注册和管理
 * 2. 插件实例的创建和缓存
 * 3. 插件配置的存储
 * 4. 插件运行环境的隔离
 * 
 * 设计模式：
 * - 单例模式：全局唯一的插件管理器
 * - 工厂模式：根据类型创建插件
 * - 沙箱模式：插件运行在受控环境中
 * 
 * 数据结构：
 * - LinkedHashMap保证插件注册顺序
 * - Map存储插件配置
 */
class PluginSandbox {
  PluginSandbox() {
    pluginRunner = PluginRunner();
  }

  /* 插件构建器映射表
   * 使用LinkedHashMap保持插件注册顺序
   * key: 插件类型
   * value: 对应的构建器
   */
  final LinkedHashMap<PluginType, PluginBuilder> _pluginBuilders =
      LinkedHashMap();
  
  /* 插件配置映射表
   * 存储每个插件的配置信息
   */
  final Map<PluginType, PluginConfig> _pluginConfigs =
      <PluginType, PluginConfig>{};
  
  /* 插件运行器
   * 管理插件的执行生命周期
   */
  late PluginRunner pluginRunner;

  /*
   * 获取插件类型在注册列表中的索引
   * 
   * 参数：
   * - pluginType: 要查找的插件类型
   * 
   * 返回：
   * - 插件在注册列表中的位置索引
   * 
   * 异常：
   * - PlatformException: 当插件类型未注册时抛出
   * 
   * 应用场景：
   * - 确定插件在UI中的显示顺序
   * - 导航到特定插件位置
   */
  int indexOf(PluginType pluginType) {
    final index =
        _pluginBuilders.keys.toList().indexWhere((ty) => ty == pluginType);
    if (index == -1) {
      throw PlatformException(
        code: '-1',
        message: "Can't find the flowy plugin type: $pluginType",
      );
    }
    return index;
  }

  /*
   * 构建插件实例
   * 
   * 根据插件类型和数据创建插件实例
   * 如果插件类型未注册，返回空白插件
   * 
   * 参数：
   * - pluginType: 插件类型
   * - data: 初始化数据
   * 
   * 返回：
   * - 对应的插件实例
   * 
   * 容错机制：
   * - 未注册的插件类型会返回空白插件
   * - 保证系统不会因为未知插件而崩溃
   */
  Plugin buildPlugin(PluginType pluginType, dynamic data) {
    final builder = _pluginBuilders[pluginType] ?? BlankPluginBuilder();
    return builder.build(data);
  }

  /*
   * 注册插件
   * 
   * 将插件构建器和配置注册到沙箱中
   * 
   * 参数：
   * - pluginType: 插件类型标识
   * - builder: 插件构建器
   * - config: 可选的插件配置
   * 
   * 注册策略：
   * - 同一类型只能注册一次
   * - 重复注册会被忽略
   * - 配置是可选的
   * 
   * 执行流程：
   * 1. 检查是否已注册
   * 2. 存储构建器
   * 3. 存储配置（如果提供）
   */
  void registerPlugin(
    PluginType pluginType,
    PluginBuilder builder, {
    PluginConfig? config,
  }) {
    if (_pluginBuilders.containsKey(pluginType)) {
      return;
    }
    _pluginBuilders[pluginType] = builder;

    if (config != null) {
      _pluginConfigs[pluginType] = config;
    }
  }

  /* 获取所有支持的插件类型列表 */
  List<PluginType> get supportPluginTypes => _pluginBuilders.keys.toList();

  /* 获取所有已注册的插件构建器 */
  List<PluginBuilder> get builders => _pluginBuilders.values.toList();

  /* 获取插件配置映射表 */
  Map<PluginType, PluginConfig> get pluginConfigs => _pluginConfigs;
}
