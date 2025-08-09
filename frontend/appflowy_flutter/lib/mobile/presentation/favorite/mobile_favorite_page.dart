// 导入Dart核心IO库，用于平台检测和文件操作
import 'dart:io';

// 导入Rust工作区存储库的实现，用于与后端的Rust服务通信
import 'package:appflowy/features/workspace/data/repositories/rust_workspace_repository_impl.dart';
// 导入工作区Bloc状态管理，处理工作区相关的业务逻辑
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
// 导入移动端收藏文件夹组件，展示收藏内容的核心UI
import 'package:appflowy/mobile/presentation/favorite/mobile_favorite_folder.dart';
// 导入移动端主页头部组件，包含用户信息和快捷操作
import 'package:appflowy/mobile/presentation/home/mobile_home_page_header.dart';
// 导入应用启动服务和依赖注入容器
import 'package:appflowy/startup/startup.dart';
// 导入用户认证服务，用于管理用户登录状态和信息
import 'package:appflowy/user/application/auth/auth_service.dart';
// 导入工作区失败错误页面
import 'package:appflowy/workspace/presentation/home/errors/workspace_failed_screen.dart';
// 导入后端调度器，用于与后端服务的通信
import 'package:appflowy_backend/dispatch/dispatch.dart';
// 导入工作区相关的protobuf数据结构定义
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
// 导入用户相关的protobuf数据结构定义
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
// 导入Flutter的Material Design组件库
import 'package:flutter/material.dart';
// 导入Bloc状态管理库，实现响应式编程
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端收藏屏幕组件
/// 
/// 设计思想：
/// 1. 作为收藏功能的入口点，负责初始化所需的数据和状态
/// 2. 采用异步数据加载模式，并发获取用户信息和工作区设置
/// 3. 使用防御性编程模式，通过null检查确保数据完整性
/// 4. 将复杂的工作区状态管理委托给UserWorkspaceBloc
/// 5. 通过封装MobileFavoritePage实现UI与Bloc的分离
class MobileFavoriteScreen extends StatelessWidget {
  /// 构造函数
  const MobileFavoriteScreen({
    super.key,
  });

  /// 收藏页面的路由名称，用于Flutter导航系统的路由注册
  static const routeName = '/favorite';

  /// 构建收藏屏幕的UI
  /// 
  /// 数据加载策略：
  /// 1. 使用FutureBuilder实现异步数据加载和状态管理
  /// 2. 通过Future.wait并发执行多个异步操作，提高加载效率
  /// 3. 遵循响应式编程原则，根据数据加载状态动态渲染UI
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // 并发执行两个关键的异步操作
      future: Future.wait([
        FolderEventGetCurrentWorkspaceSetting().send(), // 获取当前工作区设置
        getIt<AuthService>().getUser(), // 从依赖注入容器获取用户信息
      ]),
      builder: (context, snapshots) {
        // 检查异步数据是否已加载完成
        if (!snapshots.hasData) {
          // 数据加载中，显示自适应加载指示器（在不同平台显示相应样式）
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // 使用fold方法处理Result类型的返回值，这是函数式错误处理模式
        // 提取工作区最新信息
        final latest = snapshots.data?[0].fold(
          (latest) {
            // 成功情况：转换为WorkspaceLatestPB类型
            return latest as WorkspaceLatestPB?;
          },
          (error) => null, // 失败情况：返回null
        );
        // 提取用户配置文件信息
        final userProfile = snapshots.data?[1].fold(
          (userProfilePB) {
            // 成功情况：转换为UserProfilePB类型
            return userProfilePB as UserProfilePB?;
          },
          (error) => null, // 失败情况：返回null
        );

        // 防御性编程：检查关键数据的有效性
        // 这种情况虽然不常见，但可能在工作区已经打开时出现
        // 通过这种检查确保应用的稳定性和用户体验
        if (latest == null || userProfile == null) {
          return const WorkspaceFailedScreen();
        }

        // 构建主界面结构
        return Scaffold(
          body: SafeArea(
            // 为子组件树提供UserWorkspaceBloc，管理工作区相关状态
            child: BlocProvider(
              create: (_) => UserWorkspaceBloc(
                userProfile: userProfile, // 传入用户配置文件
                // 创建Rust存储库实现，用于与后端服务通信
                repository: RustWorkspaceRepositoryImpl(
                  userId: userProfile.id, // 传入用户ID用于数据关联
                ),
              )..add(
                  // 创建后Bloc后立即发送初始化事件
                  UserWorkspaceEvent.initialize(),
                ),
              // 使用BlocBuilder监听UserWorkspaceBloc的状态变化
              child: BlocBuilder<UserWorkspaceBloc, UserWorkspaceState>(
                // 性能优化：仅在工作区ID变化时才重新构建UI
                // 这避免了不必要的UI重绘，提高了性能
                buildWhen: (previous, current) =>
                    previous.currentWorkspace?.workspaceId !=
                    current.currentWorkspace?.workspaceId,
                builder: (context, state) {
                  // 渲染收藏页面的主体内容
                  return MobileFavoritePage(
                    userProfile: userProfile, // 传递用户配置文件
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 移动端收藏页面的主体实现
/// 
/// 设计思想：
/// 1. 作为一个纯显示UI组件，不包含复杂的状态逻辑
/// 2. 采用垂直布局：上方是用户头部，下方是收藏内容
/// 3. 复用了主页的头部组件，保持了UI的一致性
/// 4. 通过组合模式将收藏具体功能委托给MobileFavoritePageFolder
/// 5. 考虑了不同平台（Android/iOS）的UI差异，提供了自适应的布局
class MobileFavoritePage extends StatelessWidget {
  /// 构造函数
  /// [userProfile] 用户配置文件，包含用户的基本信息和设置
  const MobileFavoritePage({
    super.key,
    required this.userProfile,
  });

  /// 用户配置文件，用于在头部显示用户信息和传递给收藏内容组件
  final UserProfilePB userProfile;

  /// 构建收藏页面的UI结构
  /// 
  /// UI布局设计：
  /// 1. 使用Column垂直布局，从上到下依次排列各个组件
  /// 2. 顶部是用户头部信息，复用了主页的头部组件
  /// 3. 中间是分割线，用于视觉上的分离
  /// 4. 底部是收藏内容区域，占据剩余的所有空间
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 头部区域：包含用户信息和快捷操作
        Padding(
          padding: EdgeInsets.only(
            left: 16, // 左侧内边距
            right: 16, // 右侧内边距
            // 平台适配：Android平台需要额外的顶部边距，iOS则不需要
            top: Platform.isAndroid ? 8.0 : 0.0,
          ),
          child: MobileHomePageHeader(
            userProfile: userProfile, // 传递用户信息用于显示
          ),
        ),
        // 分割线，在头部和内容之间提供视觉分离
        const Divider(),

        // 收藏内容区域：展示用户收藏的文档和文件夹
        Expanded(
          // 使用Expanded使收藏内容区域能够占据剩余的所有可用空间
          child: MobileFavoritePageFolder(
            userProfile: userProfile, // 传递用户信息用于数据加载和权限控制
          ),
        ),
      ],
    );
  }
}
