# AppFlowy 完整架构说明 - 桌面端与移动端对比

## 一、架构总览对比

### 桌面端架构特点
- **多标签页系统**：支持同时打开多个文档标签
- **侧边栏导航**：固定的左侧导航菜单
- **编辑面板**：右侧属性编辑面板
- **复杂布局**：可调整大小的多面板布局
- **键盘快捷键**：丰富的快捷键支持

### 移动端架构特点
- **底部导航栏**：4个主要Tab（主页、搜索、收藏、通知）
- **顶部Tab栏**：可拖拽排序的内容分类
- **单页面模式**：一次只显示一个页面
- **手势操作**：滑动、长按等触屏操作
- **全屏编辑**：编辑器占满整个屏幕

## 二、启动流程对比

### 共同流程
```
main.dart
    ↓
runAppFlowy()
    ↓
FlowyRunner.run()
    ↓
AppFlowyApplication
    ↓
SplashScreen (闪屏页)
    ↓
认证检查
```

### 路由分发差异

**桌面端路由**
```
SplashScreen
    ↓
根据认证状态
    ├── SignInScreen (登录页)
    ├── SkipLogInScreen (跳过登录)
    └── DesktopHomeScreen (桌面主页)
```

**移动端路由**
```
SplashScreen
    ↓
根据认证状态
    ├── SignInScreen (必须登录)
    └── MobileHomeScreen (移动主页)
        └── StatefulShellRoute (底部导航)
```

## 三、主页面结构对比

### 桌面端 - DesktopHomeScreen

```
DesktopHomeScreen
├── 布局组件
│   ├── HomeSideBar (侧边栏)
│   │   ├── SidebarUser (用户区域)
│   │   ├── SidebarWorkspace (工作区切换)
│   │   ├── SidebarSpace (空间列表)
│   │   ├── SidebarFolder (文件夹树)
│   │   └── SidebarFooter (设置/垃圾桶)
│   │
│   ├── HomeStack (主内容区)
│   │   ├── TabsManager (标签栏)
│   │   │   └── FlowyTab[] (多个标签)
│   │   └── PageStack (页面栈)
│   │       └── IndexedStack (标签内容)
│   │
│   ├── EditPanel (编辑面板)
│   │   └── 属性编辑器
│   │
│   └── 辅助组件
│       ├── SidebarResizer (侧边栏调整器)
│       ├── NotificationPanel (通知面板)
│       └── QuestionBubble (帮助气泡)
```

### 移动端 - MobileHomeScreen

```
MobileHomeScreen
├── MobileHomePage
│   ├── MobileHomePageHeader (顶部头部)
│   │   ├── 用户/工作区信息
│   │   └── 设置菜单
│   │
│   └── MobileHomePageTab (Tab容器)
│       ├── MobileSpaceTabBar (顶部Tab栏)
│       │   └── 可拖拽Tab
│       │
│       └── TabBarView (内容区)
│           ├── MobileRecentSpace
│           ├── MobileHomeSpace
│           ├── MobileFavoriteSpace
│           └── MSharedSection
│
└── MobileBottomNavigationBar (底部导航)
    ├── 主页
    ├── 搜索
    ├── 收藏
    └── 通知
```

## 四、核心组件差异

### 导航方式

| 特性 | 桌面端 | 移动端 |
|------|--------|--------|
| 主导航 | 左侧边栏 (HomeSideBar) | 底部导航栏 (BottomNavigation) |
| 内容切换 | 多标签页 (TabsManager) | 顶部Tab栏 (MobileSpaceTabBar) |
| 导航树 | 可折叠文件夹树 | 平铺列表 |
| 空间切换 | 下拉菜单 | Sheet弹窗 |

### 布局管理

**桌面端布局**
```dart
// 使用Stack和Positioned实现复杂布局
Stack(
  children: [
    homeStack.positioned(
      left: layout.homePageLOffset,
      right: layout.homePageROffset,
    ),
    sidebar.positioned(left: 0, width: layout.sidebarWidth),
    editPanel.positioned(right: 0, width: layout.panelWidth),
  ]
)
```

**移动端布局**
```dart
// 使用Column简单垂直布局
Column(
  children: [
    MobileHomePageHeader(),
    Expanded(
      child: TabBarView(children: [...])
    ),
  ]
)
```

