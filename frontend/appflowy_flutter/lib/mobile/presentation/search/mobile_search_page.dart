// 导入国际化本地化键值，用于多语言支持
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入应用启动服务，提供依赖注入功能
import 'package:appflowy/startup/startup.dart';
// 导入用户认证服务，管理用户身份验证状态
import 'package:appflowy/user/application/auth/auth_service.dart';
// 导入命令面板业务逻辑组件，处理搜索相关的状态管理
import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
// 导入工作区失败页面，用于错误状态展示
import 'package:appflowy/workspace/presentation/home/errors/workspace_failed_screen.dart';
// 导入后端调度器，用于与后端服务通信
import 'package:appflowy_backend/dispatch/dispatch.dart';
// 导入工作区相关的protobuf数据结构
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
// 导入用户相关的protobuf数据结构
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
// 导入国际化插件，支持多语言本地化
import 'package:easy_localization/easy_localization.dart';
// 导入Flutter的Material Design组件库
import 'package:flutter/material.dart';
// 导入Bloc状态管理库
import 'package:flutter_bloc/flutter_bloc.dart';
// 导入Provider状态管理库，用于依赖注入和状态共享
import 'package:provider/provider.dart';

// 导入AI搜索入口组件
import 'mobile_search_ask_ai_entrance.dart';
// 导入搜索结果展示组件
import 'mobile_search_result.dart';
// 导入搜索输入框组件
import 'mobile_search_textfield.dart';

/// 移动端搜索屏幕组件
/// 
/// 设计思想：
/// 1. 作为搜索功能的入口点，负责初始化搜索所需的数据和状态
/// 2. 使用FutureBuilder模式异步获取用户信息和工作区设置，体现了响应式编程思想
/// 3. 采用了错误边界模式，通过null检查确保数据完整性
/// 4. 将复杂的UI逻辑委托给MobileSearchPage，遵循单一职责原则
/// 5. 使用Provider模式将用户信息传递给子组件，实现了数据的向下传递
class MobileSearchScreen extends StatelessWidget {
  /// 构造函数
  const MobileSearchScreen({
    super.key,
  });

  /// 搜索页面的路由名称，用于Flutter导航系统
  static const routeName = '/search';

  /// 构建搜索屏幕的UI
  /// 
  /// 采用异步数据获取模式：
  /// 1. 并发获取工作区设置和用户信息，提高加载效率
  /// 2. 使用Future.wait确保两个异步操作都完成后再构建UI
  /// 3. 通过FutureBuilder处理异步状态，提供良好的用户体验
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // 并发执行两个异步操作：获取工作区设置和用户信息
      future: Future.wait([
        FolderEventGetCurrentWorkspaceSetting().send(), // 获取当前工作区设置
        getIt<AuthService>().getUser(), // 从依赖注入容器获取认证服务并获取用户信息
      ]),
      builder: (context, snapshots) {
        // 检查异步数据是否已加载完成，如果没有则显示加载指示器
        if (!snapshots.hasData) {
          // 使用自适应加载指示器，在不同平台显示相应样式的loading
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        // 使用fold方法处理Result类型的返回值，这是函数式编程的错误处理模式
        // 从第一个Future的结果中提取工作区最新信息
        final latest = snapshots.data?[0].fold(
          (latest) {
            // 成功情况：将结果转换为WorkspaceLatestPB类型
            return latest as WorkspaceLatestPB?;
          },
          (error) => null, // 失败情况：返回null
        );
        // 从第二个Future的结果中提取用户配置文件信息
        final userProfile = snapshots.data?[1].fold(
          (userProfilePB) {
            // 成功情况：将结果转换为UserProfilePB类型
            return userProfilePB as UserProfilePB?;
          },
          (error) => null, // 失败情况：返回null
        );

        // 错误边界检查：如果关键数据获取失败，显示错误页面
        // 这种情况虽然不太可能发生，但可能在工作区已经打开时出现
        // 体现了防御性编程的思想，确保应用的健壮性
        if (latest == null || userProfile == null) {
          return const WorkspaceFailedScreen();
        }

        // 使用Provider.value将用户配置文件数据提供给子组件树
        // 这样子组件可以通过context.read<UserProfilePB>()或context.watch<UserProfilePB>()访问用户信息
        return Provider.value(
          value: userProfile,
          child: MobileSearchPage(
            userProfile: userProfile, // 显式传递用户配置文件
            workspaceLatestPB: latest, // 显式传递工作区最新信息
          ),
        );
      },
    );
  }
}

