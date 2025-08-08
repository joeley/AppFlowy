import 'package:appflowy/features/workspace/data/repositories/rust_workspace_repository_impl.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/plugins/blank/blank.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/memory_leak_detector.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
import 'package:appflowy/workspace/application/home/home_bloc.dart';
import 'package:appflowy/workspace/application/home/home_setting_bloc.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/user/user_workspace_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/presentation/command_palette/command_palette.dart';
import 'package:appflowy/workspace/presentation/home/af_focus_manager.dart';
import 'package:appflowy/workspace/presentation/home/errors/workspace_failed_screen.dart';
import 'package:appflowy/workspace/presentation/home/hotkeys.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/sidebar.dart';
import 'package:appflowy/workspace/presentation/widgets/edit_panel/panel_animation.dart';
import 'package:appflowy/workspace/presentation/widgets/float_bubble/question_bubble.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart'
    show UserProfilePB;
import 'package:collection/collection.dart';
import 'package:flowy_infra_ui/style_widget/container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sized_context/sized_context.dart';
import 'package:styled_widget/styled_widget.dart';

import '../notifications/notification_panel.dart';
import '../widgets/edit_panel/edit_panel.dart';
import '../widgets/sidebar_resizer.dart';
import 'home_layout.dart';
import 'home_stack.dart';
import 'menu/sidebar/slider_menu_hover_trigger.dart';

/*
 * 桌面端主页面
 * 
 * AppFlowy桌面端的核心容器页面，负责：
 * 1. 初始化和管理所有主要的BLoC实例
 * 2. 组装侧边栏、主内容区、编辑面板等UI组件
 * 3. 处理工作区切换和视图加载
 * 4. 管理布局动画和响应式设计
 * 
 * 架构设计：
 * - 采用组合模式构建复杂的UI布局
 * - 使用BLoC模式管理状态
 * - 通过FutureBuilder异步加载工作区数据
 * - 使用Stack和Positioned实现灵活布局
 */
class DesktopHomeScreen extends StatelessWidget {
  const DesktopHomeScreen({super.key});

  static const routeName = '/DesktopHomeScreen';

