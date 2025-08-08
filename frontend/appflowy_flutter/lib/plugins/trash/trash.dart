import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/workspace/presentation/home/home_stack.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pbenum.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flutter/material.dart';

import 'trash_page.dart';

export "./src/sizes.dart";
export "./src/trash_cell.dart";
export "./src/trash_header.dart";

/*
 * 垃圾桶插件构建器
 * 
 * 负责创建垃圾桶插件实例
 * 定义插件的基本属性
 * 
 * 设计思想：
 * - 使用插件系统统一管理功能模块
 * - 垃圾桶作为特殊的插件类型
 * - 不需要与文档关联
 */
class TrashPluginBuilder extends PluginBuilder {
  @override
  Plugin build(dynamic data) {
    return TrashPlugin(pluginType: pluginType);
  }

  @override
  String get menuName => "TrashPB";

  @override
  FlowySvgData get icon => FlowySvgs.trash_m;

  @override
  PluginType get pluginType => PluginType.trash;

  @override
  ViewLayoutPB get layoutType => ViewLayoutPB.Document;
}

/*
 * 垃圾桶插件配置
 * 
 * creatable = false：不能创建多个垃圾桶实例
 * 垃圾桶是全局唯一的功能
 */
class TrashPluginConfig implements PluginConfig {
  @override
  bool get creatable => false;
}

/*
 * 垃圾桶插件
 * 
 * 核心功能：
 * 1. 管理已删除的文档和页面
 * 2. 支持恢复和永久删除
 * 3. 提供统一的删除项管理界面
 * 
 * 插件ID：TrashStack
 * - 固定的ID确保全局唯一性
 * - Stack后缀表示堆叠式存储
 */
class TrashPlugin extends Plugin {
  TrashPlugin({required PluginType pluginType}) : _pluginType = pluginType;

  final PluginType _pluginType;

  @override
  PluginWidgetBuilder get widgetBuilder => TrashPluginDisplay();

  @override
  PluginId get id => "TrashStack";

  @override
  PluginType get pluginType => _pluginType;
}

/*
 * 垃圾桶插件显示构建器
 * 
 * 负责构建垃圾桶的UI组件
 * 
 * UI组成：
 * - 左侧栏项：显示"垃圾桶"文本
 * - 标签栏项：复用左侧栏样式
 * - 右侧栏项：null（不需要额外操作）
 * - 主体内容：TrashPage组件
 * 
 * 导航配置：
 * - 作为单独的导航项
 * - 固定的ViewKey确保单例
 */
class TrashPluginDisplay extends PluginWidgetBuilder {
  @override
  String? get viewName => LocaleKeys.trash_text.tr();

  @override
  Widget get leftBarItem => FlowyText.medium(LocaleKeys.trash_text.tr());

  @override
  Widget tabBarItem(String pluginId, [bool shortForm = false]) => leftBarItem;

  @override
  Widget? get rightBarItem => null;

  @override
  Widget buildWidget({
    required PluginContext context,
    required bool shrinkWrap,
    Map<String, dynamic>? data,
  }) =>
      const TrashPage(key: ValueKey('TrashPage'));

  @override
  List<NavigationItem> get navigationItems => [this];
}
