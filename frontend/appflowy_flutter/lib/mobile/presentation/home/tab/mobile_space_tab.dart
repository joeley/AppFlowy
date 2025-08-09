import 'package:appflowy/features/shared_section/presentation/m_shared_section.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/presentation/home/favorite_folder/favorite_space.dart';
import 'package:appflowy/mobile/presentation/home/home_space/home_space.dart';
import 'package:appflowy/mobile/presentation/home/recent_folder/recent_space.dart';
import 'package:appflowy/mobile/presentation/home/tab/_tab_bar.dart';
import 'package:appflowy/mobile/presentation/home/tab/space_order_bloc.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/mobile/presentation/setting/workspace/invite_members_screen.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'ai_bubble_button.dart';

/// 全局通知器，用于触发创建新的AI聊天
final ValueNotifier<int> mobileCreateNewAIChatNotifier = ValueNotifier(0);

/// 移动端主页Tab页面
/// 
/// 功能说明：
/// 1. 管理多个Tab页面（最近、空间、收藏、共享）
/// 2. 支持Tab重新排序
/// 3. 处理快速创建文档和AI聊天
/// 4. 监听页面创建和工作区事件
/// 
/// 核心功能：
/// - Tab栏管理和切换
/// - 快速创建入口
/// - 工作区相关操作
/// - AI聊天浮动按钮（仅服务器工作区）
/// 
/// 设计思想：
/// 这个组件是AppFlowy移动端的核心导航组件，采用了Tab切换的交互模式。
/// 作者选择使用StatefulWidget而不是StatelessWidget是因为需要管理TabController
/// 的生命周期，这是Flutter中管理动画和状态的标准做法。
class MobileHomePageTab extends StatefulWidget {
  const MobileHomePageTab({
    super.key,
    required this.userProfile,
  });

  /// 用户信息
  final UserProfilePB userProfile;

  @override
  State<MobileHomePageTab> createState() => _MobileHomePageTabState();
}

