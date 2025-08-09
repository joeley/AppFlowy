// 导入移动端基础视图页面组件，提供统一的页面结构和布局
import 'package:appflowy/mobile/presentation/base/mobile_view_page.dart';
// 导入AppFlowy后端协议缓冲区定义，包含视图相关的数据结构
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// Flutter核心UI框架
import 'package:flutter/material.dart';

/// 移动端看板视图屏幕
/// 
/// 这是AppFlowy数据库在移动端的看板布局显示组件。
/// 看板布局以卡片形式展示数据，类似于Trello或Kanban的界面风格。
/// 每个数据项以卡片形式展示，可以按状态、优先级等字段分组显示。
/// 
/// 设计思路：
/// - 继承StatelessWidget，保持组件的简洁性和性能
/// - 作为视图层的入口，负责路由管理和参数传递
/// - 将具体的看板渲染逻辑委托给MobileViewPage处理
class MobileBoardScreen extends StatelessWidget {
  /// 构造函数 - 创建移动端看板屏幕
  /// 
  /// 参数说明：
  /// - [id]: 必需，数据库视图的唯一标识符
  /// - [title]: 可选，视图标题，显示在应用栏中
  const MobileBoardScreen({
    super.key,
    required this.id,
    this.title,
  });

  /// 数据库视图的唯一标识符
  /// 用于在后端查找和加载对应的数据库视图数据
  /// 这个ID是数据库视图的核心标识，确保数据的准确加载
  final String id;
  
  /// 视图标题（可选）
  /// 如果提供，将显示在移动端的应用栏中
  /// 为用户提供直观的页面标识信息
  final String? title;

  /// 路由常量定义 - 用于页面导航和参数传递
  /// 路由名称 - 看板视图页面的路径标识
  static const routeName = '/board';
  /// URL参数键名 - 视图ID参数
  static const viewId = 'id';
  /// URL参数键名 - 视图标题参数
  static const viewTitle = 'title';

  /// 构建看板视图界面
  /// 
  /// 这个方法是Flutter框架的核心，负责构建和返回要显示的Widget树。
  /// 
  /// 设计思路：
  /// - 使用MobileViewPage作为通用容器组件
  /// - 注意：这里使用ViewLayoutPB.Document可能是个错误，应该是ViewLayoutPB.Board
  /// - 将所有配置参数透传给底层实现，保持组件职责单一
  /// 
  /// 返回值：
  /// 返回配置好的MobileViewPage组件，用于显示看板形式的数据库内容
  @override
  Widget build(BuildContext context) {
    // 使用MobileViewPage作为容器，配置看板布局
    // TODO: 这里的viewLayout应该是ViewLayoutPB.Board而不是Document
    return MobileViewPage(
      id: id,                            // 传递视图ID用于数据加载
      title: title,                      // 传递标题用于显示
      viewLayout: ViewLayoutPB.Document, // 指定布局类型（此处可能需要修正为Board）
    );
  }
}