/// 移动端搜索页面的主体实现
/// 
/// 设计思想：
/// 1. 使用StatefulWidget以支持焦点管理和用户交互状态
/// 2. 将搜索功能分解为多个子组件：输入框、AI入口、搜索结果
/// 3. 通过CommandPaletteBloc管理搜索状态，体现了在AppFlowy中统一的命令模式
/// 4. 根据用户类型动态展示AI搜索功能（仅在服务器类型工作区中显示）
/// 5. 实现了滚动时自动取消焦点的用户体验优化
class MobileSearchPage extends StatefulWidget {
  /// 构造函数
  /// [userProfile] 用户配置文件信息，用于判断是否显示AI功能
  /// [workspaceLatestPB] 工作区最新信息，提供搜索的上下文
  const MobileSearchPage({
    super.key,
    required this.userProfile,
    required this.workspaceLatestPB,
  });

  /// 用户配置文件，包含用户的基本信息和工作区类型等
  final UserProfilePB userProfile;
  /// 工作区最新信息，包含工作区的配置和元数据
  final WorkspaceLatestPB workspaceLatestPB;

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

/// MobileSearchPage的私有状态类
/// 负责管理搜索页面的局部状态和用户交互
class _MobileSearchPageState extends State<MobileSearchPage> {
  /// 计算属性：判断是否启用AI搜索功能
  /// 只有在服务器类型的工作区中才显示AI搜索入口
  /// 这体现了产品分层的设计：本地工作区不支持AI功能，仅服务器工作区支持
  bool get enableShowAISearch =>
      widget.userProfile.workspaceType == WorkspaceTypePB.ServerW;

  /// 焦点节点，用于管理搜索输入框的焦点状态
  /// 允许程序主动控制输入框的焦点获取和失去
  final focusNode = FocusNode();

  /// 释放资源
  /// 在组件销毁时手动释放FocusNode资源，防止内存泄漏
  /// 这是Flutter中资源管理的最佳实践
  @override
  void dispose() {
    focusNode.dispose(); // 释放焦点节点资源
    super.dispose(); // 调用父类的dispose方法
  }

  /// 构建UI界面
  /// 
  /// UI结构设计：
  /// 1. 使用BlocBuilder监听命令面板的状态变化，实现响应式更新
  /// 2. 采用Column垂直布局：上方是输入框，下方是内容区域
  /// 3. 使用NotificationListener监听滚动事件，实现优雅的用户体验
  @override
  Widget build(BuildContext context) {
    // 使用BlocBuilder监听命令面板状态，实现状态驱动的UI更新
    return BlocBuilder<CommandPaletteBloc, CommandPaletteState>(
      builder: (context, state) {
        // SafeArea确保内容不被系统状态栏等遵挡
        return SafeArea(
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 左对齐布局
              children: [
                // 搜索输入框组件
                MobileSearchTextfield(
                  focusNode: focusNode, // 传递焦点节点以支持焦点管理
                  // 根据是否支持AI功能动态设置提示文本
                  hintText: enableShowAISearch
                      ? LocaleKeys.search_searchOrAskAI.tr() // 支持AI：“搜索或咨询AI”
                      : LocaleKeys.search_label.tr(), // 不支持AI：仅显示“搜索”
                  query: state.query ?? '', // 显示当前的搜索查询内容
                  // 搜索输入变化时的回调函数
                  onChanged: (value) => context.read<CommandPaletteBloc>().add(
                        CommandPaletteEvent.searchChanged(search: value), // 发送搜索变化事件
                      ),
                ),
                // 使用Flexible使内容区域能够自适应剩余空间
                Flexible(
                  child: NotificationListener(
                    // 监听滚动通知，实现滚动时自动取消输入框焦点的优化体验
                    onNotification: (t) {
                      // 检查是否为滚动更新通知
                      if (t is ScrollUpdateNotification) {
                        // 如果输入框当前有焦点，则取消焦点
                        if (focusNode.hasFocus) {
                          focusNode.unfocus(); // 隐藏键盘，取消输入框焦点
                        }
                      }
                      return true; // 继续传递通知
                    },
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16), // 设置左右内边距
                        child: Column(
                          children: [
                            // 条件渲染：AI搜索入口（仅在支持AI的工作区中显示）
                            if (enableShowAISearch) MobileSearchAskAiEntrance(),
                            // 搜索结果展示组件（始终显示）
                            MobileSearchResult(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
