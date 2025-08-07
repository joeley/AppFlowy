// 日志系统
import 'package:appflowy_backend/log.dart';
// UI基础组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// Flutter基础库，提供kDebugMode常量
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../startup.dart';

/// 平台错误捕获任务
/// 
/// 这是启动流程中的第一个任务（非测试模式下）
/// 
/// 主要职责：
/// 1. 捕获未被Flutter框架处理的平台级错误
/// 2. 自定义错误小部件的显示方式
/// 3. 防止应用因未处理错误而崩溃
/// 
/// 这个任务必须最先执行，以确保后续任务的错误都能被捕获
/// 类似于Java中的Thread.setDefaultUncaughtExceptionHandler
class PlatformErrorCatcherTask extends LaunchTask {
  const PlatformErrorCatcherTask();

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // Handle platform errors not caught by Flutter.
    // Reduces the likelihood of the app crashing, and logs the error.
    // only active in non debug mode.
    // 
    // 设置全局错误处理器
    // 仅在非调试模式下生效，调试模式保留默认行为以便开发者调试
    if (!kDebugMode) {
      // PlatformDispatcher是Flutter底层平台的分发器
      // onError回调会捕获所有未被Flutter框架处理的错误
      PlatformDispatcher.instance.onError = (error, stack) {
        // 记录错误日志，便于后续分析
        Log.error('Uncaught platform error', error, stack);
        // 返回true表示错误已被处理，防止应用崩溃
        return true;
      };
    }

    // 自定义错误小部件的显示方式
    // 当Widget构建过程中出现错误时，会显示这个错误小部件
    // 默认是红屏错误（Red Screen of Death）
    ErrorWidget.builder = (details) {
      if (kDebugMode) {
        // 调试模式：显示简化的错误信息
        // 避免占据太多屏幕空间，便于开发者查看其他内容
        return Container(
          width: double.infinity,
          height: 30,
          color: Colors.red,
          child: FlowyText(
            'ERROR: ${details.exceptionAsString()}',
            color: Colors.white,
          ),
        );
      }

      // hide the error widget in release mode
      // 发布模式：完全隐藏错误
      // 避免用户看到技术性错误信息，提升用户体验
      // 错误仍会被记录在日志中
      return const SizedBox.shrink();
    };
  }
}
