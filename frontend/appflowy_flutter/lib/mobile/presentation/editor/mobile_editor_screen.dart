// 移动端编辑器屏幕 - 文档编辑界面的入口组件
// 导入移动端基础页面组件，提供统一的页面结构
import 'package:appflowy/mobile/presentation/base/mobile_view_page.dart';
// 导入图标表情选择器相关标签页类型
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
// 导入后端视图数据结构定义
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// Flutter核心UI框架
import 'package:flutter/material.dart';

/// 移动端文档屏幕组件
/// 这是文档编辑功能的主入口，负责创建和配置文档编辑页面
/// 采用无状态设计，所有配置通过构造函数参数传递
class MobileDocumentScreen extends StatelessWidget {
  /// 构造函数 - 创建移动端文档屏幕
  /// 
  /// 参数说明：
  /// - [id]: 必需，视图的唯一标识符
  /// - [title]: 可选，页面标题
  /// - [showMoreButton]: 是否显示更多按钮，默认true
  /// - [fixedTitle]: 固定标题，如果提供则不可编辑
  /// - [blockId]: 特定块的ID，用于直接定位到某个内容块
  /// - [tabs]: 图标选择器标签页类型，默认包含emoji和icon
  const MobileDocumentScreen({
    super.key,
    required this.id,
    this.title,
    this.showMoreButton = true,
    this.fixedTitle,
    this.blockId,
    this.tabs = const [PickerTabType.emoji, PickerTabType.icon],
  });

  /// 视图唯一标识符 - 用于标识和加载特定的文档
  final String id;
  /// 页面标题 - 显示在应用栏中的标题文本
  final String? title;
  /// 是否显示更多按钮 - 控制页面右上角操作按钮的显示
  final bool showMoreButton;
  /// 固定标题 - 如果设置，标题将不可编辑
  final String? fixedTitle;
  /// 块标识符 - 用于定位到文档中的特定内容块
  final String? blockId;
  /// 图标选择器标签页类型列表 - 定义可用的图标/表情选择选项
  final List<PickerTabType> tabs;

  /// 路由常量定义 - 用于页面导航和参数传递
  /// 路由名称 - 文档页面的路由路径
  static const routeName = '/docs';
  /// URL参数键名 - 视图ID参数
  static const viewId = 'id';
  /// URL参数键名 - 视图标题参数
  static const viewTitle = 'title';
  /// URL参数键名 - 是否显示更多按钮参数
  static const viewShowMoreButton = 'show_more_button';
  /// URL参数键名 - 固定标题参数
  static const viewFixedTitle = 'fixed_title';
  /// URL参数键名 - 块ID参数
  static const viewBlockId = 'block_id';
  /// URL参数键名 - 选择器标签页参数
  static const viewSelectTabs = 'select_tabs';

  /// 构建UI界面
  /// 
  /// 这个方法创建移动端文档编辑界面，实际上是对MobileViewPage的简单包装
  /// 所有的具体实现都委托给MobileViewPage处理
  /// 
  /// 设计思路：
  /// - 遵循单一职责原则，此组件只负责配置和参数传递
  /// - 将视图布局固定为Document类型
  /// - 将所有配置参数透传给底层实现
  @override
  Widget build(BuildContext context) {
    return MobileViewPage(
      id: id,                                // 视图标识符
      title: title,                          // 页面标题
      viewLayout: ViewLayoutPB.Document,     // 指定为文档布局类型
      showMoreButton: showMoreButton,        // 更多按钮显示控制
      fixedTitle: fixedTitle,                // 固定标题配置
      blockId: blockId,                      // 目标块ID
      tabs: tabs,                            // 图标选择器标签页
    );
  }
}
