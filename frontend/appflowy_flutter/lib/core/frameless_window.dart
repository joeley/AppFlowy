import 'package:appflowy/startup/tasks/device_info_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_platform/universal_platform.dart';

/// macOS窗口控制通道
/// 
/// 通过Method Channel与原生macOS代码通信，控制无边框窗口
/// 
/// 主要功能：
/// 1. 设置窗口位置
/// 2. 获取窗口位置
/// 3. 窗口缩放（双击标题栏效果）
/// 
/// 设计思想：
/// - 单例模式确保全局只有一个实例
/// - 通过Flutter的MethodChannel与原生代码通信
/// - 专门为macOS无边框窗口设计
class CocoaWindowChannel {
  CocoaWindowChannel._();

  /// Method Channel用于与原生代码通信
  final MethodChannel _channel = const MethodChannel("flutter/cocoaWindow");

  /// 单例实例
  static final CocoaWindowChannel instance = CocoaWindowChannel._();

  /// 设置窗口位置
  /// 
  /// 参数：
  /// - [offset]: 窗口左上角的屏幕坐标
  Future<void> setWindowPosition(Offset offset) async {
    await _channel.invokeMethod("setWindowPosition", [offset.dx, offset.dy]);
  }

  /// 获取窗口当前位置
  /// 
  /// 返回：[x, y]坐标数组
  Future<List<double>> getWindowPosition() async {
    final raw = await _channel.invokeMethod("getWindowPosition");
    final arr = raw as List<dynamic>;
    final List<double> result = arr.map((s) => s as double).toList();
    return result;
  }

  /// 窗口缩放
  /// 
  /// 模拟双击标题栏的效果，在最大化和正常大小之间切换
  Future<void> zoom() async {
    await _channel.invokeMethod("zoom");
  }
}

/// 移动窗口检测器
/// 
/// 为无边框窗口提供拖动功能，模拟标题栏的拖动行为
/// 
/// 主要功能：
/// 1. 检测拖动手势并移动窗口
/// 2. 双击缩放窗口
/// 3. 仅在macOS上生效
/// 
/// 设计思想：
/// - 通过GestureDetector捕获拖动手势
/// - 计算鼠标移动的增量并更新窗口位置
/// - 兼容macOS 15+的系统API
class MoveWindowDetector extends StatefulWidget {
  const MoveWindowDetector({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  MoveWindowDetectorState createState() => MoveWindowDetectorState();
}

class MoveWindowDetectorState extends State<MoveWindowDetector> {
  /// 记录拖动开始时的鼠标X坐标
  double winX = 0;
  /// 记录拖动开始时的鼠标Y坐标
  double winY = 0;

  @override
  Widget build(BuildContext context) {
    // 无边框窗口仅在macOS上支持
    if (!UniversalPlatform.isMacOS) {
      return widget.child ?? const SizedBox.shrink();
    }

    // macOS 15及以上版本使用系统API控制窗口位置，不需要此组件
    if (ApplicationInfo.macOSMajorVersion != null &&
        ApplicationInfo.macOSMajorVersion! >= 15) {
      return widget.child ?? const SizedBox.shrink();
    }

    return GestureDetector(
      // 确保手势可以穿透透明区域
      // 参考：https://stackoverflow.com/questions/52965799/flutter-gesturedetector-not-working-with-containers-in-stack
      behavior: HitTestBehavior.translucent,
      // 双击缩放窗口
      onDoubleTap: () async => CocoaWindowChannel.instance.zoom(),
      // 记录拖动开始位置
      onPanStart: (DragStartDetails details) {
        winX = details.globalPosition.dx;
        winY = details.globalPosition.dy;
      },
      // 处理拖动更新
      onPanUpdate: (DragUpdateDetails details) async {
        // 获取窗口当前位置
        final windowPos = await CocoaWindowChannel.instance.getWindowPosition();
        final double dx = windowPos[0];
        final double dy = windowPos[1];
        // 计算鼠标移动增量
        final deltaX = details.globalPosition.dx - winX;
        final deltaY = details.globalPosition.dy - winY;
        // 更新窗口位置（注意Y轴方向相反）
        await CocoaWindowChannel.instance
            .setWindowPosition(Offset(dx + deltaX, dy - deltaY));
      },
      child: widget.child,
    );
  }
}
