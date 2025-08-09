import 'dart:async';
import 'dart:ui';

import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/app_window_size_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:scaled_app/scaled_app.dart';
import 'package:window_manager/window_manager.dart';
import 'package:universal_platform/universal_platform.dart';

/// 应用窗口初始化任务
/// 
/// 功能说明：
/// 1. 初始化桌面端应用窗口
/// 2. 恢复上次的窗口状态（大小、位置、最大化）
/// 3. 监听窗口事件并保存状态
/// 4. 设置界面缩放因子
/// 
/// 技术实现：
/// - 继承自LaunchTask，作为启动任务的一部分
/// - 混入WindowListener，监听窗口事件
/// - 使用window_manager管理窗口
/// - Windows平台使用bitsdojo_window
/// 
/// 支持平台：
/// - Windows（使用bitsdojo_window，隐藏原生标题栏）
/// - macOS/Linux（使用window_manager）
/// - 移动端（仅设置缩放因子）
class InitAppWindowTask extends LaunchTask with WindowListener {
  InitAppWindowTask({this.title = 'AppFlowy'});

  /// 窗口标题
  final String title;
  /// 窗口大小管理器实例
  final windowSizeManager = WindowSizeManager();

  /// 初始化窗口任务
  /// 
  /// 执行流程：
  /// 1. 检查运行环境（跳过测试和Web环境）
  /// 2. 移动端：仅设置缩放因子
  /// 3. 桌面端：初始化窗口管理器
  /// 4. 恢复窗口状态（大小、位置、最大化）
  /// 5. 设置平台特定的窗口选项
  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 测试环境和Web平台不需要初始化窗口
    // 避免在单元测试中出错
    if (context.env.isTest || UniversalPlatform.isWeb) {
      return;
    }

    // 移动端处理：只需要设置缩放因子
    if (UniversalPlatform.isMobile) {
      final scale = await windowSizeManager.getScaleFactor();
      // 设置全局缩放因子，影响所有Widget的大小
      ScaledWidgetsFlutterBinding.instance.scaleFactor = (_) => scale;
      return;
    }

    // ========== 桌面端窗口初始化 ==========
    
    // 确保窗口管理器已初始化
    await windowManager.ensureInitialized();
    // 添加自己作为窗口事件监听器
    windowManager.addListener(this);

    // 从存储中恢复窗口大小
    final windowSize = await windowSizeManager.getSize();
    
    // 配置窗口选项
    final windowOptions = WindowOptions(
      size: windowSize,                    // 初始窗口大小
      minimumSize: const Size(              // 最小窗口尺寸
        WindowSizeManager.minWindowWidth,
        WindowSizeManager.minWindowHeight,
      ),
      maximumSize: const Size(              // 最大窗口尺寸
        WindowSizeManager.maxWindowWidth,
        WindowSizeManager.maxWindowHeight,
      ),
      title: title,                         // 窗口标题
    );

    // 恢复窗口位置（可能为null，表示首次启动）
    final position = await windowSizeManager.getPosition();