### 状态管理差异

**桌面端特有BLoC**
- `TabsBloc` - 管理多标签页
- `HomeBloc` - 管理主页状态
- `HomeSettingBloc` - 管理布局设置（侧边栏宽度等）
- `CommandPaletteBloc` - 命令面板

**移动端特有BLoC**
- `SpaceOrderBloc` - 管理Tab顺序
- `底部导航状态` - StatefulShellRoute内置

## 五、交互模式对比

### 桌面端交互
1. **鼠标操作**
   - 点击、双击、右键菜单
   - 拖拽调整面板大小
   - 悬停提示

2. **键盘快捷键**
   - Cmd/Ctrl+N 新建
   - Cmd/Ctrl+W 关闭标签
   - Cmd/Ctrl+Tab 切换标签

3. **多窗口**
   - 支持多个标签页同时打开
   - 可以分屏查看

### 移动端交互
1. **触屏手势**
   - 滑动切换Tab
   - 长按拖拽排序
   - 下拉刷新

2. **导航模式**
   - 单页面堆栈导航
   - Sheet弹窗
   - 全屏编辑

3. **适配优化**
   - 大按钮易点击
   - 底部操作区域
   - 滑动返回

## 六、插件系统差异

### 桌面端插件加载
```dart
// 支持在标签页中打开不同插件
TabsBloc.add(TabsEvent.openPlugin(plugin: view.plugin()))
```

### 移动端插件加载
```dart
// 通过路由导航到不同页面
context.pushView(view, tabs: [...])
```

## 七、文件组织结构

```
lib/
├── main.dart                    # 共用入口
├── startup/                     # 共用启动模块
│
├── workspace/                   # 桌面端模块
│   └── presentation/
│       └── home/
│           ├── desktop_home_screen.dart
│           ├── home_stack.dart      # 标签页管理
│           ├── tabs/                # 标签系统
│           └── menu/sidebar/        # 侧边栏
│
└── mobile/                      # 移动端模块
    └── presentation/
        ├── home/
        │   ├── mobile_home_page.dart
        │   ├── mobile_home_page_header.dart
        │   └── tab/                 # Tab系统
        │
        └── bottom_navigation/       # 底部导航
```
## 八、性能优化策略对比

### 桌面端优化
- **多标签懒加载**：只渲染当前标签内容
- **虚拟滚动**：大列表虚拟化
- **面板动画缓存**：布局动画优化
- **键盘事件优化**：防抖处理

### 移动端优化
- **Tab状态保持**：AutomaticKeepAliveClientMixin
- **图片懒加载**：滚动时加载
- **手势优化**：减少重绘
- **内存管理**：及时释放不可见页面

## 九、平台特定功能

### 桌面端独有
- 窗口管理 (WindowManager)
- 文件拖放
- 系统托盘
- 全局快捷键
- 右键菜单
- 命令面板 (Cmd+K)

### 移动端独有
- 底部Sheet
- 手势返回
- 系统分享
- 推送通知
- 生物识别
- AI悬浮按钮

## 十、设计理念差异

### 桌面端设计理念
- **生产力优先**：支持复杂操作和批量处理
- **信息密度高**：同时显示更多信息
- **键鼠优化**：精确操作和快捷键
- **多任务**：支持多窗口和标签页

### 移动端设计理念
- **简洁优先**：减少认知负担
- **触屏友好**：大目标区域
- **单手操作**：重要功能在拇指区
- **上下文相关**：根据场景显示功能

## 十一、代码复用策略

### 共享组件
- 认证流程 (SplashScreen)
- BLoC业务逻辑
- 数据模型
- 网络请求
- Rust后端通信

### 平台特定实现
- UI布局完全独立
- 导航系统各自实现
- 交互逻辑分离
- 样式主题定制

## 十二、开发建议

### 添加新功能时
1. **评估平台差异**：功能是否适合所有平台
2. **共享业务逻辑**：BLoC层尽量复用
3. **独立UI实现**：各平台独立设计UI
4. **测试覆盖**：确保各平台都测试到位

### 维护建议
1. **保持一致性**：核心功能行为一致
2. **平台特色**：充分利用平台特性
3. **性能优化**：针对性优化
4. **用户体验**：符合平台使用习惯
