// 导入相关依赖包
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/presentation/home/shared/empty_placeholder.dart';
import 'package:appflowy/mobile/presentation/home/shared/mobile_page_card.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端收藏页面空间组件
/// 
/// 功能说明：
/// 1. 管理和显示用户收藏的页面列表
/// 2. 支持页面状态保持（AutomaticKeepAliveClientMixin）
/// 3. 监听工作空间变化并刷新收藏列表
/// 4. 提供空状态展示和页面导航功能
/// 
/// 设计思想：
/// - 使用MultiBlocProvider管理多个BLoC状态
/// - 通过BlocListener监听状态变化并处理导航
/// - 采用反转列表显示最新收藏的页面
/// - 集成空状态占位符提升用户体验
class MobileFavoriteSpace extends StatefulWidget {
  const MobileFavoriteSpace({
    super.key,
    required this.userProfile,
  });

  /// 用户配置信息
  final UserProfilePB userProfile;

  @override
  State<MobileFavoriteSpace> createState() => _MobileFavoriteSpaceState();
}

/// 移动端收藏空间状态类
/// 
/// 使用AutomaticKeepAliveClientMixin保持页面状态，避免重建时丢失数据
class _MobileFavoriteSpaceState extends State<MobileFavoriteSpace>
    with AutomaticKeepAliveClientMixin {
  /// 保持页面状态活跃，避免因切换Tab而重建页面
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // 调用super.build以支持AutomaticKeepAliveClientMixin
    super.build(context);
    // 获取当前工作空间ID，如果没有则使用空字符串
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId ??
            '';
    return MultiBlocProvider(
      providers: [
        // 侧边栏分区BLoC，管理页面分区状态
        BlocProvider(
          create: (_) => SidebarSectionsBloc()
            ..add(
              SidebarSectionsEvent.initial(widget.userProfile, workspaceId),
            ),
        ),
        // 收藏BLoC，管理收藏页面的状态和操作
        BlocProvider(
          create: (_) => FavoriteBloc()..add(const FavoriteEvent.initial()),
        ),
      ],
      // 监听工作空间变化，当工作空间切换时刷新收藏列表
      child: BlocListener<UserWorkspaceBloc, UserWorkspaceState>(
        listener: (context, state) =>
            // 工作空间变化时重新初始化收藏列表
            context.read<FavoriteBloc>().add(const FavoriteEvent.initial()),
        child: MultiBlocListener(
          listeners: [
            // 监听侧边栏分区状态变化
            BlocListener<SidebarSectionsBloc, SidebarSectionsState>(
              // 只有当最新创建的根页面ID发生变化时才监听
              listenWhen: (p, c) =>
                  p.lastCreatedRootView?.id != c.lastCreatedRootView?.id,
              // 导航到新创建的页面
              listener: (context, state) =>
                  context.pushView(state.lastCreatedRootView!),
            ),
          ],
          child: Builder(
            builder: (context) {
              // 监听收藏状态变化
              final favoriteState = context.watch<FavoriteBloc>().state;

              // 如果正在加载，显示空的占位符
              if (favoriteState.isLoading) {
                return const SizedBox.shrink();
              }

              // 如果没有收藏的页面，显示空状态占位符
              if (favoriteState.views.isEmpty) {
                return const EmptySpacePlaceholder(
                  type: MobilePageCardType.favorite,
                );
              }

              // 显示收藏页面列表，reversed()使最新收藏的页面显示在顶部
              return _FavoriteViews(
                favoriteViews: favoriteState.views.reversed.toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 收藏页面列表显示组件
/// 
/// 功能说明：
/// 1. 以ListView形式展示收藏的页面
/// 2. 每个页面项之间有分隔线
/// 3. 底部留出额外空间避免被导航栏遮挡
/// 
/// 设计思想：
/// - 使用PageStorageKey保持滚动位置
/// - 根据主题模式动态调整分隔线颜色
/// - 统一的内边距和视觉样式
class _FavoriteViews extends StatelessWidget {
  const _FavoriteViews({
    required this.favoriteViews,
  });

  /// 收藏页面列表数据
  final List<SectionViewPB> favoriteViews;

  @override
  Widget build(BuildContext context) {
    // 根据主题模式设置分隔线颜色
    final borderColor = Theme.of(context).isLightMode
        ? const Color(0xFFE9E9EC)        // 浅色模式：浅灰色
        : const Color(0x1AFFFFFF);       // 深色模式：半透明白色
    return ListView.separated(
      // 使用PageStorageKey保持滚动位置状态
      key: const PageStorageKey('favorite_views_page_storage_key'),
      // 底部内边距，避免内容被底部导航栏遮挡
      padding: EdgeInsets.only(
        bottom: HomeSpaceViewSizes.mVerticalPadding +
            MediaQuery.of(context).padding.bottom,
      ),
      itemBuilder: (context, index) {
        // 获取当前索引对应的收藏页面
        final view = favoriteViews[index];
        return Container(
          // 垂直内边距增加点击区域
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          // 底部边框分隔线装饰
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 0.5,
              ),
            ),
          ),
          // 移动端页面卡片，显示页面详细信息
          child: MobileViewPage(
            key: ValueKey(view.item.id),    // 使用页面ID作为唯一标识
            view: view.item,                // 页面数据
            timestamp: view.timestamp,       // 收藏时间戳
            type: MobilePageCardType.favorite, // 标记为收藏类型
          ),
        );
      },
      // 项目间分隔符（水平空间）
      separatorBuilder: (context, index) => const HSpace(8),
      // 列表项目数量
      itemCount: favoriteViews.length,
    );
  }
}
