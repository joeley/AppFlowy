import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/home/section_folder/mobile_home_section_folder.dart';
import 'package:appflowy/mobile/presentation/home/space/mobile_space.dart';
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 移动端文件夹组件
/// 
/// 功能说明：
/// 1. 显示公共和私有部分的文件夹
/// 2. 支持空间视图和传统文件夹视图
/// 3. 监听工作区切换事件
/// 4. 自动适配协作工作区和个人工作区
/// 
/// 显示模式：
/// - 空间模式：显示多个空间
/// - 文件夹模式：显示公共/私有文件夹
/// - 个人模式：仅显示个人文件夹
class MobileFolders extends StatelessWidget {
  const MobileFolders({
    super.key,
    required this.user,
    required this.workspaceId,
    required this.showFavorite,
  });

  /// 用户信息
  final UserProfilePB user;
  
  /// 工作区ID
  final String workspaceId;
  
  /// 是否显示收藏夹
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    // 获取当前工作区ID
    // 如果当前没有工作区，使用传入的workspaceId作为备用
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId ??
            '';
    
    return BlocListener<UserWorkspaceBloc, UserWorkspaceState>(
      // 仅在工作区ID变化时监听，避免不必要的重建
      // 这是一个重要的性能优化，确保只有真正的工作区切换才会触发数据重载
      listenWhen: (previous, current) =>
          previous.currentWorkspace?.workspaceId !=
          current.currentWorkspace?.workspaceId,
      listener: (context, state) {
        // 工作区切换时需要重新初始化相关的BLoC状态
        // 这确保了新工作区的数据能正确加载和显示
        
        // 1. 重新初始化侧边栏部分（收藏夹、最近访问等）
        context.read<SidebarSectionsBloc>().add(
              SidebarSectionsEvent.initial(
                user,
                state.currentWorkspace?.workspaceId ?? workspaceId,
              ),
            );
        // 2. 重置空间列表，清除旧工作区的空间数据
        context.read<SpaceBloc>().add(
              SpaceEvent.reset(
                user,
                state.currentWorkspace?.workspaceId ?? workspaceId,
                false,  // 不自动打开第一个空间，让用户手动选择
              ),
            );
      },
      child: const _MobileFolder(),
    );
  }
}

/// 移动端文件夹内部实现组件
/// 
/// 根据空间配置和工作区类型动态显示不同的布局
class _MobileFolder extends StatefulWidget {
  const _MobileFolder();

  @override
  State<_MobileFolder> createState() => _MobileFolderState();
}

class _MobileFolderState extends State<_MobileFolder> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SidebarSectionsBloc, SidebarSectionsState>(
      builder: (context, state) {
        // 使用SlidableAutoCloseBehavior确保滑动操作的一致性
        // 当用户滑动其他项目时，自动关闭已打开的滑动菜单
        // 这提供了更好的用户体验，避免多个滑动菜单同时打开造成的混乱
        return SlidableAutoCloseBehavior(
          child: Column(
            children: [
              // 根据当前配置和工作区类型构建相应的空间或文件夹部分
              // 这里使用展开操作符将列表中的所有Widget添加到Column中
              ..._buildSpaceOrSection(context, state),
              // 底部留白，避免内容被浮动按钮（如AI聊天按钮）遮挡
              // 80.0的高度足以容纳大部分浮动按钮
              const VSpace(80.0),
            ],
          ),
        );
      },
    );
  }

  /// 构建空间或文件夹部分
  /// 
  /// 这是整个文件夹系统的核心逻辑，根据以下优先级决定显示内容：
  /// 1. 如果有空间配置，优先显示空间视图（新架构）
  /// 2. 如果是协作工作区，显示公共和私有文件夹（传统架构）
  /// 3. 如果是个人工作区，仅显示个人文件夹（简化架构）
  /// 
  /// 架构演进说明：
  /// - 空间(Space)是新的组织方式，提供更灵活的内容组织
  /// - 文件夹(Folder)是传统的组织方式，区分公共/私有访问权限
  /// - 系统优先使用空间架构，向后兼容文件夹架构
  /// 
  /// 返回：
  /// - Widget列表，包含相应的视图组件
  List<Widget> _buildSpaceOrSection(
    BuildContext context,
    SidebarSectionsState state,
  ) {
    // 优先显示空间视图（如果有空间配置）
    // 使用watch而不是read，确保空间数据变化时能及时响应
    if (context.watch<SpaceBloc>().state.spaces.isNotEmpty) {
      return [
        const MobileSpace(),  // 新架构：空间视图
      ];
    }

    // 协作工作区：显示公共和私有两个部分
    // 这种模式下需要区分不同的访问权限和协作范围
    if (context.read<UserWorkspaceBloc>().state.isCollabWorkspaceOn) {
      return [
        // 公共文件夹部分：所有协作成员都可以访问的内容
        MobileSectionFolder(
          title: LocaleKeys.sideBar_workspace.tr(),  // "工作区"
          spaceType: FolderSpaceType.public,
          views: state.section.publicViews,
        ),
        const VSpace(8.0),  // 区块间隔
        // 私有文件夹部分：仅当前用户可以访问的内容
        MobileSectionFolder(
          title: LocaleKeys.sideBar_private.tr(),    // "私有"
          spaceType: FolderSpaceType.private,
          views: state.section.privateViews,
        ),
      ];
    }

    // 个人工作区：仅显示个人文件夹
    // 个人工作区不需要区分公共/私有，所有内容都是个人的
    return [
      MobileSectionFolder(
        title: LocaleKeys.sideBar_personal.tr(),   // "个人"
        spaceType: FolderSpaceType.public,  // 个人工作区使用public类型，但实际上是个人内容
        views: state.section.publicViews,
      ),
    ];
  }
}