    // ========== Windows平台特殊处理 ==========
    if (UniversalPlatform.isWindows) {
      // 隐藏原生标题栏，使用自定义标题栏
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

      // 使用bitsdojo_window设置窗口属性
      doWhenWindowReady(() async {
        // 设置窗口的最小、最大和当前尺寸
        appWindow.minSize = windowOptions.minimumSize;
        appWindow.maxSize = windowOptions.maximumSize;
        appWindow.size = windowSize;

        // 恢复窗口位置
        if (position != null) {
          appWindow.position = position;
        }

        // Windows平台特有：恢复最大化状态
        // 如果上次关闭时窗口是最大化的，重新最大化
        final isMaximized = await windowSizeManager.getWindowMaximized();
        if (isMaximized) {
          appWindow.maximize();
        }
      });
    } else {
      // ========== macOS/Linux平台处理 ==========
      // 等待窗口准备就绪后显示
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();      // 显示窗口
        await windowManager.focus();      // 获取焦点

        // 恢复窗口位置
        if (position != null) {
          await windowManager.setPosition(position);
        }
      });
    }

    // 异步设置缩放因子（不阻塞启动流程）
    unawaited(
      windowSizeManager.getScaleFactor().then(
            (v) => ScaledWidgetsFlutterBinding.instance.scaleFactor = (_) => v,
          ),
    );
  }

  /// 窗口最大化事件处理
  /// 
  /// 当用户点击最大化按钮时触发
  /// 
  /// 处理逻辑：
  /// 1. 保存最大化状态为true
  /// 2. 将位置设置为(0,0)，因为最大化窗口总是从屏幕左上角开始
  @override
  Future<void> onWindowMaximize() async {
    super.onWindowMaximize();
    await windowSizeManager.setWindowMaximized(true);
    await windowSizeManager.setPosition(Offset.zero);
  }

  /// 窗口取消最大化事件处理
  /// 
  /// 当用户从最大化状态恢复窗口时触发
  /// 
  /// 处理逻辑：
  /// 1. 保存最大化状态为false
  /// 2. 获取并保存当前窗口位置
  @override
  Future<void> onWindowUnmaximize() async {
    super.onWindowUnmaximize();
    await windowSizeManager.setWindowMaximized(false);

    // 获取恢复后的窗口位置并保存
    final position = await windowManager.getPosition();
    return windowSizeManager.setPosition(position);
  }

  /// 窗口进入全屏模式事件处理
  /// 
  /// macOS平台特有，当用户点击全屏按钮时触发
  /// 
  /// 处理逻辑：
  /// 1. 标记为最大化状态（全屏视为最大化的一种）
  /// 2. 位置设为(0,0)
  @override
  void onWindowEnterFullScreen() async {
    super.onWindowEnterFullScreen();
    await windowSizeManager.setWindowMaximized(true);
    await windowSizeManager.setPosition(Offset.zero);
  }

  /// 窗口退出全屏模式事件处理
  /// 
  /// macOS平台特有，当用户退出全屏时触发
  /// 
  /// 处理逻辑：
  /// 1. 取消最大化状态标记
  /// 2. 获取并保存退出全屏后的窗口位置
  @override
  Future<void> onWindowLeaveFullScreen() async {
    super.onWindowLeaveFullScreen();
    await windowSizeManager.setWindowMaximized(false);

    // 获取退出全屏后的窗口位置
    final position = await windowManager.getPosition();
    return windowSizeManager.setPosition(position);
  }

  /// 窗口大小调整事件处理
  /// 
  /// 当用户拖动窗口边缘调整大小时触发
  /// 
  /// 处理逻辑：
  /// 获取新的窗口尺寸并保存到本地存储
  /// 
  /// 注意：
  /// - 此事件可能频繁触发，内部实现应考虑节流
  /// - 保存的尺寸会在下次启动时恢复
  @override
  Future<void> onWindowResize() async {
    super.onWindowResize();

    // 获取调整后的窗口大小
    final currentWindowSize = await windowManager.getSize();
    // 保存新的尺寸
    return windowSizeManager.setSize(currentWindowSize);
  }

  /// 窗口移动事件处理
  /// 
  /// 当用户拖动窗口标题栏移动窗口时触发
  /// 
  /// 处理逻辑：
  /// 获取新的窗口位置并保存
  /// 
  /// 使用场景：
  /// - 多显示器环境下记住窗口在哪个屏幕
  /// - 记住用户的布局偏好
  @override
  void onWindowMoved() async {
    super.onWindowMoved();

    // 获取移动后的窗口位置
    final position = await windowManager.getPosition();
    // 保存新位置
    return windowSizeManager.setPosition(position);
  }

  /// 任务销毁处理
  /// 
  /// 清理资源，移除窗口事件监听器
  /// 防止内存泄漏
  @override
  Future<void> dispose() async {
    await super.dispose();

    // 移除窗口事件监听器
    windowManager.removeListener(this);
  }
}
