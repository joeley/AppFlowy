import 'package:appflowy/mobile/presentation/home/mobile_home_page.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/presentation/screens/screens.dart';
import 'package:appflowy/workspace/presentation/home/desktop_home_screen.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart'
    show UserProfilePB;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_platform/universal_platform.dart';

/*
 * 认证路由器
 * 
 * 管理用户认证相关的页面导航，包括：
 * 1. 密码找回流程
 * 2. 工作区启动页面
 * 3. 主页面跳转（根据平台自动选择）
 * 4. 工作区错误处理
 * 
 * 设计模式：
 * - 通过依赖注入（getIt）获取SplashRouter实例
 * - 使用go_router进行页面导航
 * - 平台适配：自动区分移动端和桌面端
 */
class AuthRouter {
  /* 跳转到忘记密码页面（预留功能） */
  void pushForgetPasswordScreen(BuildContext context) {}

  /*
   * 跳转到工作区启动页面
   * 
   * @param context 构建上下文
   * @param userProfile 用户配置信息
   */
  void pushWorkspaceStartScreen(
    BuildContext context,
    UserProfilePB userProfile,
  ) {
    getIt<SplashRouter>().pushWorkspaceStartScreen(context, userProfile);
  }

  /*
   * 导航到主页面（基于当前工作区和平台）
   * 
   * 根据用户设置和当前平台，自动选择合适的主页面：
   * - 移动平台：MobileHomeScreen
   * - 桌面平台：DesktopHomeScreen
   * 
   * 执行流程：
   * 1. 获取当前工作区设置
   * 2. 成功则跳转到对应平台的主页面
   * 3. 失败则跳转到工作区启动页面
   * 
   * @param context 构建上下文，用于页面导航
   * @param userProfile 当前用户的配置信息
   */
  Future<void> goHomeScreen(
    BuildContext context,
    UserProfilePB userProfile,
  ) async {
    final result = await FolderEventGetCurrentWorkspaceSetting().send();
    result.fold(
      (workspaceSetting) {
        /* 
         * 替换根页面（SignInScreen或SkipLogInScreen）
         * 用户点击返回按钮时会退出应用，而不是返回登录页面
         */
        if (UniversalPlatform.isMobile) {
          context.go(
            MobileHomeScreen.routeName,
          );
        } else {
          context.go(
            DesktopHomeScreen.routeName,
          );
        }
      },
      (error) => pushWorkspaceStartScreen(context, userProfile),
    );
  }

  /*
   * 跳转到工作区错误页面
   * 
   * 当工作区加载失败时显示错误信息
   * 
   * @param context 构建上下文
   * @param userFolder 用户文件夹信息
   * @param error 错误详情
   */
  Future<void> pushWorkspaceErrorScreen(
    BuildContext context,
    UserFolderPB userFolder,
    FlowyError error,
  ) async {
    await context.push(
      WorkspaceErrorScreen.routeName,
      extra: {
        WorkspaceErrorScreen.argUserFolder: userFolder,
        WorkspaceErrorScreen.argError: error,
      },
    );
  }
}

/*
 * 闪屏路由器
 * 
 * 管理应用启动后的初始导航流程：
 * 1. 工作区选择页面
 * 2. 主页面跳转（push和go两种模式）
 * 3. 平台适配的页面路由
 * 
 * 设计特点：
 * - push模式：添加新页面到导航栈
 * - go模式：替换当前页面（无法返回）
 */
class SplashRouter {
  /*
   * 跳转到工作区启动页面
   * 
   * 原计划用于注册页面，让用户选择工作区后再导航到主页面
   * 目前未使用
   */
  Future<void> pushWorkspaceStartScreen(
    BuildContext context,
    UserProfilePB userProfile,
  ) async {
    await context.push(
      WorkspaceStartScreen.routeName,
      extra: {
        WorkspaceStartScreen.argUserProfile: userProfile,
      },
    );

    final result = await FolderEventGetCurrentWorkspaceSetting().send();
    result.fold(
      (workspaceSettingPB) => pushHomeScreen(context),
      (r) => null,
    );
  }

  /*
   * 推入主页面（添加到导航栈）
   * 
   * 根据平台选择对应的主页面
   * 使用push方式，保留返回能力
   */
  void pushHomeScreen(
    BuildContext context,
  ) {
    if (UniversalPlatform.isMobile) {
      context.push(
        MobileHomeScreen.routeName,
      );
    } else {
      context.push(
        DesktopHomeScreen.routeName,
      );
    }
  }

  /*
   * 跳转到主页面（替换当前页面）
   * 
   * 根据平台选择对应的主页面
   * 使用go方式，替换整个导航栈
   */
  void goHomeScreen(
    BuildContext context,
  ) {
    if (UniversalPlatform.isMobile) {
      context.go(
        MobileHomeScreen.routeName,
      );
    } else {
      context.go(
        DesktopHomeScreen.routeName,
      );
    }
  }
}
