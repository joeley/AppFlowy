import 'package:appflowy/startup/startup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talker/talker.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'package:universal_platform/universal_platform.dart';

/*
 * 调试任务
 * 
 * 在开发模式下执行的初始化任务
 * 
 * 主要功能：
 * 1. 移动端隐藏键盘
 * 2. BLoC事件日志记录
 * 3. Rust请求跟踪（可选）
 * 
 * 设计目的：
 * - 帮助开发者调试应用状态变化
 * - 跟踪业务逻辑执行流程
 * - 提供详细的运行时信息
 */

class DebugTask extends LaunchTask {
  DebugTask();

  /* Talker日志器实例，用于构建化日志输出 */
  final Talker talker = Talker();

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    /* 移动端隐藏键盘
     * 避免开发过程中键盘意外弹出
     * 仅在调试模式下生效
     */
    if (UniversalPlatform.isMobile && kDebugMode) {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    }

    /* BLoC事件日志记录器
     * 
     * 配置说明：
     * - enabled: 是否启用日志（默认关闭，避免日志过多）
     * - printEventFullData: 是否打印完整事件数据
     * - printStateFullData: 是否打印完整状态数据
     * - printChanges: 是否打印状态变化
     * - printClosings: 是否打印BLoC关闭事件
     * - printCreations: 是否打印BLoC创建事件
     * - transitionFilter: 过滤器，可以选择性监听特定BLoC
     * 
     * 使用场景：
     * 1. 调试特定功能的状态管理
     * 2. 跟踪复杂的业务流程
     * 3. 分析性能瓶颈
     */
    if (kDebugMode) {
      Bloc.observer = TalkerBlocObserver(
        talker: talker,
        settings: TalkerBlocLoggerSettings(
          enabled: false,  /* 默认关闭，需要时手动开启 */
          printEventFullData: false,
          printStateFullData: false,
          printChanges: true,
          printClosings: true,
          printCreations: true,
          transitionFilter: (bloc, transition) {
            /* 默认观察所有BLoC的状态转换
             * 可以添加自定义过滤逻辑
             * 例如：return bloc.runtimeType.toString().contains('Workspace');
             * 仅监听工作区相关的BLoC
             */
            return true;
          },
        ),
      );

      /* Rust请求跟踪
       * 启用后会记录所有Flutter与Rust之间的通信
       * 对性能有影响，仅在需要调试FFI通信时开启
       */
      // Dispatch.enableTracing = true;
    }
  }
}
