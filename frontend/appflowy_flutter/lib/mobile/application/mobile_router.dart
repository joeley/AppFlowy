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

/*
 * 移动端路由扩展
 * 
 * 为BuildContext添加移动端专用的导航功能
 * 这个扩展提供了统一的视图跳转接口，隐藏了不同视图类型的路由细节
 * 
 * 设计思想：
 * 1. **扩展方法模式**：通过扩展为现有类添加新功能
 * 2. **统一接口**：不同类型的视图使用相同的跳转方法
 * 3. **参数传递**：通过查询参数传递视图配置
 */

extension MobileRouter on BuildContext {
  /*
   * 推送视图页面
   * 
   * 根据视图类型自动选择对应的页面进行跳转
   * 同时更新最近访问记录和共享状态
   * 
   * @param view 要打开的视图对象
   * @param arguments 额外参数，传递给目标页面
   * @param addInRecent 是否添加到最近访问
   * @param showMoreButton 是否显示更多按钮（文档视图专用）
   * @param fixedTitle 固定标题，不使用视图名称
   * @param blockId 文档块ID，用于定位到特定位置
   * @param tabs 选中的标签页列表
   */
  Future<void> pushView(
    ViewPB view, {
    Map<String, dynamic>? arguments,
    bool addInRecent = true,
    bool showMoreButton = true,
    String? fixedTitle,
    String? blockId,
    List<String>? tabs,
  }) async {
    /* 在跳转前设置当前视图
     * 更新全局状态，让其他组件知道当前打开的视图 */
    getIt<MenuSharedState>().latestOpenView = view;
    /* 异步更新最近访问记录
     * 使用unawaited避免阻塞导航操作 */
    unawaited(getIt<CachedRecentService>().updateRecentViews([view.id], true));
    /* 获取基础查询参数 */
    final queryParameters = view.queryParameters(arguments);

    /* 文档视图的特殊参数处理
     * 文档页面支持更多的自定义配置 */
    if (view.layout == ViewLayoutPB.Document) {
      /* 是否显示更多操作按钮 */
      queryParameters[MobileDocumentScreen.viewShowMoreButton] =
          showMoreButton.toString();
      /* 使用固定标题而不是视图名称 */
      if (fixedTitle != null) {
        queryParameters[MobileDocumentScreen.viewFixedTitle] = fixedTitle;
      }
      /* 跳转到特定的文档块 */
      if (blockId != null) {
        queryParameters[MobileDocumentScreen.viewBlockId] = blockId;
      }
    }
    /* 标签页参数，用连字符连接多个标签 */
    if (tabs != null) {
      queryParameters[MobileDocumentScreen.viewSelectTabs] = tabs.join('-');
    }

    /* 构建完整的URI路径
     * 使用查询参数传递所有配置信息 */
    final uri = Uri(
      path: view.routeName,
      queryParameters: queryParameters,
    ).toString();
    /* 执行实际的路由跳转 */
    await push(uri);
  }
}

/*
 * ViewPB扩展
 * 
 * 为Protocol Buffer生成的ViewPB类添加路由相关功能
 * 将视图类型映射到对应的路由名称
 */
extension on ViewPB {
  /*
   * 获取路由名称
   * 
   * 根据视图布局类型返回对应的页面路由名
   * 每种布局类型对应一个特定的移动端页面
   */
  String get routeName {
    switch (layout) {
      case ViewLayoutPB.Document:
        return MobileDocumentScreen.routeName;  /* 文档编辑器 */
      case ViewLayoutPB.Grid:
        return MobileGridScreen.routeName;      /* 表格视图 */
      case ViewLayoutPB.Calendar:
        return MobileCalendarScreen.routeName;  /* 日历视图 */
      case ViewLayoutPB.Board:
        return MobileBoardScreen.routeName;     /* 看板视图 */
      case ViewLayoutPB.Chat:
        return MobileChatScreen.routeName;      /* AI聊天视图 */

      default:
        throw UnimplementedError('routeName for $this is not implemented');
    }
  }

  /*
   * 构建查询参数
   * 
   * 为不同的视图类型生成对应的URL查询参数
   * 这些参数会传递给目标页面用于初始化
   * 
   * @param arguments 额外的自定义参数
   * @return 包含所有必要参数的Map
   */
  Map<String, dynamic> queryParameters([Map<String, dynamic>? arguments]) {
    switch (layout) {
      case ViewLayoutPB.Document:
        /* 文档视图：只需要ID和标题 */
        return {
          MobileDocumentScreen.viewId: id,
          MobileDocumentScreen.viewTitle: name,
        };
      case ViewLayoutPB.Grid:
        /* 表格视图：支持额外参数（如过滤器、排序等）
         * 将参数JSON序列化以便通过URL传递 */
        return {
          MobileGridScreen.viewId: id,
          MobileGridScreen.viewTitle: name,
          MobileGridScreen.viewArgs: jsonEncode(arguments),
        };
      case ViewLayoutPB.Calendar:
        /* 日历视图：基础参数 */
        return {
          MobileCalendarScreen.viewId: id,
          MobileCalendarScreen.viewTitle: name,
        };
      case ViewLayoutPB.Board:
        /* 看板视图：基础参数 */
        return {
          MobileBoardScreen.viewId: id,
          MobileBoardScreen.viewTitle: name,
        };
      case ViewLayoutPB.Chat:
        /* 聊天视图：基础参数 */
        return {
          MobileChatScreen.viewId: id,
          MobileChatScreen.viewTitle: name,
        };
      default:
        throw UnimplementedError(
          'queryParameters for $this is not implemented',
        );
    }
  }
}
