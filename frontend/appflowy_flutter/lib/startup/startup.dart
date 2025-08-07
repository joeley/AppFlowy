// Dart核心异步编程库，提供Future、Stream等异步编程支持
import 'dart:async';
// Dart IO库，提供文件系统、网络等IO操作
import 'dart:io';

// 云环境配置，管理AppFlowy云服务相关的环境变量和配置
import 'package:appflowy/env/cloud_env.dart';
// 文档编辑器的桌面浮动工具栏组件
import 'package:appflowy/plugins/document/presentation/editor_plugins/desktop_toolbar/desktop_floating_toolbar.dart';
// 链接悬停菜单功能
import 'package:appflowy/plugins/document/presentation/editor_plugins/desktop_toolbar/link/link_hover_menu.dart';
// 视图展开功能注册表
import 'package:appflowy/util/expand_views.dart';
// 应用设置相关的导入集合
import 'package:appflowy/workspace/application/settings/prelude.dart';
// AppFlowy后端SDK，提供与Rust后端的通信接口
import 'package:appflowy_backend/appflowy_backend.dart';
// 日志系统
import 'package:appflowy_backend/log.dart';
// Flutter基础库，提供kReleaseMode等常量
import 'package:flutter/foundation.dart';
// Flutter Material组件库
import 'package:flutter/material.dart';
// GetIt：服务定位器模式的依赖注入容器
// 类似于Java Spring的IoC容器，用于管理应用中的单例和依赖关系
import 'package:get_it/get_it.dart';
// 获取应用包信息（版本号、包名等）
import 'package:package_info_plus/package_info_plus.dart';
// 提供同步锁功能，防止并发问题
import 'package:synchronized/synchronized.dart';

// 依赖解析器，负责注册和配置应用的所有依赖项
import 'deps_resolver.dart';
// 应用入口点定义
import 'entry_point.dart';
// 启动配置，包含版本号、环境变量等启动参数
import 'launch_configuration.dart';
// 插件系统基础设施
import 'plugin/plugin.dart';
// 导航观察器，用于监控路由跳转
import 'tasks/af_navigator_observer.dart';
// 文件存储任务
import 'tasks/file_storage_task.dart';
// 任务系统的通用导入
import 'tasks/prelude.dart';

/// 全局依赖注入容器实例
/// 
/// GetIt是一个服务定位器（Service Locator）模式的实现
/// 作用类似于Java Spring的ApplicationContext
/// 通过它可以在应用的任何地方获取注册的依赖对象
/// 
/// 使用示例：
/// - 注册：getIt.registerSingleton<MyService>(MyService())
/// - 获取：getIt<MyService>()
final getIt = GetIt.instance;

/// 应用入口点抽象类
/// 
/// 定义了创建应用根Widget的接口
/// 所有的应用入口实现都必须继承这个类
/// 这种设计允许不同的启动模式（开发、测试、生产）使用不同的入口实现
abstract class EntryPoint {
  /// 根据启动配置创建应用的根Widget
  /// 这个Widget将成为整个Widget树的根节点
  Widget create(LaunchConfiguration config);
}

/// 应用运行上下文
/// 
/// 保存应用运行时的重要环境信息
/// 类似于Android的Context或Spring的ApplicationContext
class FlowyRunnerContext {
  FlowyRunnerContext({required this.applicationDataDirectory});

  /// 应用数据目录
  /// 存储用户数据、配置文件、数据库等持久化数据
  /// 不同平台的路径不同：
  /// - Windows: C:\Users\<user>\AppData\Roaming\AppFlowy
  /// - macOS: ~/Library/Application Support/AppFlowy
  /// - Linux: ~/.config/AppFlowy
  final Directory applicationDataDirectory;
}

