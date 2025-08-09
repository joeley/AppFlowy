import 'dart:async';
import 'dart:convert';

import 'package:appflowy/mobile/presentation/chat/mobile_chat_screen.dart';
import 'package:appflowy/mobile/presentation/database/board/mobile_board_screen.dart';
import 'package:appflowy/mobile/presentation/database/mobile_calendar_screen.dart';
import 'package:appflowy/mobile/presentation/database/mobile_grid_screen.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
import 'package:appflowy/workspace/presentation/home/menu/menu_shared_state.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 移动端路由管理器
/// 
/// 主要功能：
/// 1. 为移动端提供统一的视图导航接口
/// 2. 管理不同类型视图的路由映射
/// 3. 处理视图跳转时的参数传递
/// 4. 维护最近访问记录和全局状态
/// 
/// 设计架构：
/// - **扩展方法模式**：通过Extension为BuildContext添加路由功能
/// - **策略模式**：根据视图类型选择不同的路由策略
/// - **查询参数传递**：使用URI查询参数传递复杂配置
/// - **异步处理**：避免阻塞UI的状态更新操作
/// 
/// 支持的视图类型：
/// - Document：文档编辑器
/// - Grid：表格视图
/// - Calendar：日历视图
/// - Board：看板视图
/// - Chat：AI聊天视图

extension MobileRouter on BuildContext {
  /// 推送视图页面
  /// 
  /// 这是移动端导航的核心方法，提供了一个统一的接口来打开不同类型的视图。
  /// 根据视图的布局类型自动选择对应的页面进行跳转，同时处理状态同步和参数传递。
  /// 
  /// 工作流程：
  /// 1. 更新全局状态中的最新打开视图
  /// 2. 异步更新最近访问记录（不阻塞导航）
  /// 3. 构建基础查询参数
  /// 4. 处理特定视图类型的额外参数
  /// 5. 执行路由跳转
  /// 
  /// 参数说明：
  /// - [view]: 要打开的视图对象（Protocol Buffer生成）
  /// - [arguments]: 额外参数，会被JSON序列化后传递给目标页面
  /// - [addInRecent]: 是否添加到最近访问记录（默认true）
  /// - [showMoreButton]: 是否显示更多操作按钮（仅文档视图有效）
  /// - [fixedTitle]: 固定标题，覆盖视图原本的名称
  /// - [blockId]: 文档块ID，用于定位到文档的特定位置
  /// - [tabs]: 选中的标签页列表，用连字符连接
  Future<void> pushView(
    ViewPB view, {
    Map<String, dynamic>? arguments,
    bool addInRecent = true,
    bool showMoreButton = true,
    String? fixedTitle,
    String? blockId,
    List<String>? tabs,
  }) async {
    // 更新全局共享状态，记录最新打开的视图
    // 这允许其他组件（如侧边栏）知道当前活动视图
    getIt<MenuSharedState>().latestOpenView = view;
    
    // 异步更新最近访问记录
    // 使用unawaited避免阻塞导航操作，提升用户体验
    unawaited(getIt<CachedRecentService>().updateRecentViews([view.id], true));
    
    // 根据视图类型获取基础查询参数
    final queryParameters = view.queryParameters(arguments);

    // 文档视图的特殊参数处理
    // 文档页面支持更丰富的配置选项
    if (view.layout == ViewLayoutPB.Document) {
      // 控制是否显示更多操作按钮
      // 某些场景下（如预览模式）可能需要隐藏操作按钮
      queryParameters[MobileDocumentScreen.viewShowMoreButton] =
          showMoreButton.toString();
      
      // 使用固定标题覆盖视图名称
      // 用于特殊场景，如显示"欢迎页"而不是实际的文档名
      if (fixedTitle != null) {
        queryParameters[MobileDocumentScreen.viewFixedTitle] = fixedTitle;
      }
      
      // 传递文档块ID，用于定位到特定段落
      // 支持深链接和精确导航
      if (blockId != null) {
        queryParameters[MobileDocumentScreen.viewBlockId] = blockId;
      }
    }
    
    // 处理标签页参数
    // 多个标签用连字符连接，如"tab1-tab2-tab3"
    if (tabs != null) {
      queryParameters[MobileDocumentScreen.viewSelectTabs] = tabs.join('-');
    }

    // 构建完整的URI路径
    // 使用查询参数传递所有配置信息，避免使用路径参数
    // 这种方式更灵活，易于扩展
    final uri = Uri(
      path: view.routeName,
      queryParameters: queryParameters,
    ).toString();
    
    // 执行路由跳转
    // 使用GoRouter的push方法进行导航
    await push(uri);
  }
}

