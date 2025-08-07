// === AI和核心服务 ===
// AI服务实现
import 'package:appflowy/ai/service/appflowy_ai_service.dart';
// 键值存储抽象
import 'package:appflowy/core/config/kv.dart';
// 网络监控服务
import 'package:appflowy/core/network_monitor.dart';
// 云环境配置
import 'package:appflowy/env/cloud_env.dart';
// 视图祖先缓存（用于移动端搜索优化）
import 'package:appflowy/mobile/presentation/search/view_ancestor_cache.dart';

// === 文档和插件服务 ===
// 文档应用层服务
import 'package:appflowy/plugins/document/application/prelude.dart';
// 剪贴板服务
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/clipboard_service.dart';
// 回收站服务
import 'package:appflowy/plugins/trash/application/prelude.dart';

// === 缓存和共享服务 ===
// 缓存管理器
import 'package:appflowy/shared/appflowy_cache_manager.dart';
// 自定义图片缓存
import 'package:appflowy/shared/custom_image_cache_manager.dart';
// 国际化服务
import 'package:appflowy/shared/easy_localiation_service.dart';

// === 启动相关 ===
// 启动模块
import 'package:appflowy/startup/startup.dart';
// AppFlowy云任务
import 'package:appflowy/startup/tasks/appflowy_cloud_task.dart';

// === 用户认证服务 ===
// AppFlowy云认证服务
import 'package:appflowy/user/application/auth/af_cloud_auth_service.dart';
// 认证服务抽象
import 'package:appflowy/user/application/auth/auth_service.dart';
// 用户应用层服务
import 'package:appflowy/user/application/prelude.dart';
// 提醒功能
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
// 用户监听器
import 'package:appflowy/user/application/user_listener.dart';
// 用户路由
import 'package:appflowy/user/presentation/router.dart';

// === 工作空间和界面 ===
// 动作导航Bloc
import 'package:appflowy/workspace/application/action_navigation/action_navigation_bloc.dart';
// 编辑面板Bloc
import 'package:appflowy/workspace/application/edit_panel/edit_panel_bloc.dart';
// 收藏夹Bloc
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
// 缓存的最近使用服务
import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
// 外观设置
import 'package:appflowy/workspace/application/settings/appearance/base_appearance.dart';
import 'package:appflowy/workspace/application/settings/appearance/desktop_appearance.dart';
import 'package:appflowy/workspace/application/settings/appearance/mobile_appearance.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
// 重命名视图Bloc
import 'package:appflowy/workspace/application/sidebar/rename_view/rename_view_bloc.dart';
// 订阅成功监听器
import 'package:appflowy/workspace/application/subscription_success_listenable/subscription_success_listenable.dart';
// 标签页Bloc
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
// 工作空间相关服务
import 'package:appflowy/workspace/application/user/prelude.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy/workspace/application/workspace/prelude.dart';
// 菜单共享状态
import 'package:appflowy/workspace/presentation/home/menu/menu_shared_state.dart';

// === 后端和工具库 ===
// 日志系统
import 'package:appflowy_backend/log.dart';
// Protocol Buffers定义
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
// 弹出框组件
import 'package:appflowy_popover/appflowy_popover.dart';
// 文件选择器
import 'package:flowy_infra/file_picker/file_picker_impl.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
// Toast提示
import 'package:fluttertoast/fluttertoast.dart';
// 依赖注入
import 'package:get_it/get_it.dart';
// 平台检测
import 'package:universal_platform/universal_platform.dart';

/// 依赖解析器
/// 
/// 负责注册和配置应用中所有的依赖项
/// 这个类相当于Spring的@Configuration类
/// 
/// 设计思想：
/// 1. **模块化组织**：按功能模块分组注册依赖
/// 2. **条件注册**：根据运行模式和环境注册不同的实现
/// 3. **单一职责**：仅负责依赖配置，不包含业务逻辑
/// 
/// GetIt注册方式说明：
/// - registerFactory: 每次调用创建新实例（类似@Scope("prototype")）
/// - registerSingleton: 立即创建单例（类似@Singleton饥饿模式）
/// - registerLazySingleton: 延迟创建单例（类似@Singleton懒加载）
/// - registerFactoryParam: 带参数的工厂方法
class DependencyResolver {
  /// 主解析方法 - 组织和协调所有依赖注册
  static Future<void> resolve(
    GetIt getIt,
    IntegrationMode mode,
  ) async {
    // 键值存储服务
    // 注释掉的是Rust实现，当前使用Dart实现
    // getIt.registerFactory<KeyValueStorage>(() => RustKeyValue());
    getIt.registerFactory<KeyValueStorage>(() => DartKeyValue());

    // 按模块顺序解析依赖
    // 顺序很重要，确保基础服务先注册
    await _resolveCloudDeps(getIt);      // 云服务相关
    _resolveUserDeps(getIt, mode);       // 用户和认证相关
    _resolveHomeDeps(getIt);             // 主页和工作空间相关
    _resolveFolderDeps(getIt);           // 文件夹和视图相关
    _resolveCommonService(getIt, mode);  // 通用服务
  }
}