/// AppFlowy应用的主启动函数
/// 
/// 这是从main.dart调用的核心启动函数
/// 负责初始化整个应用的运行环境
/// 
/// @param isAnon 是否以匿名模式运行
///               true: 用户无需登录，数据仅保存在本地
///               false: 正常模式，支持云同步功能
/// 
/// 设计思想：
/// - 区分发布模式和开发/测试模式的不同启动流程
/// - 支持热重启（在开发时保持状态）
/// - 提供测试钩子以支持集成测试
Future<void> runAppFlowy({bool isAnon = false}) async {
  Log.info('restart AppFlowy: isAnon: $isAnon');

  if (kReleaseMode) {
    // 生产环境：使用简化的启动流程，提高性能
    await FlowyRunner.run(
      AppFlowyApplication(),  // 实际的应用入口实现
      integrationMode(),       // 自动检测运行模式
      isAnon: isAnon,
    );
  } else {
    // 开发/测试环境：保留更多的调试功能和测试钩子
    // When running the app in integration test mode, we need to
    // specify the mode to run the app again.
    await FlowyRunner.run(
      AppFlowyApplication(),
      FlowyRunner.currentMode,  // 使用当前模式，支持热重启时保持模式
      // 测试钩子：允许测试代码在依赖注入完成后执行自定义逻辑
      didInitGetItCallback: IntegrationTestHelper.didInitGetItCallback,
      // Rust环境变量构建器：允许测试设置特定的后端配置
      rustEnvsBuilder: IntegrationTestHelper.rustEnvsBuilder,
      isAnon: isAnon,
    );
  }
}

/// 应用运行器
/// 
/// 核心职责：
/// 1. 管理应用的启动流程
/// 2. 协调各个初始化任务的执行
/// 3. 配置依赖注入容器
/// 4. 处理不同运行模式的差异
/// 
/// 这个类相当于Spring Boot的SpringApplication
/// 负责编排整个应用的启动过程
class FlowyRunner {
  /// 当前运行模式
  /// 
  /// This variable specifies the initial mode of the app when it is launched for the first time.
  /// The same mode will be automatically applied in subsequent executions when the runAppFlowy()
  /// method is called.
  /// 
  /// 在热重载时保持模式不变，避免状态丢失
  static var currentMode = integrationMode();

