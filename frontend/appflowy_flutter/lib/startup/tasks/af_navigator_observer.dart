import 'package:flutter/material.dart';

/// AppFlowy导航观察者
/// 
/// 全局路由监控器，继承自Flutter的NavigatorObserver，
/// 用于监听和分发应用中的所有导航事件。
/// 
/// ## 核心设计
/// 1. **观察者模式**：允许多个组件监听路由变化
/// 2. **事件分类**：将导航事件分为Push、Pop、Replace三种类型
/// 3. **安全迭代**：使用Set.of创建副本，避免迭代时修改集合
/// 
/// ## 使用场景
/// - 页面访问统计：记录用户访问路径
/// - 导航历史管理：维护页面访问历史
/// - 状态同步：页面切换时同步全局状态
/// - 调试工具：开发时追踪路由问题
/// 
/// ## 使用示例
/// ```dart
/// // 1. 在应用启动时注册到MaterialApp
/// MaterialApp(
///   navigatorObservers: [getIt<AFNavigatorObserver>()],
/// )
/// 
/// // 2. 添加监听器
/// final observer = getIt<AFNavigatorObserver>();
/// observer.addListener((routeInfo) {
///   if (routeInfo is PushRouterInfo) {
///     print('打开页面: ${routeInfo.newRoute?.settings.name}');
///   } else if (routeInfo is PopRouterInfo) {
///     print('关闭页面: ${routeInfo.oldRoute?.settings.name}');
///   }
/// });
/// 
/// // 3. 移除监听器
/// observer.removeListener(myListener);
/// ```
class AFNavigatorObserver extends NavigatorObserver {
  /// 路由事件监听器集合
  /// 
  /// 使用Set确保同一个监听器不会重复注册
  final Set<ValueChanged<RouteInfo>> _listeners = {};

  /// 添加路由事件监听器
  /// 
  /// [listener] 路由事件回调函数
  void addListener(ValueChanged<RouteInfo> listener) {
    _listeners.add(listener);
  }

  /// 移除路由事件监听器
  /// 
  /// [listener] 要移除的监听器
  void removeListener(ValueChanged<RouteInfo> listener) {
    _listeners.remove(listener);
  }

  /// 页面入栈事件
  /// 
  /// 当新页面被push到导航栈时触发
  /// 
  /// [route] 新入栈的路由
  /// [previousRoute] 之前的路由（如果有）
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 创建监听器副本，避免迭代时修改集合导致异常
    for (final listener in Set.of(_listeners)) {
      listener(PushRouterInfo(newRoute: route, oldRoute: previousRoute));
    }
  }

  /// 页面出栈事件
  /// 
  /// 当页面从导航栈pop出时触发
  /// 
  /// [route] 被pop的路由
  /// [previousRoute] pop后显示的路由（如果有）
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 创建监听器副本，避免迭代时修改集合导致异常
    for (final listener in Set.of(_listeners)) {
      listener(PopRouterInfo(newRoute: route, oldRoute: previousRoute));
    }
  }

  /// 页面替换事件
  /// 
  /// 当路由被替换时触发（如使用Navigator.replace）
  /// 
  /// [newRoute] 新的路由
  /// [oldRoute] 被替换的路由
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // 创建监听器副本，避免迭代时修改集合导致异常
    for (final listener in Set.of(_listeners)) {
      listener(ReplaceRouterInfo(newRoute: newRoute, oldRoute: oldRoute));
    }
  }
}

/// 路由信息基类
/// 
/// 封装路由变化的信息，包含新旧路由对象
abstract class RouteInfo {
  RouteInfo({this.oldRoute, this.newRoute});

  /// 旧路由（变化前的路由）
  final Route? oldRoute;
  
  /// 新路由（变化后的路由）
  final Route? newRoute;
}

/// Push路由信息
/// 
/// 表示新页面被推入导航栈
/// - newRoute: 新推入的页面路由
/// - oldRoute: 被覆盖的页面路由
class PushRouterInfo extends RouteInfo {
  PushRouterInfo({super.newRoute, super.oldRoute});
}

/// Pop路由信息
/// 
/// 表示页面从导航栈弹出
/// - newRoute: 弹出后显示的页面路由
/// - oldRoute: 被弹出的页面路由
class PopRouterInfo extends RouteInfo {
  PopRouterInfo({super.newRoute, super.oldRoute});
}

/// Replace路由信息
/// 
/// 表示页面被替换
/// - newRoute: 替换后的新页面路由
/// - oldRoute: 被替换的旧页面路由
class ReplaceRouterInfo extends RouteInfo {
  ReplaceRouterInfo({super.newRoute, super.oldRoute});
}
