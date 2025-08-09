# AppFlowy 移动端完整架构说明

## 一、应用启动流程

### 1.1 入口点层级

```
main.dart (应用入口)
    ↓
runAppFlowy() [startup.dart]
    ↓
FlowyRunner.run() (启动器)
    ↓
AppFlowyApplication [entry_point.dart]
    ↓
SplashScreen (闪屏页)
    ↓
路由分发 (根据认证状态)
    ├── SignInScreen (登录页)
    ├── SkipLogInScreen (跳过登录页)
    └── MobileHomeScreen (主页)
```

### 1.2 启动初始化任务链

```
FlowyRunner 执行任务列表:
1. PlatformErrorCatcherTask - 平台错误捕获
2. MemoryLeakDetectorTask - 内存泄漏检测
3. DebugTask - 调试配置
4. FeatureFlagTask - 特性开关
5. InitLocalizationTask - 国际化
6. InitAppWindowTask - 窗口初始化
7. InitRustSDKTask - Rust后端初始化
8. PluginLoadTask - 插件加载
9. FileStorageTask - 文件存储
10. ApplicationInfoTask - 应用信息
11. AutoUpdateTask - 自动更新
12. HotKeyTask - 快捷键
13. InitAppFlowyCloudTask - 云服务
14. InitAppWidgetTask - Widget初始化
15. InitPlatformServiceTask - 平台服务
16. RecentServiceTask - 最近使用服务
```

## 二、路由架构

### 2.1 路由结构图

```
GoRouter (根路由器)
├── / (根路径) → SplashScreen
├── /sign_in → SignInScreen
├── /skip_log_in → SkipLogInScreen
├── /workspace_error → WorkspaceErrorScreen
├── /workspace_start → WorkspaceStartScreen
└── /home → StatefulShellRoute (带底部导航栏)
    ├── Branch 0: /home → MobileHomeScreen
    ├── Branch 1: /search → MobileSearchScreen
    ├── Branch 2: /favorite → MobileFavoriteScreen
    └── Branch 3: /notifications → MobileNotificationsScreenV2
```

### 2.2 页面导航类型

#### 普通路由 (GoRoute)
- 设置页面: `/settings`, `/trash`, `/cloud_settings`
- 编辑器页面: `/editor`, `/grid`, `/board`, `/calendar`, `/chat`
- 工具页面: `/emoji_picker`, `/color_picker`, `/font_picker`

#### 状态保持路由 (StatefulShellRoute)
- 底部导航栏的4个主页面
- 每个分支维护独立的导航栈
- 切换Tab时保持页面状态

## 三、核心组件架构

### 3.1 组件层级关系

```
MobileHomeScreen (主屏幕容器)
├── 初始化逻辑
│   ├── 获取工作区设置
│   ├── 获取用户信息
│   └── Provider注入
│
├── MobileHomePage (主页面)
│   ├── BLoC Providers
│   │   ├── UserWorkspaceBloc (工作区管理)
│   │   ├── FavoriteBloc (收藏管理)
│   │   └── ReminderBloc (提醒管理)
│   │
│   ├── MobileHomePageHeader (头部)
│   │   ├── 个人模式 → _MobileUser
│   │   ├── 协作模式 → _MobileWorkspace
│   │   └── 设置菜单 → SettingsPopupMenu
│   │
│   └── MobileHomePageTab (Tab容器)
│       ├── MobileSpaceTabBar (Tab栏)
│       │   ├── 可拖拽排序
│       │   ├── 圆角指示器
│       │   └── Tab类型管理
│       │
│       └── TabBarView (内容区)
│           ├── MobileRecentSpace (最近)
│           ├── MobileHomeSpace (空间)
│           ├── MobileFavoriteSpace (收藏)
│           └── MSharedSection (共享)
```

### 3.2 底部导航栏架构

```
MobileBottomNavigationBar
├── StatefulNavigationShell (状态管理)
├── NavigationBarItem[] (导航项)
│   ├── 主页 (index: 0)
│   ├── 搜索 (index: 1)
│   ├── 收藏 (index: 2)
│   └── 通知 (index: 3)
└── 页面切换逻辑
    └── navigationShell.goBranch(index)
```

## 四、状态管理架构

### 4.1 BLoC 架构图

```
应用级 BLoC
├── UserWorkspaceBloc (工作区)
│   ├── 管理当前工作区
│   ├── 工作区切换
│   └── 工作区CRUD操作
│
├── SpaceBloc (空间管理)
│   ├── 空间列表
│   ├── 空间创建/删除
│   └── 空间内页面管理
│
├── SpaceOrderBloc (Tab排序)
│   ├── Tab顺序持久化
│   ├── 默认Tab记录
│   └── 拖拽重排序
│
├── SidebarSectionsBloc (侧边栏)
│   ├── 公共文件夹
│   ├── 私有文件夹
│   └── 部分管理
│
├── FavoriteBloc (收藏)
│   └── 收藏操作管理
│
├── RecentViewsBloc (最近访问)
│   └── 访问记录管理
│
└── ReminderBloc (提醒)
    └── 提醒服务管理
```

