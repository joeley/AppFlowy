import 'dart:convert';
import 'dart:ui';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/startup/startup.dart';

/*
 * 窗口大小管理器
 * 
 * 负责桌面端应用窗口的尺寸和位置管理
 * 
 * 核心功能：
 * 1. 窗口尺寸的持久化存储
 * 2. 窗口位置的记忆和恢复
 * 3. 缩放因子管理（DPI适配）
 * 4. 窗口最大化状态管理
 * 
 * 设计特点：
 * - 尺寸限制防止窗口过小或过大
 * - 使用JSON存储复杂数据结构
 * - 支持高DPI显示器
 */

class WindowSizeManager {
  /* 最小窗口高度，确保UI元素可见 */
  static const double minWindowHeight = 640.0;
  /* 最小窗口宽度，确保基本功能可用 */
  static const double minWindowWidth = 640.0;
  /* 最大窗口高度
   * 限制原因：避免纹理描述符验证失败
   * GPU纹理大小有硬件限制
   */
  static const double maxWindowHeight = 8192.0;
  static const double maxWindowWidth = 8192.0;

  /* 默认窗口尺寸
   * 960x1280是一个常见的适中尺寸
   * 适合大多数显示器
   */
  static const double defaultWindowHeight = 960.0;
  static const double defaultWindowWidth = 1280.0;

  /* 缩放因子范围
   * 支持50%到200%的界面缩放
   * 用于高DPI显示器适配
   */
  static const double maxScaleFactor = 2.0;
  static const double minScaleFactor = 0.5;

  /* JSON键名常量 */
  static const width = 'width';
  static const height = 'height';
  static const String dx = 'dx';
  static const String dy = 'dy';

  Future<void> setSize(Size size) async {
    final windowSize = {
      height: size.height.clamp(minWindowHeight, maxWindowHeight),
      width: size.width.clamp(minWindowWidth, maxWindowWidth),
    };

    await getIt<KeyValueStorage>().set(
      KVKeys.windowSize,
      jsonEncode(windowSize),
    );
  }

  Future<Size> getSize() async {
    final defaultWindowSize = jsonEncode(
      {
        WindowSizeManager.height: defaultWindowHeight,
        WindowSizeManager.width: defaultWindowWidth,
      },
    );
    final windowSize = await getIt<KeyValueStorage>().get(KVKeys.windowSize);
    final size = json.decode(
      windowSize ?? defaultWindowSize,
    );
    final double width = size[WindowSizeManager.width] ?? minWindowWidth;
    final double height = size[WindowSizeManager.height] ?? minWindowHeight;
    return Size(
      width.clamp(minWindowWidth, maxWindowWidth),
      height.clamp(minWindowHeight, maxWindowHeight),
    );
  }

  Future<void> setPosition(Offset offset) async {
    await getIt<KeyValueStorage>().set(
      KVKeys.windowPosition,
      jsonEncode({
        dx: offset.dx,
        dy: offset.dy,
      }),
    );
  }

  Future<Offset?> getPosition() async {
    final position = await getIt<KeyValueStorage>().get(KVKeys.windowPosition);
    if (position == null) {
      return null;
    }
    final offset = json.decode(position);
    return Offset(offset[dx], offset[dy]);
  }

  Future<double> getScaleFactor() async {
    final scaleFactor = await getIt<KeyValueStorage>().getWithFormat<double>(
          KVKeys.scaleFactor,
          (value) => double.tryParse(value) ?? 1.0,
        ) ??
        1.0;
    return scaleFactor.clamp(minScaleFactor, maxScaleFactor);
  }

  Future<void> setScaleFactor(double scaleFactor) async {
    await getIt<KeyValueStorage>().set(
      KVKeys.scaleFactor,
      '${scaleFactor.clamp(minScaleFactor, maxScaleFactor)}',
    );
  }

  /// Set the window maximized status
  Future<void> setWindowMaximized(bool isMaximized) async {
    await getIt<KeyValueStorage>()
        .set(KVKeys.windowMaximized, isMaximized.toString());
  }

  /// Get the window maximized status
  Future<bool> getWindowMaximized() async {
    return await getIt<KeyValueStorage>().getWithFormat<bool>(
          KVKeys.windowMaximized,
          (v) => bool.tryParse(v) ?? false,
        ) ??
        false;
  }
}
