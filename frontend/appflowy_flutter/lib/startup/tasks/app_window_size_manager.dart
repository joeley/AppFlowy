import 'dart:convert';
import 'dart:ui';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/startup/startup.dart';

/// 窗口大小管理器
/// 
/// 负责桌面端应用窗口的尺寸和位置管理
/// 
/// 核心功能：
/// 1. 窗口尺寸的持久化存储
/// 2. 窗口位置的记忆和恢复
/// 3. 缩放因子管理（DPI适配）
/// 4. 窗口最大化状态管理
/// 
/// 设计特点：
/// - 尺寸限制防止窗口过小或过大
/// - 使用JSON存储复杂数据结构
/// - 支持高DPI显示器
/// 
/// 使用场景：
/// - 应用启动时恢复上次的窗口状态
/// - 用户调整窗口时保存新的状态
/// - 适配不同DPI的显示器
class WindowSizeManager {
  /// 最小窗口高度（像素）
  /// 
  /// 640像素确保所有UI元素都能正常显示
  /// 低于此值可能导致界面元素重叠或无法操作
  static const double minWindowHeight = 640.0;
  
  /// 最小窗口宽度（像素）
  /// 
  /// 640像素确保侧边栏和主内容区都有足够空间
  static const double minWindowWidth = 640.0;
  
  /// 最大窗口高度（像素）
  /// 
  /// 限制原因：
  /// 1. GPU纹理大小有硬件限制
  /// 2. 超过8192可能导致纹理描述符验证失败
  /// 3. 避免内存溢出
  static const double maxWindowHeight = 8192.0;
  static const double maxWindowWidth = 8192.0;

  /// 默认窗口尺寸
  /// 
  /// 960x1280是经过优化的默认尺寸：
  /// - 适合大多数笔记本和桌面显示器
  /// - 提供良好的内容展示空间
  /// - 不会占满整个屏幕，方便多任务操作
  static const double defaultWindowHeight = 960.0;
  static const double defaultWindowWidth = 1280.0;

  /// 界面缩放因子范围
  /// 
  /// maxScaleFactor = 2.0：最大200%缩放，适合4K显示器
  /// minScaleFactor = 0.5：最小50%缩放，适合低分辨率显示器
  /// 
  /// 缩放因子用途：
  /// - 适配不同DPI的显示器
  /// - 解决高分辨率屏幕上界面过小的问题
  /// - 让用户根据视力需求调整界面大小
  static const double maxScaleFactor = 2.0;
  static const double minScaleFactor = 0.5;

  /// JSON存储时使用的键名常量
  /// 
  /// 这些键用于序列化窗口状态到JSON
  static const width = 'width';
  static const height = 'height';
  static const String dx = 'dx';     // 窗口左上角X坐标
  static const String dy = 'dy';     // 窗口左上角Y坐标

  /// 保存窗口尺寸到本地存储
  /// 
  /// 功能说明：
  /// 1. 接收新的窗口尺寸
  /// 2. 使用clamp确保尺寸在合理范围内
  /// 3. 将尺寸序列化为JSON格式
  /// 4. 持久化存储到键值数据库
  /// 
  /// 参数：
  /// - [size]: 要保存的窗口尺寸（宽度和高度）
  /// 
  /// 使用场景：
  /// - 用户手动调整窗口大小时
  /// - 程序退出前保存当前状态
  Future<void> setSize(Size size) async {
    // 创建窗口尺寸对象，同时限制在最小最大值范围内
    final windowSize = {
      height: size.height.clamp(minWindowHeight, maxWindowHeight),
      width: size.width.clamp(minWindowWidth, maxWindowWidth),
    };

    // 存储到本地键值数据库
    await getIt<KeyValueStorage>().set(
      KVKeys.windowSize,
      jsonEncode(windowSize),  // 转换为JSON字符串存储
    );
  }

  /// 从本地存储获取窗口尺寸
  /// 
  /// 功能说明：
  /// 1. 尝试从存储中读取保存的窗口尺寸
  /// 2. 如果没有保存的尺寸，使用默认值
  /// 3. 解析JSON数据并提取宽高
  /// 4. 再次验证尺寸范围确保安全
  /// 
  /// 返回值：
  /// - Size对象，包含窗口的宽度和高度
  /// 
  /// 使用场景：
  /// - 应用启动时恢复窗口大小
  /// - 重置窗口时获取上次的尺寸
  Future<Size> getSize() async {
    // 准备默认窗口尺寸的JSON字符串
    final defaultWindowSize = jsonEncode(
      {
        WindowSizeManager.height: defaultWindowHeight,
        WindowSizeManager.width: defaultWindowWidth,
      },
    );
    
    // 从存储中读取保存的窗口尺寸
    final windowSize = await getIt<KeyValueStorage>().get(KVKeys.windowSize);
    
    // 解析JSON，如果没有保存的值则使用默认值
    final size = json.decode(
      windowSize ?? defaultWindowSize,
    );
    
    // 提取宽高值，如果解析失败则使用最小值
    final double width = size[WindowSizeManager.width] ?? minWindowWidth;
    final double height = size[WindowSizeManager.height] ?? minWindowHeight;
    
    // 返回Size对象，确保值在合理范围内
    return Size(
      width.clamp(minWindowWidth, maxWindowWidth),
      height.clamp(minWindowHeight, maxWindowHeight),
    );
  }