/// State类，管理Tab页面的状态和生命周期
/// 
/// SingleTickerProviderStateMixin 详解：
/// 这是Flutter动画系统的核心mixin之一，它的作用是：
/// 1. 提供一个TickerProvider给动画控制器（AnimationController）
/// 2. Ticker是Flutter动画的心跳，每一帧都会触发一次
/// 3. Single表示只有一个AnimationController（这里是TabController内部的）
/// 4. 如果有多个动画控制器，需要使用TickerProviderStateMixin
/// 
/// 为什么需要TickerProvider？
/// - TabController内部使用AnimationController来处理Tab切换动画
/// - 动画需要与屏幕刷新率同步（通常60fps）
/// - TickerProvider确保动画只在Widget可见时运行，节省资源
/// - 当Widget不可见时（如切换到其他页面），动画会自动暂停
/// 
/// vsync参数的意义：
/// - vsync是垂直同步（Vertical Synchronization）的缩写
/// - 它确保动画与屏幕刷新同步，避免画面撕裂
/// - 在TabController构造函数中传入this作为vsync参数
class _MobileHomePageTabState extends State<MobileHomePageTab>
    with SingleTickerProviderStateMixin {
  /// Tab控制器，管理Tab切换
  /// 
  /// TabController的核心职责：
  /// 1. 管理当前选中的Tab索引（index）
  /// 2. 处理Tab切换动画（通过内部的AnimationController）
  /// 3. 同步TabBar和TabBarView的状态
  /// 4. 提供Tab切换的编程接口（animateTo、index setter等）
  /// 
  /// 为什么使用可空类型？
  /// - 初始化时需要知道Tab的数量，这个信息来自SpaceOrderBloc的状态
  /// - 在build方法中根据状态动态创建，而不是在initState中创建
  /// - 这种延迟初始化模式确保TabController总是与最新的Tab配置同步
  TabController? tabController;

  @override
  void initState() {
    super.initState();

    // 监听全局通知器
    // 设计思想：使用全局ValueNotifier实现跨组件通信
    // 这种模式允许其他页面（如底部导航栏）触发当前页面的操作
    // 优点：解耦组件间的直接依赖
    // 缺点：需要手动管理监听器的生命周期，避免内存泄漏
    mobileCreateNewPageNotifier.addListener(_createNewDocument);  // 创建新文档
    mobileCreateNewAIChatNotifier.addListener(_createNewAIChat);  // 创建新AI聊天
    mobileLeaveWorkspaceNotifier.addListener(_leaveWorkspace);  // 离开工作区
    
    // 注意：TabController不在这里创建
    // 原因：需要等待SpaceOrderBloc加载完Tab配置
    // 这是Flutter中处理异步依赖的常见模式
  }

  @override
  void dispose() {
    // 清理Tab控制器
    // 重要：必须先移除监听器再dispose控制器
    // 否则可能导致在dispose过程中触发回调，引发错误
    tabController?.removeListener(_onTabChange);
    tabController?.dispose();

    // 移除全局监听器
    // 这是防止内存泄漏的关键步骤
    // Flutter不会自动清理这些监听器，必须手动移除
    mobileCreateNewPageNotifier.removeListener(_createNewDocument);
    mobileCreateNewAIChatNotifier.removeListener(_createNewAIChat);
    mobileLeaveWorkspaceNotifier.removeListener(_leaveWorkspace);

    // 调用父类dispose
    // SingleTickerProviderStateMixin会在这里清理Ticker
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider.value: 向下传递用户信息，使子组件可以访问
    // 这是Flutter中的依赖注入模式，避免层层传递参数
    return Provider.value(
      value: widget.userProfile,
      child: MultiBlocListener(
        // MultiBlocListener允许同时监听多个BLoC的状态变化
        // 这是BLoC架构的核心模式：UI响应业务逻辑层的状态变化
        listeners: [
          // 监听空间中创建的新页面
          // 设计意图：当用户在空间中创建新页面后，自动导航到该页面
          BlocListener<SpaceBloc, SpaceState>(
            // listenWhen: 性能优化，只在lastCreatedPage改变时触发
            // 比较前后状态的id，避免不必要的重复导航
            listenWhen: (p, c) =>
                p.lastCreatedPage?.id != c.lastCreatedPage?.id,
            listener: (context, state) {
              final lastCreatedPage = state.lastCreatedPage;
              if (lastCreatedPage != null) {
                // 导航到新创建的页面
                // pushView是扩展方法，封装了GoRouter的导航逻辑
                context.pushView(
                  lastCreatedPage,
                  // 图标选择器的Tab配置
                  // 允许用户为新页面选择emoji、图标或自定义图片
                  tabs: [
                    PickerTabType.emoji,
                    PickerTabType.icon,
                    PickerTabType.custom,
                  ].map((e) => e.name).toList(),
                );
              }
            },
          ),
          // 监听侧边栏部分中创建的新页面
          // 设计意图：统一处理不同来源的页面创建事件
          BlocListener<SidebarSectionsBloc, SidebarSectionsState>(
            listenWhen: (p, c) =>
                p.lastCreatedRootView?.id != c.lastCreatedRootView?.id,
            listener: (context, state) {
              final lastCreatedPage = state.lastCreatedRootView;
              if (lastCreatedPage != null) {
                // 导航到新创建的根视图
                context.pushView(
                  lastCreatedPage,
                  tabs: [
                    PickerTabType.emoji,
                    PickerTabType.icon,
                    PickerTabType.custom,
                  ].map((e) => e.name).toList(),
                );
              }
            },
          ),
        ],
        // BlocBuilder: 根据SpaceOrderBloc的状态构建UI
        // 这是BLoC模式的核心：状态驱动UI渲染
        child: BlocBuilder<SpaceOrderBloc, SpaceOrderState>(
          builder: (context, state) {
            // 加载中时显示空组件
            // SizedBox.shrink()是Flutter中表示空组件的惯用方式
            if (state.isLoading) {
              return const SizedBox.shrink();
            }

            // 在每次build时检查并初始化TabController
            // 这确保TabController始终与最新的Tab配置同步
            _initTabController(state);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tab栏组件
                // 设计要点：
                // 1. 将TabController传递给子组件，实现状态共享
                // 2. 支持拖拽重排序，提供个性化体验
                // 3. Tab配置由状态管理，符合单一数据源原则
                MobileSpaceTabBar(
                  tabController: tabController!,  // 非空断言，因为已在上面初始化
                  tabs: state.tabsOrder,  // Tab列表和顺序
                  onReorder: (from, to) {  // 重排序回调
                    // 通过Bloc处理重排序逻辑
                    // from: 原位置索引, to: 目标位置索引
                    context.read<SpaceOrderBloc>().add(
                          SpaceOrderEvent.reorder(from, to),
                        );
                  },
                ),
                const HSpace(12.0),
                // Tab内容区域
                // Expanded确保TabBarView占据剩余的所有空间
                Expanded(
                  child: TabBarView(
                    // 关键：TabBarView和TabBar共享同一个TabController
                    // 这确保了两者的状态同步：
                    // - 点击Tab时，内容会切换
                    // - 滑动内容时，Tab指示器会移动
                    controller: tabController,
                    
                    // children必须与TabBar的tabs数量一致
                    // 顺序也必须对应，这是TabController的约束
                    children: _buildTabs(state),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 初始化Tab控制器
  /// 
  /// 功能说明：
  /// 1. 创建TabController
  /// 2. 设置初始索引为默认Tab
  /// 3. 添加Tab切换监听器
  /// 
  /// 设计思想：
  /// - 延迟初始化：只在第一次需要时创建，避免重复创建
  /// - 单例模式：通过if检查确保只创建一次
  /// - 状态同步：TabController的配置完全由SpaceOrderState决定
  void _initTabController(SpaceOrderState state) {
    // 防止重复初始化
    if (tabController != null) {
      return;
    }
    
    // 创建TabController
    // 关键参数说明：
    tabController = TabController(
      // length: Tab的总数，必须与TabBar和TabBarView的子组件数量一致
      length: state.tabsOrder.length,
      
      // vsync: TickerProvider，用于驱动动画
      // this指向当前State，它混入了SingleTickerProviderStateMixin
      // TabController内部会用这个创建AnimationController
      vsync: this,
      
      // initialIndex: 初始选中的Tab索引
      // 使用indexOf查找默认Tab在数组中的位置
      // 这确保了用户每次打开应用时看到的是他们期望的Tab
      initialIndex: state.tabsOrder.indexOf(state.defaultTab),
    );
    
    // 添加监听器，跟踪用户的Tab切换行为
    // 这用于记住用户最后访问的Tab，提供更好的用户体验
    tabController?.addListener(_onTabChange);
  }

  /// Tab切换回调
  /// 记录用户最后打开的Tab
  /// 
  /// 触发时机：
  /// 1. 用户点击TabBar切换Tab
  /// 2. 用户滑动TabBarView切换页面
  /// 3. 程序调用tabController.animateTo或设置index
  /// 
  /// 设计目的：
  /// - 持久化用户偏好，下次打开应用时恢复到最后使用的Tab
  /// - 为数据分析提供用户行为数据
  void _onTabChange() {
    if (tabController == null) {
      return;
    }
    
    // 通过Bloc更新状态
    // 这里体现了Flutter的单向数据流架构：
    // UI事件 -> Bloc事件 -> 状态更新 -> UI重建
    context
        .read<SpaceOrderBloc>()
        .add(SpaceOrderEvent.open(tabController!.index));
  }

  /// 构建Tab页面内容
  /// 
  /// 这是整个主页的核心内容渲染逻辑，根据Tab类型返回对应的页面组件：
  /// - recent: 最近访问页面 - 显示用户最近打开的文档和页面
  /// - spaces: 空间页面 - 显示工作区中的所有空间和文件夹
  /// - favorites: 收藏页面 - 显示用户收藏的所有内容
  /// - shared: 共享页面 - 显示与其他用户共享的内容
  /// 
  /// 特殊功能：
  /// - 服务器工作区的空间页面会显示AI聊天浮动按钮
  List<Widget> _buildTabs(SpaceOrderState state) {
    return state.tabsOrder.map((tab) {
      switch (tab) {
        case MobileSpaceTabType.recent:
          return const MobileRecentSpace();
          
        case MobileSpaceTabType.spaces:
          // 仅在服务器工作区（云端工作区）显示AI浮动按钮
          // 本地工作区不支持AI功能，因为需要云端服务支持
          final showAIFloatingButton =
              widget.userProfile.workspaceType == WorkspaceTypePB.ServerW;
          return Stack(
            children: [
              // 主要内容：空间和文件夹列表
              MobileHomeSpace(userProfile: widget.userProfile),
              // AI聊天浮动按钮（仅在服务器工作区显示）
              if (showAIFloatingButton)
                Positioned(
                  right: 20,  // 右侧边距
                  // 底部位置 = 设备底部安全区域 + 额外间距
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: FloatingAIEntryV2(),  // AI聊天入口按钮
                ),
            ],
          );
          
        case MobileSpaceTabType.favorites:
          return MobileFavoriteSpace(userProfile: widget.userProfile);
          
        case MobileSpaceTabType.shared:
          // 共享页面需要工作区ID来加载共享内容
          final workspaceId = context
              .read<UserWorkspaceBloc>()
              .state
              .currentWorkspace
              ?.workspaceId;
          if (workspaceId == null) {
            // 没有工作区ID时显示空组件
            return const SizedBox.shrink();
          }
          return MSharedSection(
            workspaceId: workspaceId,
          );
      }
    }).toList();
  }

  /// 快速创建新文档
  /// 响应导航栏的添加按钮点击
  void _createNewDocument() => _createNewPage(ViewLayoutPB.Document);

  /// 快速创建新AI聊天
  void _createNewAIChat() => _createNewPage(ViewLayoutPB.Chat);

  /// 创建新页面的通用方法
  /// 
  /// 功能说明：
  /// 1. 优先在空间中创建
  /// 2. 如果没有空间，在侧边栏部分创建（仅支持文档）
  /// 3. 创建后自动打开新页面
  void _createNewPage(ViewLayoutPB layout) {
    if (context.read<SpaceBloc>().state.spaces.isNotEmpty) {
      // 在空间中创建页面
      context.read<SpaceBloc>().add(
            SpaceEvent.createPage(
              name: '',
              layout: layout,
              openAfterCreate: true,  // 创建后自动打开
            ),
          );
    } else if (layout == ViewLayoutPB.Document) {
      // 只有文档类型支持在部分中创建
      context.read<SidebarSectionsBloc>().add(
            SidebarSectionsEvent.createRootViewInSection(
              name: '',
              index: 0,
              viewSection: FolderSpaceType.public.toViewSectionPB,
            ),
          );
    }
  }

  /// 离开当前工作区
  /// 
  /// 处理用户离开工作区的请求
  void _leaveWorkspace() {
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId;
    if (workspaceId == null) {
      return Log.error('Workspace ID is null');
    }
    // 发送离开工作区事件
    context
        .read<UserWorkspaceBloc>()
        .add(UserWorkspaceEvent.leaveWorkspace(workspaceId: workspaceId));
  }
}