/// 解析云服务相关依赖
/// 
/// 包括：
/// - 云环境配置
/// - AI服务
/// - 深度链接处理
Future<void> _resolveCloudDeps(GetIt getIt) async {
  // 从环境变量加载云服务配置
  final env = await AppFlowyCloudSharedEnv.fromEnv();
  Log.info("cloud setting: $env");
  // 注册云环境配置为工厂模式
  getIt.registerFactory<AppFlowyCloudSharedEnv>(() => env);
  
  // 注册AI服务实现
  // AIRepository是抽象接口，AppFlowyAIService是具体实现
  getIt.registerFactory<AIRepository>(() => AppFlowyAIService());

  // 条件注册：仅在启用AppFlowy云时注册深度链接服务
  if (isAppFlowyCloudEnabled) {
    getIt.registerSingleton(
      AppFlowyCloudDeepLink(),
      // dispose回调：在容器重置时清理资源
      dispose: (obj) async {
        await obj.dispose();
      },
    );
  }
}

/// 解析通用服务依赖
/// 
/// 包括基础设施服务：
/// - 文件选择器
/// - 存储服务
/// - 剪贴板服务
/// - 主题外观
/// - 缓存管理
/// - 国际化
void _resolveCommonService(
  GetIt getIt,
  IntegrationMode mode,
) async {
  // 文件选择器服务
  getIt.registerFactory<FilePickerService>(() => FilePicker());

  // 应用数据存储服务
  // 测试模式使用Mock实现，避免影响真实数据
  getIt.registerFactory<ApplicationDataStorage>(
    () => mode.isTest ? MockApplicationDataStorage() : ApplicationDataStorage(),
  );

  // 剪贴板服务
  // 处理复制、粘贴操作
  getIt.registerFactory<ClipboardService>(
    () => ClipboardService(),
  );

  // 主题外观服务
  // 根据平台选择不同的外观实现
  // 这是策略模式的应用
  getIt.registerFactory<BaseAppearance>(
    () => UniversalPlatform.isMobile ? MobileAppearance() : DesktopAppearance(),
  );

  // 缓存管理器
  // 使用链式调用注册多个缓存策略
  getIt.registerFactory<FlowyCacheManager>(
    () => FlowyCacheManager()
      ..registerCache(TemporaryDirectoryCache())  // 临时目录缓存
      ..registerCache(CustomImageCacheManager())  // 图片缓存
      ..registerCache(FeatureFlagCache()),        // 特性开关缓存
  );

  // 国际化服务
  // 单例模式，确保全局只有一个实例
  getIt.registerSingleton<EasyLocalizationService>(EasyLocalizationService());
}