  /// 保存窗口位置到本地存储
  /// 
  /// 功能说明：
  /// 1. 接收窗口在屏幕上的位置坐标
  /// 2. 将X、Y坐标封装为JSON对象
  /// 3. 持久化存储位置信息
  /// 
  /// 参数：
  /// - [offset]: 窗口左上角在屏幕上的坐标位置
  /// 
  /// 使用场景：
  /// - 用户拖动窗口后保存新位置
  /// - 程序退出前记录窗口位置
  /// - 多显示器环境下记住在哪个屏幕
  Future<void> setPosition(Offset offset) async {
    await getIt<KeyValueStorage>().set(
      KVKeys.windowPosition,
      jsonEncode({
        dx: offset.dx,  // X坐标（水平位置）
        dy: offset.dy,  // Y坐标（垂直位置）
      }),
    );
  }

  /// 从本地存储获取窗口位置
  /// 
  /// 功能说明：
  /// 1. 从存储中读取保存的窗口位置
  /// 2. 如果没有保存的位置，返回null
  /// 3. 解析JSON并创建Offset对象
  /// 
  /// 返回值：
  /// - Offset对象：包含窗口位置坐标
  /// - null：如果没有保存的位置（首次启动）
  /// 
  /// 使用场景：
  /// - 应用启动时恢复窗口位置
  /// - 判断是否需要居中显示（返回null时）
  Future<Offset?> getPosition() async {
    final position = await getIt<KeyValueStorage>().get(KVKeys.windowPosition);
    if (position == null) {
      return null;  // 没有保存的位置，让系统决定
    }
    final offset = json.decode(position);
    return Offset(offset[dx], offset[dy]);
  }

  /// 获取界面缩放因子
  /// 
  /// 功能说明：
  /// 1. 从存储中读取保存的缩放因子
  /// 2. 如果解析失败或没有值，默认返回1.0（100%缩放）
  /// 3. 确保缩放因子在合理范围内（0.5-2.0）
  /// 
  /// 返回值：
  /// - double：缩放因子（0.5到2.0之间）
  /// 
  /// 使用场景：
  /// - 应用启动时设置界面缩放
  /// - 适配高DPI显示器
  /// - 用户自定义界面大小
  /// 
  /// 示例：
  /// - 1.0 = 100%标准大小
  /// - 1.5 = 150%放大（适合高分屏）
  /// - 0.75 = 75%缩小
  Future<double> getScaleFactor() async {
    final scaleFactor = await getIt<KeyValueStorage>().getWithFormat<double>(
          KVKeys.scaleFactor,
          (value) => double.tryParse(value) ?? 1.0,  // 解析失败返回1.0
        ) ??
        1.0;  // 没有保存的值返回1.0
    return scaleFactor.clamp(minScaleFactor, maxScaleFactor);
  }

  /// 保存界面缩放因子
  /// 
  /// 功能说明：
  /// 1. 接收新的缩放因子
  /// 2. 限制在合理范围内（0.5-2.0）
  /// 3. 转换为字符串存储
  /// 
  /// 参数：
  /// - [scaleFactor]: 新的缩放因子（会自动限制范围）
  /// 
  /// 使用场景：
  /// - 用户在设置中调整界面缩放
  /// - 自动适配高DPI显示器
  Future<void> setScaleFactor(double scaleFactor) async {
    await getIt<KeyValueStorage>().set(
      KVKeys.scaleFactor,
      '${scaleFactor.clamp(minScaleFactor, maxScaleFactor)}',
    );
  }

  /// 保存窗口最大化状态
  /// 
  /// 功能说明：
  /// 记录窗口是否处于最大化状态
  /// 
  /// 参数：
  /// - [isMaximized]: true表示最大化，false表示正常窗口
  /// 
  /// 使用场景：
  /// - 用户点击最大化按钮后
  /// - 程序退出前保存最大化状态
  /// - 下次启动时恢复最大化状态
  Future<void> setWindowMaximized(bool isMaximized) async {
    await getIt<KeyValueStorage>()
        .set(KVKeys.windowMaximized, isMaximized.toString());
  }

  /// 获取窗口最大化状态
  /// 
  /// 功能说明：
  /// 1. 从存储中读取最大化状态
  /// 2. 解析布尔值，失败则返回false
  /// 
  /// 返回值：
  /// - true：窗口应该最大化
  /// - false：窗口应该保持正常大小
  /// 
  /// 使用场景：
  /// - 应用启动时决定是否最大化窗口
  /// - 恢复用户的窗口布局偏好
  Future<bool> getWindowMaximized() async {
    return await getIt<KeyValueStorage>().getWithFormat<bool>(
          KVKeys.windowMaximized,
          (v) => bool.tryParse(v) ?? false,  // 解析失败返回false
        ) ??
        false;  // 没有保存的值返回false
  }
}
