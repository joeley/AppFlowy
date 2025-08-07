import 'dart:async';

import 'package:flutter/foundation.dart';
// 内存泄漏跟踪库
import 'package:leak_tracker/leak_tracker.dart';

import '../startup.dart';

/// 是否启用内存泄漏检测
/// 默认关闭，因为会影响性能
bool enableMemoryLeakDetect = false;
/// 是否每秒输出内存泄漏信息
/// 用于实时监控内存状态
bool dumpMemoryLeakPerSecond = false;

/// 输出内存泄漏信息
/// 
/// @param type 泄漏类型：
/// - notDisposed: 未释放的对象
/// - notGCed: 未被垃圾回收的对象
/// - gcedLate: 延迟回收的对象
void dumpMemoryLeak({
  LeakType type = LeakType.notDisposed,
}) async {
  final details = await LeakTracking.collectLeaks();
  details.dumpDetails(type);
}

/// 内存泄漏检测任务
/// 
/// 这是启动流程中的第二个任务
/// 
/// 主要功能：
/// 1. 监控Flutter对象的内存分配和释放
/// 2. 检测未正确释放的对象（内存泄漏）
/// 3. 提供实时或定期的泄漏报告
/// 
/// 这个工具在开发阶段非常有用，可以帮助发现：
/// - 未正确释放的Controller
/// - 循环引用导致的内存泄漏
/// - Stream未取消订阅等问题
/// 
/// 类似于Java的Memory Profiler或Android Studio的LeakCanary
class MemoryLeakDetectorTask extends LaunchTask {
  MemoryLeakDetectorTask();

  /// 定时器，用于定期输出内存泄漏信息
  Timer? _timer;

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 仅在调试模式且显式启用时才运行
    // 因为内存泄漏检测会影响性能
    if (!kDebugMode || !enableMemoryLeakDetect) {
      return;
    }

    // 启动内存泄漏跟踪
    LeakTracking.start();
    
    // 配置泄漏诊断参数
    LeakTracking.phase = const PhaseSettings(
      leakDiagnosticConfig: LeakDiagnosticConfig(
        // 收集未被垃圾回收对象的引用路径
        // 这有助于找到是谁持有了该对象的引用
        collectRetainingPathForNotGCed: true,
        // 在对象创建时收集堆栈信息
        // 可以追踪对象是在哪里创建的
        collectStackTraceOnStart: true,
      ),
    );

    // 监听Flutter内存分配事件
    FlutterMemoryAllocations.instance.addListener((p0) {
      // 将内存事件转发给LeakTracking
      LeakTracking.dispatchObjectEvent(p0.toMap());
    });

    // dump memory leak per second if needed
    // 如果需要实时监控，每秒输出一次泄漏信息
    if (dumpMemoryLeakPerSecond) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        // 检查是否有泄漏
        final summary = await LeakTracking.checkLeaks();
        if (summary.isEmpty) {
          return;
        }

        // 输出泄漏详情
        dumpMemoryLeak();
      });
    }
  }

  @override
  Future<void> dispose() async {
    await super.dispose();

    if (!kDebugMode || !enableMemoryLeakDetect) {
      return;
    }

    // 清理定时器
    if (dumpMemoryLeakPerSecond) {
      _timer?.cancel();
      _timer = null;
    }

    // 停止内存泄漏跟踪
    LeakTracking.stop();
  }
}

/// LeakType的扩展，提供友好的描述文本
extension on LeakType {
  String get desc => switch (this) {
        LeakType.notDisposed => 'not disposed',  // 未调用dispose方法
        LeakType.notGCed => 'not GCed',          // 未被垃圾回收
        LeakType.gcedLate => 'GCed late'         // 延迟垃圾回收
      };
}

/// 需要输出泄漏信息的包名
/// 只关注自己的代码，忽略第三方库的泄漏
final _dumpablePackages = [
  'package:appflowy/',         // 主应用
  'package:appflowy_editor/',  // 编辑器组件
];

/// Leaks的扩展，用于输出泄漏详情
extension on Leaks {
  /// 输出泄漏详细信息
  /// 
  /// 这个方法会：
  /// 1. 输出泄漏摘要
  /// 2. 过滤出属于AppFlowy代码的泄漏
  /// 3. 显示泄漏对象的创建堆栈
  void dumpDetails(LeakType type) {
    // 构建摘要信息
    final summary = '${type.desc}: ${switch (type) {
      LeakType.notDisposed => '${notDisposed.length}',
      LeakType.notGCed => '${notGCed.length}',
      LeakType.gcedLate => '${gcedLate.length}'
    }}';
    debugPrint(summary);
    
    // 获取对应类型的泄漏列表
    final details = switch (type) {
      LeakType.notDisposed => notDisposed,
      LeakType.notGCed => notGCed,
      LeakType.gcedLate => gcedLate
    };

    // only dump the code in appflowy
    // 遍历每个泄漏对象
    for (final value in details) {
      // 获取对象创建时的堆栈信息
      final stack = value.context![ContextKeys.startCallstack]! as StackTrace;
      
      // 过滤堆栈，只保留AppFlowy相关的调用
      final stackInAppFlowy = stack
          .toString()
          .split('\n')
          .where(
            (stack) =>
                // ignore current file call stack
                // 忽略当前文件的调用栈
                !stack.contains('memory_leak_detector') &&
                // 只保留指定包名的调用栈
                _dumpablePackages.any((pkg) => stack.contains(pkg)),
          )
          .join('\n');

      // ignore the untreatable leak
      // 如果没有AppFlowy相关的堆栈，跳过
      // 这通常是第三方库的泄漏，我们无法处理
      if (stackInAppFlowy.isEmpty) {
        continue;
      }

      // 输出泄漏对象和其创建堆栈
      final object = value.type;
      debugPrint('''
$object ${type.desc}
$stackInAppFlowy
''');
    }
  }
}