### 4.2 依赖注入 (GetIt)

```
GetIt 容器
├── 核心服务
│   ├── FlowySDK (Rust后端通信)
│   ├── AuthService (认证服务)
│   ├── ApplicationDataStorage (数据存储)
│   └── KeyValueStorage (键值存储)
│
├── 路由服务
│   ├── SplashRouter (闪屏路由)
│   ├── AuthRouter (认证路由)
│   └── AFNavigatorObserver (导航观察者)
│
├── BLoC 实例
│   ├── SplashBloc
│   ├── SettingsUserViewBloc
│   └── ReminderBloc (单例)
│
└── 其他服务
    ├── MenuSharedState (菜单状态)
    ├── CachedRecentService (缓存服务)
    └── AppLauncher (启动器)
```

## 五、数据流架构

### 5.1 单向数据流

```
用户操作
    ↓
UI组件 (View)
    ↓
BLoC事件 (Event)
    ↓
业务逻辑处理 (BLoC)
    ↓
Rust后端调用 (通过FFI)
    ↓
状态更新 (State)
    ↓
UI重建 (BlocBuilder)
```

### 5.2 跨组件通信

```
全局通知器 (ValueNotifier)
├── mobileCreateNewPageNotifier (创建文档)
├── mobileCreateNewAIChatNotifier (创建AI聊天)
├── mobileLeaveWorkspaceNotifier (离开工作区)
└── mCurrentWorkspace (当前工作区)
```

## 六、平台适配策略

### 6.1 平台检测与路由

```dart
if (UniversalPlatform.isMobile) {
    // 移动端路由
    context.go(MobileHomeScreen.routeName);
} else {
    // 桌面端路由
    context.go(DesktopHomeScreen.routeName);
}
```

### 6.2 平台特定功能

```
移动端特有
├── 底部导航栏
├── 手势操作
├── Sheet路由
└── 移动端设置页

桌面端特有
├── 侧边栏
├── 窗口管理
├── 快捷键
└── 桌面端设置页
```

## 七、关键设计模式

### 7.1 使用的设计模式

1. **策略模式** - EntryPoint接口和实现
2. **单例模式** - GetIt依赖注入
3. **观察者模式** - BLoC状态管理
4. **工厂模式** - Widget创建
5. **门面模式** - FlowyRunner启动器
6. **任务链模式** - LaunchTask任务链

### 7.2 架构特点

1. **模块化设计** - 功能模块独立，低耦合
2. **响应式编程** - 基于Stream的状态管理
3. **平台自适应** - 自动识别并适配不同平台
4. **状态保持** - Tab切换时保持页面状态
5. **异步初始化** - 非阻塞的启动流程

## 八、文件组织结构

```
lib/
├── main.dart                      # 应用入口
├── startup/                        # 启动模块
│   ├── startup.dart               # 启动器核心
│   ├── entry_point.dart           # 入口点实现
│   ├── launch_configuration.dart  # 启动配置
│   ├── deps_resolver.dart         # 依赖注入
│   └── tasks/                     # 启动任务
│       ├── app_widget.dart        # Widget初始化
│       └── generate_router.dart   # 路由生成
│
├── mobile/                         # 移动端模块
│   ├── presentation/              
│   │   ├── home/                  # 主页相关
│   │   │   ├── mobile_home_page.dart
│   │   │   ├── mobile_home_page_header.dart
│   │   │   ├── mobile_folders.dart
│   │   │   └── tab/               # Tab相关
│   │   │       ├── mobile_space_tab.dart
│   │   │       ├── _tab_bar.dart
│   │   │       └── space_order_bloc.dart
│   │   └── bottom_navigation/     # 底部导航
│   │
│   └── application/               # 业务逻辑
│       └── mobile_router.dart     # 移动端路由
│
├── user/                           # 用户模块
│   ├── presentation/
│   │   ├── screens/
│   │   │   └── splash_screen.dart # 闪屏页
│   │   └── router.dart            # 用户路由
│   └── application/
│       └── auth/                  # 认证相关
│
└── workspace/                      # 工作区模块
    ├── application/               # BLoC层
    │   ├── user/user_workspace_bloc.dart
    │   └── sidebar/space/space_bloc.dart
    └── presentation/              # UI层
```

## 九、性能优化策略

1. **懒加载** - 使用 `AutomaticKeepAliveClientMixin` 保持状态
2. **按需初始化** - GetIt的 `registerLazySingleton`
3. **路由优化** - StatefulShellRoute 维护独立导航栈
4. **异步加载** - FutureBuilder 处理异步数据
5. **状态缓存** - CachedRecentService 缓存最近访问

## 十、扩展指南

### 添加新页面
1. 在 `generate_router.dart` 添加路由
2. 创建对应的 Screen 组件
3. 配置路由参数和导航逻辑

### 添加新的 BLoC
1. 创建 BLoC 类和事件/状态
2. 在依赖注入中注册
3. 在需要的组件中提供 Provider

### 添加新的 Tab
1. 在 `MobileSpaceTabType` 添加枚举
2. 在 `_buildTabs` 实现对应组件
3. 更新本地化文本