  /// 核心启动方法 - 执行完整的应用初始化流程
  /// 
  /// 这个方法的设计思想：
  /// 1. **任务链模式**：通过一系列的LaunchTask顺序执行初始化
  /// 2. **依赖注入**：使用GetIt管理全局单例和依赖关系
  /// 3. **模式分离**：根据不同的运行模式执行不同的初始化逻辑
  /// 
  /// @param f 应用入口点，负责创建根Widget
  /// @param mode 运行模式（开发/发布/测试）
  /// @return 返回包含应用数据目录的上下文
  static Future<FlowyRunnerContext> run(
    EntryPoint f,
    IntegrationMode mode, {
    // This callback is triggered after the initialization of 'getIt',
    // which is used for dependency injection throughout the app.
    // If your functionality depends on 'getIt', ensure to register
    // your callback here to execute any necessary actions post-initialization.
    // 
    // 依赖注入完成后的回调
    // 主要用于测试环境，允许在GetIt初始化后注入额外的测试依赖
    Future Function()? didInitGetItCallback,
    // Passing the envs to the backend
    // 
    // Rust后端环境变量构建器
    // 用于向Rust后端传递环境配置，如API地址、调试开关等
    Map<String, String> Function()? rustEnvsBuilder,
    // Indicate whether the app is running in anonymous mode.
    // Note: when the app is running in anonymous mode, the user no need to
    // sign in, and the app will only save the data in the local storage.
    // 
    // 匿名模式标志
    // true: 纯本地模式，无需登录，数据不同步到云端
    // false: 支持云同步的完整模式
    bool isAnon = false,
  }) async {
    // 保存当前运行模式，便于热重载时保持一致
    currentMode = mode;

    // Only set the mode when it's not release mode
    // 非发布模式下保存测试钩子，便于集成测试使用
    if (!kReleaseMode) {
      IntegrationTestHelper.didInitGetItCallback = didInitGetItCallback;
      IntegrationTestHelper.rustEnvsBuilder = rustEnvsBuilder;
    }

    // Disable the log in test mode
    // 测试模式下禁用日志，避免干扰测试输出
    Log.shared.disableLog = mode.isTest;

    // Clear and dispose tasks from previous AppLaunch
    // 清理上次启动的任务和资源
    // 这在热重载时尤其重要，确保不会有资源泄漏
    if (getIt.isRegistered(instance: AppLauncher)) {
      await getIt<AppLauncher>().dispose();
    }

    // Clear all the states in case of rebuilding.
    // 重置GetIt容器，清空所有注册的依赖
    // 确保每次启动都是全新的状态，避免状态污染
    await getIt.reset();

    // 构建启动配置
    final config = LaunchConfiguration(
      isAnon: isAnon,
      // Unit test can't use the package_info_plus plugin
      // 单元测试无法使用平台插件，使用固定版本号
      version: mode.isUnitTest
          ? '1.0.0'
          : await PackageInfo.fromPlatform().then((value) => value.version),
      // 构建Rust后端环境变量
      rustEnvs: rustEnvsBuilder?.call() ?? {},
    );

    // Specify the env
    // 初始化依赖注入容器
    // 这里会注册所有的全局单例服务
    await initGetIt(getIt, mode, f, config);
    // 执行依赖注入完成后的回调（主要用于测试）
    await didInitGetItCallback?.call();

    // 获取应用数据存储目录
    // 这个目录用于存储用户数据、配置文件、数据库等
    final applicationDataDirectory =
        await getIt<ApplicationDataStorage>().getPath().then(
              (value) => Directory(value),
            );

    // 添加启动任务链
    // 
    // 这里的任务顺序非常重要！每个任务可能依赖前面任务的结果
    // 整个启动流程采用任务链模式，类似于Spring Boot的ApplicationRunner
    final launcher = getIt<AppLauncher>();
    launcher.addTasks(
      [
        // === 错误处理和调试任务 ===
        // this task should be first task, for handling platform errors.
        // don't catch errors in test mode
        // 平台错误捕获器：必须是第一个任务，用于捕获全局未处理异常
        if (!mode.isUnitTest && !mode.isIntegrationTest)
          const PlatformErrorCatcherTask(),
        // this task should be second task, for handling memory leak.
        // there's a flag named _enable in memory_leak_detector.dart. If it's false, the task will be ignored.
        // 内存泄漏检测器：开发模式下的调试工具
        MemoryLeakDetectorTask(),
        // 调试任务：设置调试相关的配置
        DebugTask(),
        // 特性开关：管理各种功能的启用/禁用
        const FeatureFlagTask(),

        // === 基础服务初始化 ===
        // localization
        // 国际化初始化：加载语言包
        const InitLocalizationTask(),
        // init the app window
        // 窗口初始化：设置窗口大小、位置等（桌面平台）
        InitAppWindowTask(),
        // Init Rust SDK
        // Rust SDK初始化：启动Rust后端服务
        // 这是AppFlowy的核心，负责数据处理和业务逻辑
        InitRustSDKTask(customApplicationPath: applicationDataDirectory),
        // Load Plugins, like document, grid ...
        // 插件加载：加载文档、表格等核心功能插件
        const PluginLoadTask(),
        // 文件存储任务：初始化文件存储服务
        const FileStorageTask(),

        // === UI和应用服务初始化 ===
        // init the app widget
        // ignore in test mode
        // 单元测试不需要UI相关的初始化
        if (!mode.isUnitTest) ...[
          // The DeviceOrApplicationInfoTask should be placed before the AppWidgetTask to fetch the app information.
          // It is unable to get the device information from the test environment.
          // 应用信息任务：收集设备和应用信息
          const ApplicationInfoTask(),
          // The auto update task should be placed after the ApplicationInfoTask to fetch the latest version.
          // 自动更新任务：检查新版本（集成测试不需要）
          if (!mode.isIntegrationTest) AutoUpdateTask(),
          // 快捷键任务：注册全局快捷键
          const HotKeyTask(),
          // AppFlowy云服务初始化（如果启用）
          if (isAppFlowyCloudEnabled) InitAppFlowyCloudTask(),
          // 初始化应用Widget：创建并运行根Widget
          const InitAppWidgetTask(),
          // 平台服务初始化：设置平台特定的服务
          const InitPlatformServiceTask(),
          // 最近使用服务：管理最近打开的文档
          const RecentServiceTask(),
        ],
      ],
    );
    // 执行所有启动任务
    // 任务会按照添加的顺序依次执行
    // 如果任何任务失败，整个启动流程将中断
    await launcher.launch(); // execute the tasks

    // 返回应用运行上下文
    // 包含应用数据目录等重要信息
    return FlowyRunnerContext(
      applicationDataDirectory: applicationDataDirectory,
    );
  }
}

