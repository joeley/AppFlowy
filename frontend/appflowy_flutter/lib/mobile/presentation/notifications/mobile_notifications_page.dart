// 导入国际化键值文件，用于多语言支持
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端用户配置文件的Bloc状态管理
import 'package:appflowy/mobile/application/user_profile/user_profile_bloc.dart';
// 导入移动端通知Tab标签栏组件
import 'package:appflowy/mobile/presentation/notifications/widgets/mobile_notification_tab_bar.dart';
// 导入应用启动服务和依赖注入容器
import 'package:appflowy/startup/startup.dart';
// 导入通知过滤器的Bloc状态管理
import 'package:appflowy/user/application/notification_filter/notification_filter_bloc.dart';
// 导入提醒功能的Bloc状态管理
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
// 导入侧边栏区域的Bloc状态管理
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
// 导入工作区失败页面
import 'package:appflowy/workspace/presentation/home/errors/workspace_failed_screen.dart';
// 导入提醒扩展方法，用于数据处理
import 'package:appflowy/workspace/presentation/notifications/reminder_extension.dart';
// 导入收件箱操作栏组件
import 'package:appflowy/workspace/presentation/notifications/widgets/inbox_action_bar.dart';
// 导入通知视图组件
import 'package:appflowy/workspace/presentation/notifications/widgets/notification_view.dart';
// 导入视图相关的protobuf数据结构
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// 导入工作区相关的protobuf数据结构
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
// 导入用户相关的protobuf数据结构
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
// 导入国际化插件
import 'package:easy_localization/easy_localization.dart';
// 导入Flutter核心组件库
import 'package:flutter/material.dart';
// 导入Bloc状态管理库
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端通知屏幕组件
/// 
/// 设计思想：
/// 1. 作为通知功能的主入口，负责初始化所有相关的Bloc状态管理器
/// 2. 使用MultiBlocProvider模式，统一管理多个相关的状态
/// 3. 通过SingleTickerProviderStateMixin支持Tab切换动画
/// 4. 将复杂的UI逻辑委托给内部组件，遵循单一职责原则
/// 5. 使用单例ReminderBloc，确保全局通知状态的一致性
class MobileNotificationsScreen extends StatefulWidget {
  const MobileNotificationsScreen({super.key});

  /// 通知页面的路由名称，用于Flutter导航系统
  static const routeName = '/notifications';

  @override
  State<MobileNotificationsScreen> createState() =>
      _MobileNotificationsScreenState();
}

/// MobileNotificationsScreen的私有状态类
/// 混入SingleTickerProviderStateMixin以支持Tab切换的动画效果
class _MobileNotificationsScreenState extends State<MobileNotificationsScreen>
    with SingleTickerProviderStateMixin {
  /// 从依赖注入容器获取全局唯一的ReminderBloc实例
  /// 这确保了整个应用中提醒状态的一致性
  final ReminderBloc reminderBloc = getIt<ReminderBloc>();
  /// Tab控制器，管理“已过期”和“即将到来”两个标签页的切换
  /// length: 2 表示有两个标签页，vsync: this 提供动画同步
  late final TabController controller = TabController(length: 2, vsync: this);

  /// 构建通知屏幕的UI
  /// 
  /// 状态管理策略：
  /// 1. 使用MultiBlocProvider统一管理多个相关的Bloc
  /// 2. UserProfileBloc: 管理用户配置文件和工作区信息
  /// 3. ReminderBloc: 使用全局单例，管理所有提醒数据
  /// 4. NotificationFilterBloc: 管理通知过滤状态
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 创建新的UserProfileBloc实例并自动启动
        BlocProvider<UserProfileBloc>(
          create: (context) =>
              UserProfileBloc()..add(const UserProfileEvent.started()),
        ),
        // 使用已存在的ReminderBloc实例（全局单例模式）
        BlocProvider<ReminderBloc>.value(value: reminderBloc),
        // 创建新的NotificationFilterBloc实例
        BlocProvider<NotificationFilterBloc>(
          create: (_) => NotificationFilterBloc(),
        ),
      ],
      // 监听UserProfileBloc的状态变化，根据不同状态展示相应的UI
      child: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          // 使用freezed生成的maybeWhen方法处理状态分支
          return state.maybeWhen(
            // 默认情况：数据加载中，显示加载指示器
            orElse: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            // 工作区失败情况：显示错误页面
            workspaceFailure: () => const WorkspaceFailedScreen(),
            // 成功情况：显示通知内容
            success: (workspaceLatest, userProfile) =>
                _NotificationScreenContent(
              workspaceLatest: workspaceLatest, // 工作区最新信息
              userProfile: userProfile, // 用户配置文件
              controller: controller, // Tab控制器
              reminderBloc: reminderBloc, // 提醒Bloc实例
            ),
          );
        },
      ),
    );
  }
}

/// 通知屏幕的内容组件
/// 
/// 设计思想：
/// 1. 将UI渲染逻辑与状态管理分离，提高代码可维护性
/// 2. 使用多层嵌套的BlocBuilder模式，实现细粒度的状态监听
/// 3. 采用Tab布局设计，将过去的和即将到来的通知分离展示
/// 4. 使用统一的回调处理函数，遵循单一职责原则
/// 5. 通过数据过滤和排序，为用户提供有组织的信息展示
class _NotificationScreenContent extends StatelessWidget {
  /// 构造函数
  const _NotificationScreenContent({
    required this.workspaceLatest,
    required this.userProfile,
    required this.controller,
    required this.reminderBloc,
  });

