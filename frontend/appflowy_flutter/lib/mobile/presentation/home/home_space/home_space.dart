import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/mobile/presentation/home/mobile_folders.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端首页空间组件
/// 
/// 功能说明：
/// 1. 作为空间Tab的主要内容容器
/// 2. 显示工作区的文件夹和空间列表
/// 3. 提供可滚动的内容区域
/// 4. 保持页面状态，避免重复构建
/// 
/// 设计思想：
/// - AutomaticKeepAliveClientMixin：保持页面状态，提升切换体验
/// - SingleChildScrollView：支持内容滚动
/// - 响应式布局：适配不同屏幕尺寸和底部安全区域
/// - 委托模式：将实际内容渲染委托给MobileFolders组件
class MobileHomeSpace extends StatefulWidget {
  const MobileHomeSpace({super.key, required this.userProfile});

  /// 用户信息，包含用户ID、工作区类型等关键数据
  final UserProfilePB userProfile;

  @override
  State<MobileHomeSpace> createState() => _MobileHomeSpaceState();
}

class _MobileHomeSpaceState extends State<MobileHomeSpace>
    with AutomaticKeepAliveClientMixin {
  /// 保持页面状态活跃，避免在Tab切换时重建
  /// 
  /// 优点：
  /// 1. 提升用户体验：切换Tab时不会重新加载数据
  /// 2. 保持滚动位置：用户滚动位置在切换后仍然保持
  /// 3. 减少性能开销：避免重复的网络请求和UI构建
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // 调用super.build(context)是AutomaticKeepAliveClientMixin的要求
    super.build(context);
    
    // 获取当前活跃的工作区ID
    // 使用read而不是watch，因为工作区变化时整个页面会重建
    final workspaceId =
        context.read<UserWorkspaceBloc>().state.currentWorkspace?.workspaceId ??
            '';
            
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          // 顶部间距：使用统一的垂直间距配置
          top: HomeSpaceViewSizes.mVerticalPadding,
          // 底部间距：垂直间距 + 设备底部安全区域
          // 确保内容不会被底部导航栏或设备底部遮挡
          bottom: HomeSpaceViewSizes.mVerticalPadding +
              MediaQuery.of(context).padding.bottom,
        ),
        child: MobileFolders(
          user: widget.userProfile,
          workspaceId: workspaceId,
          showFavorite: false,  // 在空间页面不显示收藏夹，收藏夹有专门的Tab
        ),
      ),
    );
  }
}