/// 初始化依赖注入容器
/// 
/// 这个函数负责注册所有全局单例和服务
/// GetIt使用不同的注册方式：
/// - registerFactory: 每次请求时创建新实例
/// - registerSingleton: 立即创建单例
/// - registerLazySingleton: 延迟创建单例（第一次使用时创建）
/// 
/// 这个设计类似于Spring的@Component、@Service注解
Future<void> initGetIt(
  GetIt getIt,
  IntegrationMode mode,
  EntryPoint f,
  LaunchConfiguration config,
) async {
  // 注册应用入口点为工厂模式
  // 每次获取时都会返回同一个实例
  getIt.registerFactory<EntryPoint>(() => f);
  
  // 注册Flowy SDK为懒加载单例
  // SDK负责与Rust后端通信
  getIt.registerLazySingleton<FlowySDK>(
    () {
      return FlowySDK();
    },
    // dispose回调：在容器重置时清理资源
    dispose: (sdk) async {
      await sdk.dispose();
    },
  );
  
  // 注册应用启动器
  // AppLauncher管理所有启动任务
  getIt.registerLazySingleton<AppLauncher>(
    () => AppLauncher(
      context: LaunchContext(
        getIt,
        mode,
        config,
      ),
    ),
    dispose: (launcher) async {
      await launcher.dispose();
    },
  );
  
  // === 注册全局单例服务 ===
  
  // 插件沙箱：管理和隔离插件运行环境
  getIt.registerSingleton<PluginSandbox>(PluginSandbox());
  // 视图展开注册表：管理可展开视图的注册
  getIt.registerSingleton<ViewExpanderRegistry>(ViewExpanderRegistry());
  // 链接悬停触发器：处理链接悬停事件
  getIt.registerSingleton<LinkHoverTriggers>(LinkHoverTriggers());
  // 导航观察者：监控路由导航事件
  getIt.registerSingleton<AFNavigatorObserver>(AFNavigatorObserver());
  // 浮动工具栏控制器：管理文档编辑器的浮动工具栏
  getIt.registerSingleton<FloatingToolbarController>(
    FloatingToolbarController(),
  );

  // 解析并注册其他依赖
  // DependencyResolver会根据不同的运行模式注册不同的服务
  await DependencyResolver.resolve(getIt, mode);
}

/// 启动上下文
/// 
/// 保存启动过程中需要的所有信息
/// 传递给每个启动任务，让任务可以访问全局配置和依赖
class LaunchContext {
  LaunchContext(this.getIt, this.env, this.config);

  /// 依赖注入容器
  GetIt getIt;
  /// 运行模式
  IntegrationMode env;
  /// 启动配置
  LaunchConfiguration config;
}

/// 启动任务类型
/// 
/// 用于分类不同的启动任务
enum LaunchTaskType {
  /// 数据处理任务：初始化数据库、加载配置等
  dataProcessing,
  /// 应用启动任务：UI初始化、服务启动等
  appLauncher,
}

/// 启动任务基类
/// 
/// The interface of an app launch task, which will trigger
/// some nonresident indispensable task in app launching task.
/// 
/// 这是一个模板方法模式的实现
/// 所有启动任务都必须继承这个类并实现相应的方法
/// 
/// 生命周期：
/// 1. initialize: 任务初始化，执行主要逻辑
/// 2. dispose: 任务清理，释放资源
class LaunchTask {
  const LaunchTask();

  /// 任务类型，默认为数据处理类型
  LaunchTaskType get type => LaunchTaskType.dataProcessing;

  /// 初始化任务
  /// @mustCallSuper 注解表示子类重写时必须调用super
  /// 这确保日志记录等基础功能不会被跳过
  @mustCallSuper
  Future<void> initialize(LaunchContext context) async {
    Log.info('LaunchTask: $runtimeType initialize');
  }

  /// 清理任务
  /// 在应用关闭或热重载时调用
  @mustCallSuper
  Future<void> dispose() async {
    Log.info('LaunchTask: $runtimeType dispose');
  }
}

/// 应用启动器
/// 
/// 管理和执行所有启动任务
/// 这个类的设计模式：
/// 1. **任务链模式**：按顺序执行一系列任务
/// 2. **线程安全**：使用Lock保证并发安全
/// 3. **生命周期管理**：统一管理任务的初始化和清理
class AppLauncher {
  AppLauncher({
    required this.context,
  });

  /// 启动上下文，包含配置和依赖信息
  final LaunchContext context;
  /// 任务列表，按添加顺序执行
  final List<LaunchTask> tasks = [];
  /// 同步锁，保证线程安全
  final lock = Lock();