  /// 工作区最新信息，包含工作区的配置和元数据
  final WorkspaceLatestPB workspaceLatest;
  /// 用户配置文件，包含用户的基本信息
  final UserProfilePB userProfile;
  /// Tab控制器，用于管理通知标签页的切换
  final TabController controller;
  /// 提醒Bloc实例，用于处理通知相关的业务逻辑
  final ReminderBloc reminderBloc;

  /// 构建通知屏幕的主UI
  /// 
  /// 架构设计：
  /// 1. 创建SidebarSectionsBloc来管理工作区的视图结构
  /// 2. 使用三层BlocBuilder实现细粒度的状态响应
  /// 3. 通过数据过滤和排序，为不同类型的通知提供专门的视图
  @override
  Widget build(BuildContext context) {
    // 为当前组件树提供SidebarSectionsBloc，用于管理工作区的视图结构
    return BlocProvider(
      create: (_) => SidebarSectionsBloc()
        ..add(
          // 初始化侧边栏区域，加载工作区中的所有视图
          SidebarSectionsEvent.initial(
            userProfile,
            workspaceLatest.workspaceId,
          ),
        ),
      // 第一层BlocBuilder：监听侧边栏区域状态，获取工作区中的视图信息
      child: BlocBuilder<SidebarSectionsBloc, SidebarSectionsState>(
        builder: (context, sectionState) =>
            // 第二层BlocBuilder：监听通知过滤器状态，获取过滤条件
            BlocBuilder<NotificationFilterBloc, NotificationFilterState>(
          builder: (context, filterState) =>
              // 第三层BlocBuilder：监听提醒状态，获取实际的通知数据
              BlocBuilder<ReminderBloc, ReminderState>(
            builder: (context, state) {
              // 为了适配主题亮度变化而的重建处理（临时解决方案）
              // 这里读取主题亮度是为了触发组件重新渲染
              Theme.of(context).brightness;

              // 处理过去的提醒数据：过滤 + 排序
              final List<ReminderPB> pastReminders = state.pastReminders
                  .where(
                    // 根据过滤条件决定是否仅显示未读通知
                    (r) => filterState.showUnreadsOnly ? !r.isRead : true,
                  )
                  // 使用扩展方法按计划时间排序
                  .sortByScheduledAt();

              // 处理即将到来的提醒数据：仅需排序（不需过滤，因为都是未来的）
              final List<ReminderPB> upcomingReminders =
                  state.upcomingReminders.sortByScheduledAt();

              // 构建主Scaffold结构
              return Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false, // 不显示默认的返回按钮
                  elevation: 0, // 去除AppBar的阴影效果
                  title: Text(LocaleKeys.notificationHub_mobile_title.tr()), // 显示本地化标题
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      // 移动端Tab标签栏，用于切换过去和未来的通知
                      MobileNotificationTabBar(controller: controller),
                      // 使用Expanded使TabBarView占据剩余的全部空间
                      Expanded(
                        child: TabBarView(
                          controller: controller, // 传递Tab控制器
                          children: [
                            // 第一个标签页：过去的通知（已过期的提醒）
                            NotificationsView(
                              shownReminders: pastReminders, // 显示过滤后的过去提醒
                              reminderBloc: reminderBloc, // 传递Bloc以处理用户操作
                              views: sectionState.section.publicViews, // 工作区的公开视图列表
                              onAction: _onAction, // 点击通知的回调函数
                              onReadChanged: _onReadChanged, // 标记为已读/未读的回调
                              actionBar: InboxActionBar( // 操作栏，包含过滤选项
                                showUnreadsOnly: filterState.showUnreadsOnly,
                              ),
                            ),
                            // 第二个标签页：即将到来的通知（未来的提醒）
                            NotificationsView(
                              shownReminders: upcomingReminders, // 显示排序后的未来提醒
                              reminderBloc: reminderBloc, // 传递Bloc以处理用户操作
                              views: sectionState.section.publicViews, // 工作区的公开视图列表
                              isUpcoming: true, // 标记为未来通知模式
                              onAction: _onAction, // 点击通知的回调函数
                              // 注意：未来通知没有onReadChanged，因为它们还没有发生
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 处理通知点击事件的回调函数
  /// 
  /// 参数说明：
  /// [reminder] 被点击的提醒对象
  /// [path] 可选的路径信息，用于导航
  /// [view] 关联的视图对象，用于跳转到具体的工作区内容
  void _onAction(ReminderPB reminder, int? path, ViewPB? view) =>
      reminderBloc.add(
        // 发送“按下提醒”事件给ReminderBloc处理
        ReminderEvent.pressReminder(
          reminderId: reminder.id, // 提醒ID
          path: path, // 路径信息
          view: view, // 视图信息
        ),
      );

  /// 处理通知已读状态变化的回调函数
  /// 
  /// 参数说明：
  /// [reminder] 需要更新状态的提醒对象
  /// [isRead] 新的已读状态（true表示已读，false表示未读）
  void _onReadChanged(ReminderPB reminder, bool isRead) => reminderBloc.add(
        // 发送“更新提醒”事件给ReminderBloc处理
        ReminderEvent.update(ReminderUpdate(id: reminder.id, isRead: isRead)),
      );
}
