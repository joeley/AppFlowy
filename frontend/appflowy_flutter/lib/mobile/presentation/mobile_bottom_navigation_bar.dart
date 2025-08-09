import 'dart:io';
import 'dart:ui';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/notifications/mobile_notifications_screen.dart';
import 'package:appflowy/mobile/presentation/widgets/navigation_bar_button.dart';
import 'package:appflowy/shared/popup_menu/appflowy_popup_menu.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/presentation/notifications/number_red_dot.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'home/mobile_home_page.dart';
import 'search/mobile_search_page.dart';

/// 底部导航栏操作类型枚举
/// 
/// 定义底部导航栏的两种不同操作模式：
/// - home: 常规首页导航模式
/// - notificationMultiSelect: 通知多选操作模式

enum BottomNavigationBarActionType {
  /// 首页模式：显示常规的底部导航栏
  home,
  /// 通知多选模式：显示通知操作按钮
  notificationMultiSelect,
}

/// 移动端创建新页面的全局通知器
/// 用于在整个应用中触发新页面的创建
final PropertyValueNotifier<ViewLayoutPB?> mobileCreateNewPageNotifier =
    PropertyValueNotifier(null);
    
/// 底部导航栏类型状态通知器
/// 控制显示哪种类型的底部导航栏（常规导航或通知操作）
final ValueNotifier<BottomNavigationBarActionType> bottomNavigationBarType =
    ValueNotifier(BottomNavigationBarActionType.home);
    
/// 底部导航栏当前选中项通知器
/// 记录当前激活的导航项标签
final ValueNotifier<String?> bottomNavigationBarItemType =
    ValueNotifier(BottomNavigationBarItemType.home.label);

/// 底部导航栏项目类型枚举
/// 
/// 定义移动端底部导航栏的四个主要功能入口：
/// - home: 首页入口
/// - search: 搜索功能入口
/// - add: 快速创建入口（不跳转，触发弹窗）
/// - notification: 通知中心入口
enum BottomNavigationBarItemType {
  /// 首页：显示工作区和文档列表
  home,
  /// 搜索：全局内容搜索功能
  search,
  /// 添加：快速创建新文档/页面的入口
  add,
  /// 通知：显示提醒和通知消息
  notification;

  /// 获取导航项的标签名称
  String get label => name;
  
  /// 获取对应的路由名称
  /// 注意：add项返回null，因为它不跳转路由而是触发创建弹窗
  String? get routeName {
    return switch (this) {
      home => MobileHomeScreen.routeName,
      search => MobileSearchScreen.routeName,
      notification => MobileNotificationsScreenV2.routeName,
      add => null,  // 添加按钮不对应路由，而是触发创建操作
    };
  }

  /// 获取导航项的ValueKey，用于Flutter的Widget识别
  ValueKey get valueKey {
    return ValueKey(label);
  }

  /// 获取未选中状态的图标组件
  Widget get iconWidget {
    return switch (this) {
      home => const FlowySvg(FlowySvgs.m_home_unselected_m),
      search => const FlowySvg(FlowySvgs.m_home_search_icon_m),
      add => const FlowySvg(FlowySvgs.m_home_add_m),
      notification => const _NotificationNavigationBarItemIcon(),
    };
  }

  /// 获取选中状态的图标组件
  /// 注意：add项返回null，因为它不需要选中状态
  Widget? get activeIcon {
    return switch (this) {
      home => const FlowySvg(FlowySvgs.m_home_selected_m, blendMode: null),
      search =>
        const FlowySvg(FlowySvgs.m_home_search_icon_active_m, blendMode: null),
      add => null,  // 添加按钮不需要激活状态
      notification => const _NotificationNavigationBarItemIcon(isActive: true),
    };
  }

  /// 构建Flutter BottomNavigationBarItem
  BottomNavigationBarItem get navigationItem {
    return BottomNavigationBarItem(
      key: valueKey,
      label: label,
      icon: iconWidget,
      activeIcon: activeIcon,
    );
  }
}

/// 底部导航栏所有项目的列表
/// 将枚举值转换为BottomNavigationBarItem列表，供BottomNavigationBar使用
final _items =
    BottomNavigationBarItemType.values.map((e) => e.navigationItem).toList();

