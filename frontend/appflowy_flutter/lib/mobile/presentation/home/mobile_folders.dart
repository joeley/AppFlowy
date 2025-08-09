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
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId ??
            '';
    
    return BlocListener<UserWorkspaceBloc, UserWorkspaceState>(
      // 仅在工作区ID变化时监听
      listenWhen: (previous, current) =>
          previous.currentWorkspace?.workspaceId !=
          current.currentWorkspace?.workspaceId,
      listener: (context, state) {
        // 工作区切换时重新初始化侧边栏部分
        context.read<SidebarSectionsBloc>().add(
              SidebarSectionsEvent.initial(
                user,
                state.currentWorkspace?.workspaceId ?? workspaceId,
              ),
            );
        // 重置空间列表
        context.read<SpaceBloc>().add(
              SpaceEvent.reset(
                user,
                state.currentWorkspace?.workspaceId ?? workspaceId,
                false,  // 不自动打开第一个空间
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
        return SlidableAutoCloseBehavior(
          child: Column(
            children: [
              // 根据配置构建空间或文件夹部分
              ..._buildSpaceOrSection(context, state),
              // 底部留白，避免被浮动按钮遮挡
              const VSpace(80.0),
            ],
          ),
        );
      },
    );
  }

  /// 构建空间或文件夹部分
  /// 
  /// 根据以下条件决定显示内容：
  /// 1. 如果有空间配置，显示空间视图
  /// 2. 如果是协作工作区，显示公共和私有文件夹
  /// 3. 如果是个人工作区，仅显示个人文件夹
  /// 
  /// 返回：
  /// - Widget列表，包含相应的视图组件
  List<Widget> _buildSpaceOrSection(
    BuildContext context,
    SidebarSectionsState state,
  ) {
    // 优先显示空间视图（如果有空间配置）
    if (context.watch<SpaceBloc>().state.spaces.isNotEmpty) {
      return [
        const MobileSpace(),
      ];
    }

    // 协作工作区：显示公共和私有两个部分
    if (context.read<UserWorkspaceBloc>().state.isCollabWorkspaceOn) {
      return [
        // 公共文件夹部分
        MobileSectionFolder(
          title: LocaleKeys.sideBar_workspace.tr(),
          spaceType: FolderSpaceType.public,
          views: state.section.publicViews,
        ),
        const VSpace(8.0),
        // 私有文件夹部分
        MobileSectionFolder(
          title: LocaleKeys.sideBar_private.tr(),
          spaceType: FolderSpaceType.private,
          views: state.section.privateViews,
        ),
      ];
    }

    // 个人工作区：仅显示个人文件夹
    return [
      MobileSectionFolder(
        title: LocaleKeys.sideBar_personal.tr(),
        spaceType: FolderSpaceType.public,
        views: state.section.publicViews,
      ),
    ];
  }
}