/// 解析用户相关依赖
/// 
/// 包括：
/// - 认证服务（根据云类型选择不同实现）
/// - 登录/注册Bloc
/// - 路由服务
/// - 网络监听和缓存服务
void _resolveUserDeps(GetIt getIt, IntegrationMode mode) {
  // 根据当前云类型注册不同的认证服务实现
  // 这是策略模式的典型应用
  switch (currentCloudType()) {
    case AuthenticatorType.local:
      // 本地模式：使用后端认证服务
      getIt.registerFactory<AuthService>(
        () => BackendAuthService(
          AuthTypePB.Local,
        ),
      );
      break;
    case AuthenticatorType.appflowyCloud:
    case AuthenticatorType.appflowyCloudSelfHost:
    case AuthenticatorType.appflowyCloudDevelop:
      // 云模式：使用AppFlowy云认证服务
      getIt.registerFactory<AuthService>(() => AppFlowyCloudAuthService());
      break;
  }

  // 认证路由器
  getIt.registerFactory<AuthRouter>(() => AuthRouter());

  // 登录Bloc
  // 使用依赖注入获取AuthService
  getIt.registerFactory<SignInBloc>(
    () => SignInBloc(getIt<AuthService>()),
  );
  // 注册Bloc
  getIt.registerFactory<SignUpBloc>(
    () => SignUpBloc(getIt<AuthService>()),
  );

  // 闪屏页路由和Bloc
  getIt.registerFactory<SplashRouter>(() => SplashRouter());
  getIt.registerFactory<SplashBloc>(() => SplashBloc());
  
  // 编辑面板Bloc
  getIt.registerFactory<EditPanelBloc>(() => EditPanelBloc());
  
  // === 懒加载单例服务 ===
  // 这些服务在第一次使用时才创建
  
  // 网络监听器：监控网络连接状态
  getIt.registerLazySingleton<NetworkListener>(() => NetworkListener());
  // 缓存的最近使用服务：管理最近打开的文档
  getIt.registerLazySingleton<CachedRecentService>(() => CachedRecentService());
  // 视图祖先缓存：优化搜索性能
  getIt.registerLazySingleton<ViewAncestorCache>(() => ViewAncestorCache());
  // 订阅成功监听器：用于订阅状态更新
  getIt.registerLazySingleton<SubscriptionSuccessListenable>(
    () => SubscriptionSuccessListenable(),
  );
}

/// 解析主页相关依赖
/// 
/// 包括：
/// - Toast提示
/// - 菜单状态
/// - 用户监听器
/// - 各种业务Bloc
void _resolveHomeDeps(GetIt getIt) {
  // Toast提示组件
  // 全局单例，用于显示用户提示信息
  getIt.registerSingleton(FToast());

  // 菜单共享状态
  // 管理侧边栏菜单的状态（展开/折叠等）
  getIt.registerSingleton(MenuSharedState());

  // 用户监听器
  // 带参数的工厂方法，每个用户有独立的监听器实例
  getIt.registerFactoryParam<UserListener, UserProfilePB, void>(
    (user, _) => UserListener(userProfile: user),
  );

  // 分享Bloc
  // 带参数的工厂方法，每个视图有独立的分享功能
  getIt.registerFactoryParam<ShareBloc, ViewPB, void>(
    (view, _) => ShareBloc(view: view),
  );

  // 动作导航Bloc
  // 处理快捷键和命令导航
  getIt.registerSingleton<ActionNavigationBloc>(ActionNavigationBloc());

  // 标签页Bloc
  // 管理多标签页的状态
  getIt.registerLazySingleton<TabsBloc>(() => TabsBloc());

  // 提醒Bloc
  // 管理任务提醒功能
  getIt.registerSingleton<ReminderBloc>(ReminderBloc());

  // 重命名视图Bloc
  // 处理视图重命名逻辑，包含弹出框控制器
  getIt.registerSingleton<RenameViewBloc>(RenameViewBloc(PopoverController()));
}

/// 解析文件夹和视图相关依赖
/// 
/// 包括：
/// - 工作空间监听器
/// - 视图Bloc
/// - 回收站服务
/// - 收藏功能
void _resolveFolderDeps(GetIt getIt) {
  // === 工作空间 ===
  
  // 工作空间监听器
  // 带两个参数：用户和工作空间ID
  getIt.registerFactoryParam<WorkspaceListener, UserProfilePB, String>(
    (user, workspaceId) =>
        WorkspaceListener(user: user, workspaceId: workspaceId),
  );

  // 视图Bloc
  // 每个视图（文档、表格等）都有独立的Bloc实例
  getIt.registerFactoryParam<ViewBloc, ViewPB, void>(
    (view, _) => ViewBloc(
      view: view,
    ),
  );

  // === 用户设置 ===
  
  // 设置页用户视图Bloc
  getIt.registerFactoryParam<SettingsUserViewBloc, UserProfilePB, void>(
    (user, _) => SettingsUserViewBloc(user),
  );

  // === 回收站 ===
  
  // 回收站服务：处理删除和恢复操作
  getIt.registerLazySingleton<TrashService>(() => TrashService());
  // 回收站监听器：监听回收站事件
  getIt.registerLazySingleton<TrashListener>(() => TrashListener());
  // 回收站Bloc：管理回收站UI状态
  getIt.registerFactory<TrashBloc>(
    () => TrashBloc(),
  );

  // === 收藏 ===
  
  // 收藏夹Bloc：管理收藏功能
  getIt.registerFactory<FavoriteBloc>(() => FavoriteBloc());
}