/// 移动端底部导航栏组件
/// 
/// 功能说明：
/// 1. 构建应用的主要导航结构，采用Shell导航模式
/// 2. 根据不同状态动态切换导航栏样式
/// 3. 支持平滑的切换动画效果
/// 4. 集成GoRouter的StatefulNavigationShell
/// 
/// 设计思想：
/// - Shell模式：导航栏作为应用的外壳，内容页面在body中切换
/// - 状态驱动：通过bottomNavigationBarType控制显示不同类型的导航栏
/// - 动画过渡：使用AnimatedSwitcher提供流畅的切换体验
class MobileBottomNavigationBar extends StatefulWidget {
  /// 构造移动端底部导航栏
  const MobileBottomNavigationBar({
    required this.navigationShell,
    super.key,
  });

  /// 导航Shell，包含分支导航器的容器
  /// 这是GoRouter提供的StatefulNavigationShell，用于管理多个导航分支
  final StatefulNavigationShell navigationShell;

  @override
  State<MobileBottomNavigationBar> createState() =>
      _MobileBottomNavigationBarState();
}

class _MobileBottomNavigationBarState extends State<MobileBottomNavigationBar> {
  /// 当前显示的底部导航栏组件
  /// 根据bottomNavigationBarType的值动态切换
  Widget? _bottomNavigationBar;

  @override
  void initState() {
    super.initState();

    // 监听导航栏类型变化，触发UI重建
    bottomNavigationBarType.addListener(_animate);
  }

  @override
  void dispose() {
    // 清理监听器，防止内存泄漏
    bottomNavigationBarType.removeListener(_animate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 根据当前导航栏类型构建对应的导航栏组件
    _bottomNavigationBar = switch (bottomNavigationBarType.value) {
      BottomNavigationBarActionType.home =>
        _buildHomePageNavigationBar(context),
      BottomNavigationBarActionType.notificationMultiSelect =>
        _buildNotificationNavigationBar(context),
    };

    return Scaffold(
      body: widget.navigationShell,  // 导航Shell作为主体内容
      extendBody: true,  // 允许body内容延伸到导航栏下方
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),  // 切换动画时长
        switchInCurve: Curves.easeInOut,   // 进入动画曲线
        switchOutCurve: Curves.easeInOut,  // 退出动画曲线
        transitionBuilder: _transitionBuilder,
        child: _bottomNavigationBar,
      ),
    );
  }

  /// 构建首页导航栏
  /// 包含首页、搜索、添加、通知四个主要功能入口
  Widget _buildHomePageNavigationBar(BuildContext context) {
    return _HomePageNavigationBar(
      navigationShell: widget.navigationShell,
    );
  }

  /// 构建通知操作导航栏
  /// 用于通知页面的多选操作（标记已读、归档等）
  Widget _buildNotificationNavigationBar(BuildContext context) {
    return const _NotificationNavigationBar();
  }

  /// 导航栏切换的过渡动画构建器
  /// 
  /// 实现从下往上的滑入效果：
  /// - 新导航栏从底部滑入
  /// - 旧导航栏向下滑出
  Widget _transitionBuilder(
    Widget child,
    Animation<double> animation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),  // 从底部开始
        end: Offset.zero,           // 滑动到正常位置
      ).animate(animation),
      child: child,
    );
  }

  /// 触发导航栏重建的动画方法
  /// 当bottomNavigationBarType发生变化时调用
  void _animate() {
    setState(() {});
  }
}

/// 通知导航栏图标组件
/// 
/// 功能说明：
/// 1. 显示通知图标（普通/激活状态）
/// 2. 实时监听未读提醒数量
/// 3. 有未读消息时显示红点提示
/// 
/// 设计思想：
/// - BLoC状态监听：实时反映提醒状态变化
/// - 视觉反馈：通过红点提示用户有新消息
/// - 双状态设计：支持普通和激活两种视觉状态
class _NotificationNavigationBarItemIcon extends StatelessWidget {
  const _NotificationNavigationBarItemIcon({
    this.isActive = false,
  });

