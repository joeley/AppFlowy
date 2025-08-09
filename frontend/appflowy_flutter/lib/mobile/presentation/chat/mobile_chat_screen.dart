// 导入移动端基础页面组件，这是所有移动端视图页面的基类
import 'package:appflowy/mobile/presentation/base/mobile_view_page.dart';
// 导入后端protobuf定义的视图相关数据结构
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// 导入Flutter的Material Design组件库
import 'package:flutter/material.dart';

/// 移动端聊天屏幕组件
/// 
/// 设计思想：
/// 1. 作为一个轻量级的包装组件，将聊天功能委托给通用的MobileViewPage
/// 2. 遵循Flutter的StatelessWidget模式，保持组件的简洁和高效
/// 3. 通过传递ViewLayoutPB.Chat来指定页面布局类型，体现了策略模式的设计思想
/// 4. 在AppFlowy的架构中，这种设计允许不同类型的页面（聊天、文档、数据库等）
///    复用相同的基础页面结构，只需要指定不同的布局类型
class MobileChatScreen extends StatelessWidget {
  /// 构造函数
  /// [id] 必需参数，表示聊天视图的唯一标识符
  /// [title] 可选参数，聊天页面的标题
  const MobileChatScreen({
    super.key,
    required this.id,
    this.title,
  });

  /// 聊天视图的唯一标识符，用于在后端定位具体的聊天实例
  final String id;
  /// 聊天页面的可选标题，如果为null则可能使用默认标题或从后端获取
  final String? title;

  /// 路由名称常量，用于Flutter的导航系统
  /// 这个路由路径将在路由表中注册，允许通过Navigator.pushNamed('/chat')导航到此页面
  static const routeName = '/chat';
  /// 路由参数中视图ID的键名，用于从路由参数中提取视图ID
  static const viewId = 'id';
  /// 路由参数中视图标题的键名，用于从路由参数中提取标题
  static const viewTitle = 'title';

  /// 构建聊天屏幕的UI
  /// 
  /// 这里体现了组合模式的设计思想：
  /// 1. 不直接实现聊天界面，而是委托给MobileViewPage
  /// 2. 通过ViewLayoutPB.Chat参数告诉MobileViewPage要渲染聊天类型的界面
  /// 3. 这种设计使得不同类型的页面可以共享相同的基础结构和行为
  @override
  Widget build(BuildContext context) {
    // 使用MobileViewPage作为基础容器，传入聊天特定的布局类型
    return MobileViewPage(
      id: id, // 传递视图标识符
      title: title, // 传递可选标题
      viewLayout: ViewLayoutPB.Chat, // 指定为聊天布局类型，这是关键参数
    );
  }
}
