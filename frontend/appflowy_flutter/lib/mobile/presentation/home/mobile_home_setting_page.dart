import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/env/env.dart';
import 'package:appflowy/features/workspace/data/repositories/rust_workspace_repository_impl.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/mobile/presentation/setting/ai/ai_settings_group.dart';
import 'package:appflowy/mobile/presentation/setting/cloud/cloud_setting_group.dart';
import 'package:appflowy/mobile/presentation/setting/user_session_setting_group.dart';
import 'package:appflowy/mobile/presentation/setting/workspace/workspace_setting_group.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_state_container.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/workspace/application/user/user_workspace_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端主页设置页面
/// 
/// 功能说明：
/// 1. 显示各种设置选项组
/// 2. 加载和管理用户信息
/// 3. 根据配置动态显示设置项
/// 
/// 设置项包括：
/// - 个人信息
/// - 工作区设置
/// - 外观和语言
/// - 云服务和AI设置
/// - 支持和关于
/// - 用户会话管理
class MobileHomeSettingPage extends StatefulWidget {
  const MobileHomeSettingPage({
    super.key,
  });

  /// 路由名称常量
  static const routeName = '/settings';

  @override
  State<MobileHomeSettingPage> createState() => _MobileHomeSettingPageState();
}

class _MobileHomeSettingPageState extends State<MobileHomeSettingPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // 异步获取当前用户信息，使用依赖注入获取AuthService
      future: getIt<AuthService>().getUser(),
      builder: (context, snapshot) {
        String? errorMsg;
        
        // 数据加载中显示自适应加载指示器（iOS和Android样式不同）
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // 使用Either模式fold方法处理成功或失败的结果
        final userProfile = snapshot.data?.fold(
          // 成功情况：直接返回用户信息
          (userProfile) {
            return userProfile;
          },
          // 失败情况：保存错误信息并返图null
          (error) {
            errorMsg = error.msg;
            return null;
          },
        );

        return Scaffold(
          appBar: FlowyAppBar(
            titleText: LocaleKeys.settings_title.tr(),
          ),
          body: userProfile == null
              ? _buildErrorWidget(errorMsg)      // 显示错误状态页面
              : _buildSettingsWidget(userProfile), // 显示设置列表页面
        );
      },
    );
  }

  /// 构建错误显示组件
  /// 
  /// 当无法获取用户信息时显示错误状态
  Widget _buildErrorWidget(String? errorMsg) {
    return FlowyMobileStateContainer.error(
      emoji: '🛸',
      title: LocaleKeys.settings_mobile_userprofileError.tr(),
      description: LocaleKeys.settings_mobile_userprofileErrorDescription.tr(),
      errorMsg: errorMsg,
    );
  }

  /// 构建设置组件
  /// 
  /// 功能说明：
  /// 1. 初始化用户工作区BLoC
  /// 2. 根据状态动态显示设置项
  /// 3. 根据配置显示/隐藏特定设置组
  Widget _buildSettingsWidget(UserProfilePB userProfile) {
    return BlocProvider(
      // 创建用户工作区BLoC管理工作区状态
      create: (context) => UserWorkspaceBloc(
        userProfile: userProfile,
        // 使用Rust实现的工作区仓库
        repository: RustWorkspaceRepositoryImpl(
          userId: userProfile.id,
        ),
      )..add(UserWorkspaceEvent.initialize()),  // 立即初始化
      
      child: BlocBuilder<UserWorkspaceBloc, UserWorkspaceState>(
        builder: (context, state) {
          // 获取当前工作区ID，用于AI设置组件的key
          final currentWorkspaceId = state.currentWorkspace?.workspaceId ?? '';
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 个人信息设置
                  PersonalInfoSettingGroup(
                    userProfile: userProfile,
                  ),
                  
                  // 工作区设置（仅服务器认证用户可见，本地用户不显示）
                  if (state.userProfile.userAuthType == AuthTypePB.Server)
                    const WorkspaceSettingGroup(),
                  
                  // 外观设置
                  const AppearanceSettingGroup(),
                  
                  // 语言设置
                  const LanguageSettingGroup(),
                  
                  // 云服务设置（根据环境变量决定是否显示自定义云服务）
                  if (Env.enableCustomCloud) const CloudSettingGroup(),
                  
                  // AI设置（需要云服务认证启用）
                  if (isAuthEnabled)
                    AiSettingsGroup(
                      key: ValueKey(currentWorkspaceId),  // 使用工作区ID作为key，确保切换工作区时重建组件
                      userProfile: userProfile,
                      workspaceId: currentWorkspaceId,
                    ),
                  
                  // 支持设置
                  const SupportSettingGroup(),
                  
                  // 关于设置
                  const AboutSettingGroup(),
                  
                  // 用户会话设置
                  UserSessionSettingGroup(
                    userProfile: userProfile,
                    showThirdPartyLogin: false,  // 移动端不显示第三方登录
                  ),
                  
                  const VSpace(20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