  @override
  Widget build(BuildContext context) {
    /* 异步加载工作区设置和用户信息 */
    return FutureBuilder(
      future: Future.wait([
        FolderEventGetCurrentWorkspaceSetting().send(),  /* 获取当前工作区设置 */
        getIt<AuthService>().getUser(),  /* 获取当前用户信息 */
      ]),
      builder: (context, snapshots) {
        if (!snapshots.hasData) {
          return _buildLoading();
        }

        final workspaceLatest = snapshots.data?[0].fold(
          (workspaceLatestPB) => workspaceLatestPB as WorkspaceLatestPB,
          (error) => null,
        );

        final userProfile = snapshots.data?[1].fold(
          (userProfilePB) => userProfilePB as UserProfilePB,
          (error) => null,
        );

        /* 
         * 处理异常情况：工作区或用户信息为空
         * 这种情况可能在工作区已打开时发生
         */
        if (workspaceLatest == null || userProfile == null) {
          return const WorkspaceFailedScreen();
        }

        /*
         * 构建主页面结构
         * 使用AFFocusManager管理焦点，MultiBlocProvider提供全局状态
         */
        return AFFocusManager(
          child: MultiBlocProvider(
            key: ValueKey(userProfile.id),  /* 使用用户ID作为key，确保用户切换时重建 */
            providers: [
              /* 提醒服务BLoC */
              BlocProvider.value(
                value: getIt<ReminderBloc>(),
              ),
              /* 标签页管理BLoC */
              BlocProvider<TabsBloc>.value(value: getIt<TabsBloc>()),
              /* 主页状态管理BLoC */
              BlocProvider<HomeBloc>(
                create: (_) =>
                    HomeBloc(workspaceLatest)..add(const HomeEvent.initial()),
              ),
              /* 主页设置管理BLoC（侧边栏宽度、面板显示等） */
              BlocProvider<HomeSettingBloc>(
                create: (_) => HomeSettingBloc(
                  workspaceLatest,
                  context.read<AppearanceSettingsCubit>(),
                  context.widthPx,
                )..add(const HomeSettingEvent.initial()),
              ),
              /* 收藏夹管理BLoC */
              BlocProvider<FavoriteBloc>(
                create: (context) =>
                    FavoriteBloc()..add(const FavoriteEvent.initial()),
              ),
            ],
            child: Scaffold(
              /* 内存泄漏检测按钮（调试模式） */
              floatingActionButton: enableMemoryLeakDetect
                  ? const FloatingActionButton(
                      onPressed: dumpMemoryLeak,
                      child: Icon(Icons.memory),
                    )
                  : null,
              body: BlocListener<HomeBloc, HomeState>(
                listenWhen: (p, c) => p.latestView != c.latestView,
                listener: (context, state) {
                  final view = state.latestView;
                  if (view != null) {
                    /*
                     * 打开最后访问的视图
                     * 只有当前页面管理器的插件是空白页且最后打开的视图不为空时才打开
                     * 主页面显示的所有部件都以插件形式存在（看板、表格、垃圾桶等）
                     */
                    final currentPageManager =
                        context.read<TabsBloc>().state.currentPageManager;

                    if (currentPageManager.plugin.pluginType ==
                        PluginType.blank) {
                      getIt<TabsBloc>().add(
                        TabsEvent.openPlugin(plugin: view.plugin()),
                      );
                    }

                    /* 切换到包含最后打开视图的空间 */
                    _switchToSpace(view);
                  }
                },
                child: BlocBuilder<HomeSettingBloc, HomeSettingState>(
                  buildWhen: (previous, current) => previous != current,
                  builder: (context, state) => BlocProvider(
                    create: (_) => UserWorkspaceBloc(
                      userProfile: userProfile,
                      repository: RustWorkspaceRepositoryImpl(
                        userId: userProfile.id,
                      ),
                    )..add(UserWorkspaceEvent.initialize()),
                    child: BlocListener<UserWorkspaceBloc, UserWorkspaceState>(
                      listenWhen: (previous, current) =>
                          previous.currentWorkspace != current.currentWorkspace,
                      listener: (context, state) {
                        if (!context.mounted) return;
                        final workspaceBloc =
                            context.read<UserWorkspaceBloc?>();
                        final spaceBloc = context.read<SpaceBloc?>();
                        CommandPalette.maybeOf(context)?.updateBlocs(
                          workspaceBloc: workspaceBloc,
                          spaceBloc: spaceBloc,
                        );
                      },
                      child: HomeHotKeys(
                        userProfile: userProfile,
                        child: FlowyContainer(
                          Theme.of(context).colorScheme.surface,
                          child: _buildBody(
                            context,
                            userProfile,
                            workspaceLatest,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /* 构建加载中UI */
  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator.adaptive());

  /*
   * 构建主页面主体
   * 
   * 组装所有UI组件，包括：
   * - 侧边栏（导航菜单）
   * - 主内容栈（标签页内容）
   * - 编辑面板（属性编辑）
   * - 通知面板
   * - 悬浮组件（帮助气泡等）
   */
  Widget _buildBody(
    BuildContext context,
    UserProfilePB userProfile,
    WorkspaceLatestPB workspaceSetting,
  ) {
    final layout = HomeLayout(context);  /* 布局管理器 */
    final homeStack = HomeStack(  /* 主内容栈（标签页容器） */
      layout: layout,
      delegate: DesktopHomeScreenStackAdaptor(context),
      userProfile: userProfile,
    );
    final sidebar = _buildHomeSidebar(  /* 侧边栏菜单 */
      context,
      layout: layout,
      userProfile: userProfile,
      workspaceSetting: workspaceSetting,
    );
    final notificationPanel = NotificationPanel();  /* 通知面板 */
    final sliderHoverTrigger = SliderMenuHoverTrigger();  /* 侧边栏悬停触发器 */

    /* 侧边栏调整器（拖动调整宽度） */
    final homeMenuResizer =
        layout.showMenu ? const SidebarResizer() : const SizedBox.shrink();
    final editPanel = _buildEditPanel(context, layout: layout);  /* 属性编辑面板 */

    return _layoutWidgets(
      layout: layout,
      homeStack: homeStack,
      sidebar: sidebar,
      editPanel: editPanel,
      bubble: const QuestionBubble(),
      homeMenuResizer: homeMenuResizer,
      notificationPanel: notificationPanel,
      sliderHoverTrigger: sliderHoverTrigger,
    );
  }

  /*
   * 构建侧边栏
   * 
   * 包含用户信息、工作区切换、页面导航树等
   * 使用FocusTraversalGroup管理键盘导航
   * RepaintBoundary优化重绘性能
   */
  Widget _buildHomeSidebar(
    BuildContext context, {
    required HomeLayout layout,
    required UserProfilePB userProfile,
    required WorkspaceLatestPB workspaceSetting,
  }) {
    final homeMenu = HomeSideBar(
      userProfile: userProfile,
      workspaceSetting: workspaceSetting,
    );
    return FocusTraversalGroup(child: RepaintBoundary(child: homeMenu));
  }

  /*
   * 构建编辑面板
   * 
   * 显示选中项的属性编辑器
   * 根据panelContext动态显示/隐藏
   */
  Widget _buildEditPanel(
    BuildContext context, {
    required HomeLayout layout,
  }) {
    final homeBloc = context.read<HomeSettingBloc>();
    return BlocBuilder<HomeSettingBloc, HomeSettingState>(
      buildWhen: (previous, current) =>
          previous.panelContext != current.panelContext,
      builder: (context, state) {
        final panelContext = state.panelContext;
        if (panelContext == null) {
          return const SizedBox.shrink();
        }

        return FocusTraversalGroup(
          child: RepaintBoundary(
            child: EditPanel(
              panelContext: panelContext,
              onEndEdit: () => homeBloc.add(
                const HomeSettingEvent.dismissEditPanel(),
              ),
            ),
          ),
        );
      },
    );
  }

  /*
   * 布局所有组件
   * 
   * 使用Stack和Positioned实现复杂布局：
   * - 主内容区域可伸缩
   * - 侧边栏、编辑面板支持动画滑入/滑出
   * - 悬浮组件固定定位
   * 
   * 动画设计：
   * - 使用animatedPanelX实现面板滑动动画
   * - 所有位置变化都带有缓动动画效果
   */
  Widget _layoutWidgets({
    required HomeLayout layout,
    required Widget sidebar,
    required Widget homeStack,
    required Widget editPanel,
    required Widget bubble,
    required Widget homeMenuResizer,
    required Widget notificationPanel,
    required Widget sliderHoverTrigger,
  }) {
    final isSliderbarShowing = layout.showMenu;
    return Stack(
      children: [
        /* 主内容区域 - 最小宽度500px，根据侧边栏和编辑面板自适应 */
        homeStack
            .constrained(minWidth: 500)
            .positioned(
              left: layout.homePageLOffset,
              right: layout.homePageROffset,
              bottom: 0,
              top: 0,
              animate: true,
            )
            .animate(layout.animDuration, Curves.easeOutQuad),
        /* 帮助气泡 - 固定在右下角 */
        bubble
            .positioned(right: 20, bottom: 16, animate: true)
            .animate(layout.animDuration, Curves.easeOut),
        /* 编辑面板 - 从右侧滑入 */
        editPanel
            .animatedPanelX(
              duration: layout.animDuration.inMilliseconds * 0.001,
              closeX: layout.editPanelWidth,
              isClosed: !layout.showEditPanel,
              curve: Curves.easeOutQuad,
            )
            .positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: layout.editPanelWidth,
            ),
        /* 通知面板 - 从左侧滑入，位置随侧边栏调整 */
        notificationPanel
            .animatedPanelX(
              closeX: -layout.notificationPanelWidth,
              isClosed: !layout.showNotificationPanel,
              curve: Curves.easeOutQuad,
              duration: layout.animDuration.inMilliseconds * 0.001,
            )
            .positioned(
              left: isSliderbarShowing ? layout.menuWidth : 0,
              top: isSliderbarShowing ? 0 : 52,
              width: layout.notificationPanelWidth,
              bottom: 0,
            ),
        /* 侧边栏 - 从左侧滑入/滑出 */
        sidebar
            .animatedPanelX(
              closeX: -layout.menuWidth,
              isClosed: !isSliderbarShowing,
              curve: Curves.easeOutQuad,
              duration: layout.animDuration.inMilliseconds * 0.001,
            )
            .positioned(left: 0, top: 0, width: layout.menuWidth, bottom: 0),
        /* 侧边栏宽度调整器 - 位于侧边栏右边缘 */
        homeMenuResizer
            .positioned(left: layout.menuWidth)
            .animate(layout.animDuration, Curves.easeOutQuad),
      ],
    );
  }

  /*
   * 切换到指定视图所在的空间
   * 
   * 查找视图的祖先节点，找到所属的空间并切换
   */
  Future<void> _switchToSpace(ViewPB view) async {
    final ancestors = await ViewBackendService.getViewAncestors(view.id);
    final space = ancestors.fold(
      (ancestors) =>
          ancestors.items.firstWhereOrNull((ancestor) => ancestor.isSpace),
      (error) => null,
    );
    if (space?.id != switchToSpaceNotifier.value?.id) {
      switchToSpaceNotifier.value = space;
    }
  }
}

/*
 * 桌面端主页栈适配器
 * 
 * 实现HomeStackDelegate接口，处理视图删除时的逻辑：
 * 1. 查找被删除视图的父视图
 * 2. 打开合适的替代视图（兄弟视图或空白页）
 * 3. 维护标签页的连续性
 */
class DesktopHomeScreenStackAdaptor extends HomeStackDelegate {
  DesktopHomeScreenStackAdaptor(this.buildContext);

  final BuildContext buildContext;

  /*
   * 处理视图删除事件
   * 
   * 当视图被删除时，自动选择下一个合适的视图：
   * 1. 优先选择相邻的兄弟视图
   * 2. 如果没有兄弟视图，显示空白页
   * 
   * @param view 被删除的视图
   * @param index 视图在父级中的索引
   */
  @override
  void didDeleteStackWidget(ViewPB view, int? index) {
    ViewBackendService.getView(view.parentViewId).then(
      (result) => result.fold(
        (parentView) {
          final List<ViewPB> views = parentView.childViews;
          if (views.isNotEmpty) {
            ViewPB lastView = views.last;
            if (index != null && index != 0 && views.length > index - 1) {
              lastView = views[index - 1];
            }

            return getIt<TabsBloc>()
                .add(TabsEvent.openPlugin(plugin: lastView.plugin()));
          }

          getIt<TabsBloc>()
              .add(TabsEvent.openPlugin(plugin: BlankPagePlugin()));
        },
        (err) => Log.error(err),
      ),
    );
  }
}