  /// 添加单个任务
  void addTask(LaunchTask task) {
    lock.synchronized(() {
      Log.info('AppLauncher: adding task: $task');
      tasks.add(task);
    });
  }

  /// 批量添加任务
  void addTasks(Iterable<LaunchTask> tasks) {
    lock.synchronized(() {
      Log.info('AppLauncher: adding tasks: ${tasks.map((e) => e.runtimeType)}');
      this.tasks.addAll(tasks);
    });
  }

  /// 启动所有任务
  /// 
  /// 按顺序执行所有注册的任务
  /// 如果任何任务失败，整个启动流程将中断
  /// 记录每个任务和总体的执行时间，便于性能分析
  Future<void> launch() async {
    await lock.synchronized(() async {
      // 启动计时器，用于性能监控
      final startTime = Stopwatch()..start();
      Log.info('AppLauncher: start initializing tasks');

      // 顺序执行每个任务
      for (final task in tasks) {
        final startTaskTime = Stopwatch()..start();
        await task.initialize(context);
        final endTaskTime = startTaskTime.elapsed.inMilliseconds;
        // 记录每个任务的执行时间，便于找出性能瓶颈
        Log.info(
          'AppLauncher: task ${task.runtimeType} initialized in $endTaskTime ms',
        );
      }

      // 记录总执行时间
      final endTime = startTime.elapsed.inMilliseconds;
      Log.info('AppLauncher: tasks initialized in $endTime ms');
    });
  }

  /// 清理所有任务
  /// 
  /// 在应用关闭或热重载时调用
  /// 确保所有资源被正确释放，避免内存泄漏
  Future<void> dispose() async {
    await lock.synchronized(() async {
      Log.info('AppLauncher: start clearing tasks');

      // 逆序清理任务（和初始化顺序相反）
      for (final task in tasks) {
        await task.dispose();
      }

      // 清空任务列表
      tasks.clear();

      Log.info('AppLauncher: tasks cleared');
    });
  }
}

/// 应用运行模式枚举
/// 
/// 定义了应用的不同运行环境
/// 每种模式会影响：
/// - 启动任务的选择
/// - 日志级别
/// - 错误处理方式
/// - 性能监控
/// 
/// 这种设计类似于Spring Boot的profiles
enum IntegrationMode {
  /// 开发模式：启用所有调试功能
  develop,
  /// 发布模式：优化性能，禁用调试
  release,
  /// 单元测试模式：最小化初始化
  unitTest,
  /// 集成测试模式：完整初始化但禁用部分功能
  integrationTest;

  // test mode
  /// 是否为测试模式（单元测试或集成测试）
  bool get isTest => isUnitTest || isIntegrationTest;

  /// 是否为单元测试模式
  bool get isUnitTest => this == IntegrationMode.unitTest;

  /// 是否为集成测试模式
  bool get isIntegrationTest => this == IntegrationMode.integrationTest;

  // release mode
  /// 是否为发布模式
  bool get isRelease => this == IntegrationMode.release;

  // develop mode
  /// 是否为开发模式
  bool get isDevelop => this == IntegrationMode.develop;
}

/// 自动检测当前运行模式
/// 
/// 检测顺序：
/// 1. 检查FLUTTER_TEST环境变量，判断是否为测试模式
/// 2. 检查kReleaseMode常量，判断是否为发布版本
/// 3. 默认返回开发模式
/// 
/// 这个函数相当于Spring Boot的自动环境检测
IntegrationMode integrationMode() {
  // Flutter测试框架会设置这个环境变量
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return IntegrationMode.unitTest;
  }

  // kReleaseMode是Flutter编译时常量
  // 在flutter build时为true，flutter run时为false
  if (kReleaseMode) {
    return IntegrationMode.release;
  }

  // 默认为开发模式
  return IntegrationMode.develop;
}

/// 集成测试辅助类
/// 
/// Only used for integration test
/// 
/// 提供集成测试所需的钩子和配置
/// 这些静态变量允许测试代码在应用启动过程中注入自定义逻辑
/// 
/// 设计模式：测试钩子（Test Hook）
class IntegrationTestHelper {
  /// GetIt初始化后的回调
  /// 允许测试代码在依赖注入完成后注册额外的mock服务
  static Future Function()? didInitGetItCallback;
  /// Rust环境变量构建器
  /// 允许测试设置特定的后端配置，如测试数据库路径
  static Map<String, String> Function()? rustEnvsBuilder;
}