  /// 是否为激活状态（当前选中的导航项）
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ReminderBloc>(),  // 使用依赖注入获取提醒BLoC
      child: BlocBuilder<ReminderBloc, ReminderState>(
        builder: (context, state) {
          // 检查是否有未读提醒
          final hasUnreads = state.reminders.any(
            (reminder) => !reminder.isRead,
          );
          return SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                // 通知图标（根据激活状态显示不同样式）
                Center(
                  child: isActive
                      ? const FlowySvg(
                          FlowySvgs.m_home_active_notification_m,
                          blendMode: null,
                        )
                      : const FlowySvg(
                          FlowySvgs.m_home_notification_m,
                        ),
                ),
                // 未读消息红点提示
                if (hasUnreads)
                  const Align(
                    alignment: Alignment.topRight,
                    child: NumberedRedDot.mobile(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 首页底部导航栏组件
/// 
/// 功能说明：
/// 1. 提供四个主要功能的导航入口
/// 2. 实现毛玻璃背景效果
/// 3. 响应式主题适配
/// 4. 处理导航和创建操作
/// 
/// 视觉设计：
/// - 毛玻璃效果：增强视觉层次感
/// - 主题适配：支持亮色/暗色模式
/// - 平台差异：iOS和Android的交互效果差异化
class _HomePageNavigationBar extends StatelessWidget {
  const _HomePageNavigationBar({
    required this.navigationShell,
  });

  /// 导航Shell，用于执行页面跳转
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        // 毛玻璃背景模糊效果
        filter: ImageFilter.blur(
          sigmaX: 3,
          sigmaY: 3,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: context.border,           // 主题相关边框
            color: context.backgroundColor,   // 主题相关背景色
          ),
          child: Theme(
            data: _getThemeData(context),     // 平台相关主题数据
            child: BottomNavigationBar(
              showSelectedLabels: false,      // 不显示文字标签
              showUnselectedLabels: false,    // 不显示未选中标签
              enableFeedback: false,          // 禁用触觉反馈
              type: BottomNavigationBarType.fixed,  // 固定类型导航栏
              elevation: 0,                   // 无阴影
              items: _items,                  // 导航项列表
              backgroundColor: Colors.transparent,  // 透明背景
              currentIndex: navigationShell.currentIndex,  // 当前选中索引
              onTap: (int bottomBarIndex) => _onTap(context, bottomBarIndex),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取平台适配的主题数据
  /// 
  /// 功能说明：
  /// - Android：保持默认的水波纹点击效果
  /// - iOS：移除水波纹效果，符合iOS设计规范
  ThemeData _getThemeData(BuildContext context) {
    if (Platform.isAndroid) {
      return Theme.of(context);
    }

    // iOS平台：隐藏水波纹点击效果
    return Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,  // 无水波纹工厂
      splashColor: Colors.transparent,        // 透明水波纹颜色
      highlightColor: Colors.transparent,     // 透明高亮颜色
    );
  }

  /// 处理底部导航栏项目点击事件
  /// 
  /// 功能说明：
  /// 1. 关闭可能打开的弹出菜单
  /// 2. 处理特殊按钮的特殊逻辑（添加、通知）
  /// 3. 执行页面导航或触发相应操作
  /// 4. 支持重复点击返回初始位置
  /// 
  /// 特殊处理：
  /// - 添加按钮：触发创建文档弹窗，不进行页面跳转
  /// - 通知按钮：刷新提醒数据后再跳转
  /// - 其他按钮：正常页面导航
  void _onTap(BuildContext context, int bottomBarIndex) {
    // 关闭任何可能打开的弹出菜单
    closePopupMenu();

    final label = _items[bottomBarIndex].label;
    
    // 添加按钮：触发创建新文档的全局通知器
    if (label == BottomNavigationBarItemType.add.label) {
      mobileCreateNewPageNotifier.value = ViewLayoutPB.Document;
      return;  // 不进行页面导航，只触发创建操作
    } 
    // 通知按钮：先刷新提醒数据
    else if (label == BottomNavigationBarItemType.notification.label) {
      getIt<ReminderBloc>().add(const ReminderEvent.refresh());
    }
    
    // 更新当前选中的导航项
    bottomNavigationBarItemType.value = label;
    
    // 使用goBranch方法进行分支导航
    // 这种方式能确保恢复分支中Navigator的上一次导航状态
    navigationShell.goBranch(
      bottomBarIndex,
      // 支持重复点击当前活动项时返回到初始位置的常见模式
      // 当点击的是当前已选中的项时，initialLocation设为true
      initialLocation: bottomBarIndex == navigationShell.currentIndex,
    );
  }
}

/// 通知操作导航栏组件
/// 
/// 功能说明：
/// 1. 提供批量操作通知的界面
/// 2. 支持标记已读和归档操作
/// 3. 根据选中状态动态启用/禁用按钮
/// 
/// 交互设计：
/// - 无选中项时：按钮变灰且不可点击
/// - 有选中项时：按钮可用且响应操作
/// - 操作完成后：显示成功提示并清空选择
class _NotificationNavigationBar extends StatelessWidget {
  const _NotificationNavigationBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      // TODO: 使用实际高度计算替代固定值
      height: 90,
      decoration: BoxDecoration(
        border: context.border,           // 主题相关边框
        color: context.backgroundColor,   // 主题相关背景色
      ),
      padding: const EdgeInsets.only(bottom: 20),
      child: ValueListenableBuilder(
        // 监听选中的通知ID列表变化
        valueListenable: mSelectedNotificationIds,
        builder: (context, value, child) {
          // 没有选中项时禁用按钮
          if (value.isEmpty) {
            return IgnorePointer(  // 禁用触摸响应
              child: Opacity(
                opacity: 0.3,        // 降低透明度表示禁用状态
                child: child,
              ),
            );
          }

          return child!;  // 有选中项时正常显示按钮
        },
        child: Row(
          children: [
            const HSpace(20),
            // 标记已读按钮
            Expanded(
              child: NavigationBarButton(
                icon: FlowySvgs.m_notification_action_mark_as_read_s,
                text: LocaleKeys.settings_notifications_action_markAsRead.tr(),
                onTap: () => _onMarkAsRead(context),
              ),
            ),
            const HSpace(16),
            // 归档按钮
            Expanded(
              child: NavigationBarButton(
                icon: FlowySvgs.m_notification_action_archive_s,
                text: LocaleKeys.settings_notifications_action_archive.tr(),
                onTap: () => _onArchive(context),
              ),
            ),
            const HSpace(20),
          ],
        ),
      ),
    );
  }

  /// 处理标记已读操作
  /// 
  /// 流程：
  /// 1. 检查是否有选中项
  /// 2. 显示成功提示
  /// 3. 发送标记已读事件到ReminderBloc
  /// 4. 清空选中列表
  void _onMarkAsRead(BuildContext context) {
    if (mSelectedNotificationIds.value.isEmpty) {
      return;
    }

    // 显示操作成功提示
    showToastNotification(
      message: LocaleKeys
          .settings_notifications_markAsReadNotifications_allSuccess
          .tr(),
    );

    // 发送标记已读事件
    getIt<ReminderBloc>()
        .add(ReminderEvent.markAsRead(mSelectedNotificationIds.value));

    // 清空选中列表
    mSelectedNotificationIds.value = [];
  }

  /// 处理归档操作
  /// 
  /// 流程：
  /// 1. 检查是否有选中项
  /// 2. 显示成功提示
  /// 3. 发送归档事件到ReminderBloc
  /// 4. 清空选中列表
  void _onArchive(BuildContext context) {
    if (mSelectedNotificationIds.value.isEmpty) {
      return;
    }

    // 显示操作成功提示
    showToastNotification(
      message: LocaleKeys.settings_notifications_archiveNotifications_allSuccess
          .tr(),
    );

    // 发送归档事件
    getIt<ReminderBloc>()
        .add(ReminderEvent.archive(mSelectedNotificationIds.value));

    // 清空选中列表
    mSelectedNotificationIds.value = [];
  }
}

/// BuildContext扩展，提供导航栏主题相关的颜色和样式
/// 
/// 功能说明：
/// 1. 根据当前主题模式提供合适的背景色
/// 2. 提供边框颜色配置
/// 3. 亮色模式下显示顶部边框，暗色模式下无边框
extension on BuildContext {
  /// 获取导航栏背景色
  /// 
  /// 颜色配置：
  /// - 亮色模式：白色半透明（95%透明度）
  /// - 暗色模式：深灰色半透明（95%透明度）
  Color get backgroundColor {
    return Theme.of(this).isLightMode
        ? Colors.white.withValues(alpha: 0.95)
        : const Color(0xFF23262B).withValues(alpha: 0.95);
  }

  /// 获取边框颜色
  /// 
  /// 颜色配置：
  /// - 亮色模式：浅灰色透明边框
  /// - 暗色模式：深色半透明边框
  Color get borderColor {
    return Theme.of(this).isLightMode
        ? const Color(0x141F2329)
        : const Color(0xFF23262B).withValues(alpha: 0.5);
  }

  /// 获取导航栏边框配置
  /// 
  /// 边框规则：
  /// - 亮色模式：显示顶部边框，增强层次感
  /// - 暗色模式：无边框，保持简洁
  Border? get border {
    return Theme.of(this).isLightMode
        ? Border(top: BorderSide(color: borderColor))
        : null;
  }
}
