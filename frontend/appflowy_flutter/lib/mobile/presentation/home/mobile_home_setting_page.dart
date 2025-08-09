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
      // 异步获取当前用户信息
      future: getIt<AuthService>().getUser(),
      builder: (context, snapshot) {
        String? errorMsg;
        
        // 数据加载中显示加载指示器
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // 解析用户信息或错误信息
        final userProfile = snapshot.data?.fold(
          (userProfile) {
            return userProfile;
          },
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
              ? _buildErrorWidget(errorMsg)  // 显示错误状态
              : _buildSettingsWidget(userProfile),  // 显示设置列表
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
      // 创建用户工作区BLoC
      create: (context) => UserWorkspaceBloc(
        userProfile: userProfile,
        repository: RustWorkspaceRepositoryImpl(
          userId: userProfile.id,
        ),
      )..add(UserWorkspaceEvent.initialize()),
      
      child: BlocBuilder<UserWorkspaceBloc, UserWorkspaceState>(
        builder: (context, state) {
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
                  
                  // 工作区设置（仅服务器认证用户可见）
                  if (state.userProfile.userAuthType == AuthTypePB.Server)
                    const WorkspaceSettingGroup(),
                  
                  // 外观设置
                  const AppearanceSettingGroup(),
                  
                  // 语言设置
                  const LanguageSettingGroup(),
                  
                  // 云服务设置（根据环境变量决定是否显示）
                  if (Env.enableCustomCloud) const CloudSettingGroup(),
                  
                  // AI设置（需要认证启用）
                  if (isAuthEnabled)
                    AiSettingsGroup(
                      key: ValueKey(currentWorkspaceId),  // 使用工作区ID作为key，确保切换时重建
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
