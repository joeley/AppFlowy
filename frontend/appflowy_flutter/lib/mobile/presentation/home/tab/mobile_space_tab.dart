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

class _MobileHomePageTabState extends State<MobileHomePageTab>
    with SingleTickerProviderStateMixin {
  /// Tab控制器，管理Tab切换
  TabController? tabController;

  @override
  void initState() {
    super.initState();

    // 监听全局通知器
    mobileCreateNewPageNotifier.addListener(_createNewDocument);  // 创建新文档
    mobileCreateNewAIChatNotifier.addListener(_createNewAIChat);  // 创建新AI聊天
    mobileLeaveWorkspaceNotifier.addListener(_leaveWorkspace);  // 离开工作区
  }

  @override
  void dispose() {
    // 清理Tab控制器
    tabController?.removeListener(_onTabChange);
    tabController?.dispose();

    // 移除全局监听器
    mobileCreateNewPageNotifier.removeListener(_createNewDocument);
    mobileCreateNewAIChatNotifier.removeListener(_createNewAIChat);
    mobileLeaveWorkspaceNotifier.removeListener(_leaveWorkspace);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: widget.userProfile,
      child: MultiBlocListener(
        listeners: [
          // 监听空间中创建的新页面
          BlocListener<SpaceBloc, SpaceState>(
            listenWhen: (p, c) =>
                p.lastCreatedPage?.id != c.lastCreatedPage?.id,
            listener: (context, state) {
              final lastCreatedPage = state.lastCreatedPage;
              if (lastCreatedPage != null) {
                // 导航到新创建的页面
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
          // 监听侧边栏部分中创建的新页面
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
        child: BlocBuilder<SpaceOrderBloc, SpaceOrderState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const SizedBox.shrink();
            }

            _initTabController(state);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MobileSpaceTabBar(
                  tabController: tabController!,
                  tabs: state.tabsOrder,
                  onReorder: (from, to) {
                    context.read<SpaceOrderBloc>().add(
                          SpaceOrderEvent.reorder(from, to),
                        );
                  },
                ),
                const HSpace(12.0),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
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
  void _initTabController(SpaceOrderState state) {
    if (tabController != null) {
      return;
    }
    tabController = TabController(
      length: state.tabsOrder.length,
      vsync: this,
      initialIndex: state.tabsOrder.indexOf(state.defaultTab),  // 设置默认Tab
    );
    tabController?.addListener(_onTabChange);
  }

  /// Tab切换回调
  /// 记录用户最后打开的Tab
  void _onTabChange() {
    if (tabController == null) {
      return;
    }
    // 更新最后打开的Tab索引
    context
        .read<SpaceOrderBloc>()
        .add(SpaceOrderEvent.open(tabController!.index));
  }

  /// 构建Tab页面内容
  /// 
  /// 根据Tab类型返回对应的页面组件：
  /// - recent: 最近访问页面
  /// - spaces: 空间页面（可能包含AI浮动按钮）
  /// - favorites: 收藏页面
  /// - shared: 共享页面
  List<Widget> _buildTabs(SpaceOrderState state) {
    return state.tabsOrder.map((tab) {
      switch (tab) {
        case MobileSpaceTabType.recent:
          return const MobileRecentSpace();
          
        case MobileSpaceTabType.spaces:
          // 仅服务器工作区显示AI浮动按钮
          final showAIFloatingButton =
              widget.userProfile.workspaceType == WorkspaceTypePB.ServerW;
          return Stack(
            children: [
              MobileHomeSpace(userProfile: widget.userProfile),
              // AI聊天浮动按钮
              if (showAIFloatingButton)
                Positioned(
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: FloatingAIEntryV2(),
                ),
            ],
          );
          
        case MobileSpaceTabType.favorites:
          return MobileFavoriteSpace(userProfile: widget.userProfile);
          
        case MobileSpaceTabType.shared:
          final workspaceId = context
              .read<UserWorkspaceBloc>()
              .state
              .currentWorkspace
              ?.workspaceId;
          if (workspaceId == null) {
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
