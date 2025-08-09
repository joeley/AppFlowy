// Flutter核心UI框架
import 'package:flutter/material.dart';

// AppFlowy移动端基础视图页面组件
import 'package:appflowy/mobile/presentation/base/mobile_view_page.dart';
// AppFlowy后端协议缓冲区定义，包含视图相关的数据结构
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';

/// 移动端网格视图屏幕
/// 
/// 这是AppFlowy数据库在移动端的网格布局显示组件。
/// 网格布局以表格形式展示数据，类似于电子表格的界面。
/// 该组件继承StatelessWidget，是一个无状态组件，主要负责路由和界面展示。
class MobileGridScreen extends StatelessWidget {
  /// 构造函数
  /// 
  /// [id] 视图的唯一标识符，用于在后端定位具体的数据库视图
  /// [title] 可选的视图标题，将显示在应用栏中
  /// [arguments] 可选的附加参数，用于传递额外的配置信息
  const MobileGridScreen({
    super.key,
    required this.id,
    this.title,
    this.arguments,
  });

  /// 数据库视图的唯一标识符
  /// 这个ID用于在后端查找和加载对应的数据库视图数据
  final String id;
  
  /// 视图标题（可选）
  /// 如果提供，将显示在移动端的应用栏中
  final String? title;
  
  /// 附加参数（可选）
  /// 用于传递额外的配置信息，比如过滤条件、排序规则等
  final Map<String, dynamic>? arguments;

  /// 路由名称常量
  /// 用于Flutter的路由系统，定义导航到网格视图的路径
  static const routeName = '/grid';
  
  /// 路由参数键名：视图ID
  /// 用于在路由参数中传递视图标识符
  static const viewId = 'id';
  
  /// 路由参数键名：视图标题
  /// 用于在路由参数中传递视图标题
  static const viewTitle = 'title';
  
  /// 路由参数键名：附加参数
  /// 用于在路由参数中传递额外的配置信息
  static const viewArgs = 'arguments';

  /// 构建网格视图界面
  /// 
  /// 这个方法是Flutter框架的核心，负责构建和返回要显示的Widget树。
  /// 
  /// 返回值：
  /// 返回一个MobileViewPage组件，这是AppFlowy移动端的通用视图容器。
  /// MobileViewPage会根据传入的viewLayout参数来决定如何渲染数据库内容。
  @override
  Widget build(BuildContext context) {
    // 使用MobileViewPage作为容器，配置为网格布局模式
    // ViewLayoutPB.Grid告诉系统这是一个表格/网格形式的数据展示
    return MobileViewPage(
      id: id,                          // 传递视图ID用于数据加载
      title: title,                    // 传递标题用于显示
      viewLayout: ViewLayoutPB.Grid,   // 指定为网格布局类型
      arguments: arguments,            // 传递额外参数
    );
  }
}