/// ViewPB路由扩展
/// 
/// 为Protocol Buffer生成的ViewPB类添加路由相关功能。
/// 这个扩展封装了视图类型到路由的映射逻辑，以及参数构建逻辑。
/// 
/// 设计原则：
/// - **单一职责**：每个方法只负责一个特定功能
/// - **开闭原则**：易于添加新的视图类型，不影响现有代码
/// - **类型安全**：使用枚举和类型系统确保编译时安全
extension on ViewPB {
  /// 获取路由名称
  /// 
  /// 将视图布局类型映射到对应的路由路径。
  /// 每种布局类型对应移动端的一个特定页面。
  /// 
  /// 路由映射关系：
  /// - Document -> /docs (文档编辑器)
  /// - Grid -> /grid (表格视图)
  /// - Calendar -> /calendar (日历视图)
  /// - Board -> /board (看板视图)
  /// - Chat -> /chat (AI聊天)
  /// 
  /// 抛出异常：
  /// 当遇到未实现的视图类型时抛出UnimplementedError
  String get routeName {
    switch (layout) {
      case ViewLayoutPB.Document:
        return MobileDocumentScreen.routeName;  // 文档编辑器路由
      case ViewLayoutPB.Grid:
        return MobileGridScreen.routeName;      // 表格视图路由
      case ViewLayoutPB.Calendar:
        return MobileCalendarScreen.routeName;  // 日历视图路由
      case ViewLayoutPB.Board:
        return MobileBoardScreen.routeName;     // 看板视图路由
      case ViewLayoutPB.Chat:
        return MobileChatScreen.routeName;      // AI聊天视图路由

      default:
        // 未实现的视图类型
        // 这确保了新增视图类型时必须更新路由映射
        throw UnimplementedError('routeName for $this is not implemented');
    }
  }

  /// 构建查询参数
  /// 
  /// 为不同的视图类型生成对应的URL查询参数。
  /// 这些参数会在目标页面通过GoRouterState获取并用于初始化。
  /// 
  /// 参数策略：
  /// - **基础参数**：所有视图都需要id和title
  /// - **扩展参数**：特定视图类型可能需要额外参数
  /// - **序列化**：复杂对象通过JSON序列化传递
  /// 
  /// 参数说明：
  /// - [arguments]: 可选的额外参数，根据视图类型处理
  /// 
  /// 返回值：
  /// 包含所有必要参数的Map，键为参数名，值为参数值
  Map<String, dynamic> queryParameters([Map<String, dynamic>? arguments]) {
    switch (layout) {
      case ViewLayoutPB.Document:
        // 文档视图：最简单的参数配置
        // 只需要视图ID和标题
        return {
          MobileDocumentScreen.viewId: id,
          MobileDocumentScreen.viewTitle: name,
        };
      case ViewLayoutPB.Grid:
        // 表格视图：支持复杂参数
        // arguments可能包含过滤器、排序、分组等配置
        // 通过JSON序列化确保参数完整传递
        return {
          MobileGridScreen.viewId: id,
          MobileGridScreen.viewTitle: name,
          MobileGridScreen.viewArgs: jsonEncode(arguments),
        };
      case ViewLayoutPB.Calendar:
        // 日历视图：基础参数配置
        return {
          MobileCalendarScreen.viewId: id,
          MobileCalendarScreen.viewTitle: name,
        };
      case ViewLayoutPB.Board:
        // 看板视图：基础参数配置
        return {
          MobileBoardScreen.viewId: id,
          MobileBoardScreen.viewTitle: name,
        };
      case ViewLayoutPB.Chat:
        // 聊天视图：基础参数配置
        return {
          MobileChatScreen.viewId: id,
          MobileChatScreen.viewTitle: name,
        };
      default:
        // 确保所有视图类型都有对应的参数构建逻辑
        throw UnimplementedError(
          'queryParameters for $this is not implemented',
        );
    }
  }
}
