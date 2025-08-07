// 云环境配置
import 'package:appflowy/env/cloud_env.dart';
// SVG图标资源（自动生成）
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 启动模块，用于获取依赖注入
import 'package:appflowy/startup/startup.dart';
// 认证服务
import 'package:appflowy/user/application/auth/auth_service.dart';
// 闪屏页BLoC
import 'package:appflowy/user/application/splash_bloc.dart';
// 认证状态定义
import 'package:appflowy/user/domain/auth_state.dart';
// 辅助函数
import 'package:appflowy/user/presentation/helpers/helpers.dart';
// 路由管理
import 'package:appflowy/user/presentation/router.dart';
// 其他页面
import 'package:appflowy/user/presentation/screens/screens.dart';
// 后端事件分发
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:flutter/material.dart';
// BLoC状态管理库
import 'package:flutter_bloc/flutter_bloc.dart';
// 路由库
import 'package:go_router/go_router.dart';
// 平台检测
import 'package:universal_platform/universal_platform.dart';

/// 闪屏页 - 应用的根页面
/// 
/// 这是用户看到的第一个页面，负责：
/// 1. 显示应用Logo和加载动画
/// 2. 检查用户认证状态
/// 3. 根据认证状态跳转到相应页面
/// 
/// 设计模式：BLoC模式
/// - 使用SplashBloc管理状态
/// - 通过BlocListener监听状态变化
/// - 根据状态进行路由跳转
/// 
/// 这个页面类似于Android的LaunchActivity或iOS的LaunchScreen
class SplashScreen extends StatelessWidget {
  /// Root Page of the app.
  const SplashScreen({super.key, required this.isAnon});

  /// 匿名模式标志
  /// true: 跳过登录，自动以访客身份注册
  /// false: 正常登录流程
  final bool isAnon;

  @override
  Widget build(BuildContext context) {
    // 根据是否匿名模式决定启动流程
    if (isAnon) {
      // 匿名模式：先尝试自动注册访客账号
      return FutureBuilder<void>(
        future: _registerIfNeeded(),  // 异步检查并注册访客
        builder: (context, snapshot) {
          // 注册未完成时显示空白
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          // 注册完成后构建主体内容
          return _buildChild(context);
        },
      );
    } else {
      // 正常模式：直接构建主体内容
      return _buildChild(context);
    }
  }

  /// 构建主体Widget
  /// 
  /// 使用BLoC模式管理状态：
  /// 1. 创建SplashBloc并触发获取用户事件
  /// 2. 监听认证状态变化
  /// 3. 根据状态进行路由跳转
  BlocProvider<SplashBloc> _buildChild(BuildContext context) {
    return BlocProvider(
      // 创建SplashBloc并立即触发获取用户事件
      // 这里使用级联操作符..立即添加事件
      create: (context) =>
          getIt<SplashBloc>()..add(const SplashEvent.getUser()),
      child: Scaffold(
        body: BlocListener<SplashBloc, SplashState>(
          // 监听状态变化并处理路由跳转
          listener: (context, state) {
            // 使用map方法处理不同的认证状态
            // 这是一种类似于Switch语句的模式匹配
            state.auth.map(
              authenticated: (r) => _handleAuthenticated(context, r),    // 已认证
              unauthenticated: (r) => _handleUnauthenticated(context, r), // 未认证
              initial: (r) => {},  // 初始状态，不做处理
            );
          },
          // 显示闪屏页内容（Logo和加载动画）
          child: const Body(),
        ),
      ),
    );
  }

  /// 处理已认证用户的流程
  /// 
  /// Handles the authentication flow once a user is authenticated.
  /// 
  /// 步骤：
  /// 1. 获取当前工作空间设置
  /// 2. 成功则跳转到主页
  /// 3. 失败则处理错误
  Future<void> _handleAuthenticated(
    BuildContext context,
    Authenticated authenticated,
  ) async {
    // 向Rust后端发送获取工作空间设置的事件
    final result = await FolderEventGetCurrentWorkspaceSetting().send();
    // 使用fold方法处理Result类型（类似于Rust的Result<T, E>）
    result.fold(
      // 成功：跳转到主页
      (workspaceSetting) {
        // After login, replace Splash screen by corresponding home screen
        // 使用路由器跳转到主页
        // 注意：这里使用replace而不是push，避免用户返回到闪屏页
        getIt<SplashRouter>().goHomeScreen(
          context,
        );
      },
      // 失败：处理打开工作空间错误
      (error) => handleOpenWorkspaceError(context, error),
    );
  }

  /// 处理未认证用户的流程
  /// 
  /// 根据不同条件跳转到不同页面：
  /// - 启用认证或移动端：跳转到登录页
  /// - 未配置环境：跳转到跳过登录页
  void _handleUnauthenticated(BuildContext context, Unauthenticated result) {
    // replace Splash screen as root page
    // 判断是否需要显示登录页
    if (isAuthEnabled || UniversalPlatform.isMobile) {
      // 启用了认证或者是移动端：跳转到登录页
      // 移动端总是需要登录，因为需要云同步
      context.go(SignInScreen.routeName);
    } else {
      // if the env is not configured, we will skip to the 'skip login screen'.
      // 桌面端且未配置认证：跳转到跳过登录页
      // 这允许用户在纯本地模式下使用应用
      context.go(SkipLogInScreen.routeName);
    }
  }

  /// 检查并注册访客账号
  /// 
  /// 匿名模式下的自动注册逻辑：
  /// 1. 尝试获取用户信息
  /// 2. 如果失败（用户不存在），自动注册访客账号
  Future<void> _registerIfNeeded() async {
    // 向后端请求用户信息
    final result = await UserEventGetUserProfile().send();
    if (result.isFailure) {
      // 用户不存在，自动以访客身份注册
      // 这样用户可以立即开始使用应用，无需手动注册
      await getIt<AuthService>().signUpAsGuest();
    }
  }
}

/// 闪屏页主体内容
/// 
/// 根据平台显示不同的内容：
/// - 移动端：简单的Logo
/// - 桌面端：完整的闪屏图片和加载动画
class Body extends StatelessWidget {
  const Body({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: UniversalPlatform.isMobile
          // 移动端：仅显示应用Logo
          // 移动端通常加载较快，不需要复杂的闪屏页
          ? const FlowySvg(FlowySvgs.app_logo_xl, blendMode: null)
          // 桌面端：完整的闪屏体验
          : const _DesktopSplashBody(),
    );
  }
}

/// 桌面端闪屏页主体
/// 
/// 显示一个全屏的闪屏图片和加载动画
/// 这提供了更好的视觉体验，类似专业软件的启动界面
class _DesktopSplashBody extends StatelessWidget {
  const _DesktopSplashBody();

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸以实现全屏显示
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景图片
          Image(
            fit: BoxFit.cover,  // 覆盖整个屏幕
            width: size.width,
            height: size.height,
            image: const AssetImage(
              'assets/images/appflowy_launch_splash.jpg',
            ),
          ),
          // 加载动画
          // adaptive会根据平台选择合适的样式
          // iOS: CupertinoActivityIndicator
          // 其他: CircularProgressIndicator
          const CircularProgressIndicator.adaptive(),
        ],
      ),
    );
  }
}
