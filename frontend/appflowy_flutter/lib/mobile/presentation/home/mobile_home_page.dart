import 'package:appflowy/features/workspace/data/repositories/rust_workspace_repository_impl.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/home/mobile_home_page_header.dart';
import 'package:appflowy/mobile/presentation/home/tab/mobile_space_tab.dart';
import 'package:appflowy/mobile/presentation/home/tab/space_order_bloc.dart';
import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/shared/loading.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
import 'package:appflowy/workspace/application/menu/sidebar_sections_bloc.dart';
import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/user/user_workspace_bloc.dart';
import 'package:appflowy/workspace/presentation/home/errors/workspace_failed_screen.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy/workspace/presentation/home/menu/menu_shared_state.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

/// 移动端主页屏幕组件
/// 
/// 功能说明：
/// 1. 应用的主要入口点
/// 2. 初始化工作区设置和用户信息
/// 3. 处理加载状态和错误情况
/// 4. 提供用户信息的全局访问
/// 
/// 初始化流程：
/// 1. 获取当前工作区设置
/// 2. 获取用户信息
/// 3. 创建主页UI或显示错误页面
class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key});

  /// 路由名称常量
  static const routeName = '/home';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // 并行获取工作区设置和用户信息
      future: Future.wait([
        FolderEventGetCurrentWorkspaceSetting().send(),
        getIt<AuthService>().getUser(),
      ]),
      builder: (context, snapshots) {
        // 数据加载中显示加载指示器
        if (!snapshots.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // 解析工作区设置
        final workspaceLatest = snapshots.data?[0].fold(
          (workspaceLatestPB) {
            return workspaceLatestPB as WorkspaceLatestPB?;
          },
          (error) => null,
        );
        
        // 解析用户信息
        final userProfile = snapshots.data?[1].fold(
          (userProfilePB) {
            return userProfilePB as UserProfilePB?;
          },
          (error) => null,
        );

        // 处理异常情况：工作区或用户信息获取失败
        // 这种情况很少发生，通常是工作区已经打开时可能出现
        if (workspaceLatest == null || userProfile == null) {
          return const WorkspaceFailedScreen();
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Provider.value(
              value: userProfile,
              child: MobileHomePage(
                userProfile: userProfile,
                workspaceLatest: workspaceLatest,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 当前工作区的全局状态通知器
/// 
/// 用于在整个应用中共享和监听当前工作区的变化
/// 移动端特有的全局状态管理方式
final PropertyValueNotifier<UserWorkspacePB?> mCurrentWorkspace =
    PropertyValueNotifier<UserWorkspacePB?>(null);

/// 移动端主页组件
/// 
/// 功能说明：
/// 1. 初始化BLoC提供器
/// 2. 管理菜单状态和视图变化
/// 3. 处理提醒服务
/// 
/// 状态管理：
/// - UserWorkspaceBloc: 工作区管理
/// - FavoriteBloc: 收藏夹管理
/// - ReminderBloc: 提醒管理
class MobileHomePage extends StatefulWidget {
  const MobileHomePage({
    super.key,
    required this.userProfile,
    required this.workspaceLatest,
  });

  /// 用户信息
  final UserProfilePB userProfile;
  
  /// 最新工作区信息
  final WorkspaceLatestPB workspaceLatest;

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  /// 加载指示器实例
  Loading? loadingIndicator;

  @override
  void initState() {
    super.initState();

    // 监听最新视图变化
    getIt<MenuSharedState>().addLatestViewListener(_onLatestViewChange);
    // 启动提醒服务
    getIt<ReminderBloc>().add(const ReminderEvent.started());
  }

  @override
  void dispose() {
    // 移除视图变化监听器
    getIt<MenuSharedState>().removeLatestViewListener(_onLatestViewChange);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 用户工作区管理
        BlocProvider(
          create: (_) => UserWorkspaceBloc(
            userProfile: widget.userProfile,
            repository: RustWorkspaceRepositoryImpl(
              userId: widget.userProfile.id,
            ),
          )..add(UserWorkspaceEvent.initialize()),
        ),
        // 收藏夹管理
        BlocProvider(
          create: (context) =>
              FavoriteBloc()..add(const FavoriteEvent.initial()),
        ),
        // 提醒服务（使用依赖注入的单例）
        BlocProvider.value(
          value: getIt<ReminderBloc>()..add(const ReminderEvent.started()),
        ),
      ],
      child: _HomePage(userProfile: widget.userProfile),
    );
  }

  /// 处理最新视图变化
  /// 
  /// 当用户打开新视图时，更新后端的最新视图记录
  /// 用于下次启动时恢复到最后打开的视图
  void _onLatestViewChange() async {
    final id = getIt<MenuSharedState>().latestOpenView?.id;
    if (id == null || id.isEmpty) {
      return;
    }
    // 通知后端更新最新视图
    await FolderEventSetLatestView(ViewIdPB(value: id)).send();
  }
}

/// 主页内部实现组件
/// 
/// 功能说明：
/// 1. 监听工作区状态变化
/// 2. 管理空间和侧边栏
/// 3. 显示操作结果提示
/// 
/// UI结构：
/// - 顶部：主页头部
/// - 主体：标签页内容（空间列表）
class _HomePage extends StatefulWidget {
  const _HomePage({required this.userProfile});

  final UserProfilePB userProfile;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  /// 加载指示器实例
  Loading? loadingIndicator;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserWorkspaceBloc, UserWorkspaceState>(
      // 仅在工作区ID变化时重建UI
      buildWhen: (previous, current) =>
          previous.currentWorkspace?.workspaceId !=
          current.currentWorkspace?.workspaceId,
      listener: (context, state) {
        // 重置最近访问服务缓存
        getIt<CachedRecentService>().reset();
        // 更新全局工作区状态
        mCurrentWorkspace.value = state.currentWorkspace;
        
        // 如果搜索功能启用，通知命令面板工作区已变化
        if (FeatureFlag.search.isOn) {
          context.read<CommandPaletteBloc>().add(
                CommandPaletteEvent.workspaceChanged(
                  workspaceId: state.currentWorkspace?.workspaceId,
                ),
              );
        }
        
        // 防抖处理操作结果显示
        Debounce.debounce(
          'workspace_action_result',
          const Duration(milliseconds: 150),
          () {
            _showResultDialog(context, state);
          },
        );
      },
      builder: (context, state) {
        // 无工作区时显示空内容
        if (state.currentWorkspace == null) {
          return const SizedBox.shrink();
        }

        final workspaceId = state.currentWorkspace!.workspaceId;

        return Column(
          // 使用工作区ID作为key，确保切换工作区时重建整个UI
          key: ValueKey('mobile_home_page_$workspaceId'),
          children: [
            // 顶部头部区域：显示用户信息和设置
            Padding(
              padding: const EdgeInsets.only(
                left: HomeSpaceViewSizes.mHorizontalPadding,
                right: 8.0,
              ),
              child: MobileHomePageHeader(
                userProfile: widget.userProfile,
              ),
            ),

            // 主内容区域：标签页
            Expanded(
              child: MultiBlocProvider(
                providers: [
                  // 空间排序管理
                  BlocProvider(
                    create: (_) =>
                        SpaceOrderBloc()..add(const SpaceOrderEvent.initial()),
                  ),
                  // 侧边栏部分管理（收藏、最近等）
                  BlocProvider(
                    create: (_) => SidebarSectionsBloc()
                      ..add(
                        SidebarSectionsEvent.initial(
                          widget.userProfile,
                          workspaceId,
                        ),
                      ),
                  ),
                  // 收藏夹管理（第二个实例）
                  BlocProvider(
                    create: (_) =>
                        FavoriteBloc()..add(const FavoriteEvent.initial()),
                  ),
                  // 空间管理
                  BlocProvider(
                    create: (_) => SpaceBloc(
                      userProfile: widget.userProfile,
                      workspaceId: workspaceId,
                    )..add(
                        const SpaceEvent.initial(
                          openFirstPage: false,  // 移动端不自动打开第一页
                        ),
                      ),
                  ),
                ],
                child: MobileHomePageTab(
                  userProfile: widget.userProfile,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 显示工作区操作结果对话框
  /// 
  /// 功能说明：
  /// 1. 处理加载状态显示
  /// 2. 根据操作类型显示相应提示
  /// 3. 区分成功和失败消息
  /// 
  /// 支持的操作类型：
  /// - open: 打开工作区
  /// - delete: 删除工作区
  /// - leave: 离开工作区
  /// - rename: 重命名工作区
  void _showResultDialog(BuildContext context, UserWorkspaceState state) {
    final actionResult = state.actionResult;
    if (actionResult == null) {
      return;
    }

    Log.info('workspace action result: $actionResult');

    final actionType = actionResult.actionType;
    final result = actionResult.result;
    final isLoading = actionResult.isLoading;

    // 处理加载状态
    if (isLoading) {
      // 显示加载指示器
      loadingIndicator ??= Loading(context)..start();
      return;
    } else {
      // 停止加载指示器
      loadingIndicator?.stop();
      loadingIndicator = null;
    }

    if (result == null) {
      return;
    }

    // 记录错误日志
    result.onFailure((f) {
      Log.error(
        '[Workspace] Failed to perform ${actionType.toString()} action: $f',
      );
    });

    // 根据操作类型生成提示消息
    final String? message;
    ToastificationType toastType = ToastificationType.success;
    switch (actionType) {
      // 打开工作区
      case WorkspaceActionType.open:
        message = result.onFailure((e) {
          toastType = ToastificationType.error;
          return '${LocaleKeys.workspace_openFailed.tr()}: ${e.msg}';
        });
        break;
      
      // 删除工作区
      case WorkspaceActionType.delete:
        message = result.fold(
          (s) {
            toastType = ToastificationType.success;
            return LocaleKeys.workspace_deleteSuccess.tr();
          },
          (e) {
            toastType = ToastificationType.error;
            return '${LocaleKeys.workspace_deleteFailed.tr()}: ${e.msg}';
          },
        );
        break;
      
      // 离开工作区
      case WorkspaceActionType.leave:
        message = result.fold(
          (s) {
            toastType = ToastificationType.success;
            return LocaleKeys
                .settings_workspacePage_leaveWorkspacePrompt_success
                .tr();
          },
          (e) {
            toastType = ToastificationType.error;
            return '${LocaleKeys.settings_workspacePage_leaveWorkspacePrompt_fail.tr()}: ${e.msg}';
          },
        );
        break;
      
      // 重命名工作区
      case WorkspaceActionType.rename:
        message = result.fold(
          (s) {
            toastType = ToastificationType.success;
            return LocaleKeys.workspace_renameSuccess.tr();
          },
          (e) {
            toastType = ToastificationType.error;
            return '${LocaleKeys.workspace_renameFailed.tr()}: ${e.msg}';
          },
        );
        break;
      
      default:
        message = null;
        toastType = ToastificationType.error;
        break;
    }

    // 显示Toast提示
    if (message != null) {
      showToastNotification(message: message, type: toastType);
    }
  }
}
