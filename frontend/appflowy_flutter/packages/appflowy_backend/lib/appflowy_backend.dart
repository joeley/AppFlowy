import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

// 日志工具
import 'package:appflowy_backend/log.dart';
// Rust流数据接收器
import 'package:appflowy_backend/rust_stream.dart';
// FFI（Foreign Function Interface）工具
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// FFI绑定文件，包含Rust库的C接口
import 'ffi.dart' as ffi;

export 'package:async/async.dart';

/* AppFlowy SDK异常类型枚举 */
enum ExceptionType {
  AppearanceSettingsIsEmpty,  // 外观设置为空
}

/* AppFlowy SDK异常类
 * 
 * 用于处理SDK初始化和运行过程中的异常情况
 */
class FlowySDKException implements Exception {
  ExceptionType type;
  FlowySDKException(this.type);
}

/* AppFlowy SDK主类
 * 
 * 这是AppFlowy客户端的核心SDK类，负责：
 * 1. 初始化Flutter与Rust后端的FFI连接
 * 2. 建立数据流通信管道
 * 3. 配置日志系统
 * 
 * AppFlowy架构说明：
 * - Flutter：负责UI渲染和用户交互
 * - Rust：负责核心业务逻辑、数据处理、文件I/O、网络同步等
 * - FFI：两者之间的桥梁，实现高性能的跨语言调用
 * 
 * 通信机制：
 * - 同步调用：直接通过FFI调用Rust函数
 * - 异步调用：通过消息分发系统
 * - 事件流：Rust主动向Flutter发送通知
 */
class FlowySDK {
  // 方法通道，用于与原生平台通信（iOS/Android）
  static const MethodChannel _channel = MethodChannel('appflowy_backend');
  
  /* 获取平台版本信息
   * 
   * 主要用于调试和兼容性检查
   */
  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  FlowySDK();

  /* 释放资源
   * 
   * 当应用关闭时调用，清理FFI连接和释放内存
   */
  Future<void> dispose() async {}

  /* 初始化AppFlowy SDK
   * 
   * 参数：
   * - configuration: JSON格式的配置字符串，包含：
   *   - 数据存储路径
   *   - 设备ID
   *   - 云服务配置
   *   - 认证类型等
   * 
   * 初始化流程：
   * 1. 设置Rust到Dart的通信端口
   * 2. 配置日志系统（iOS特殊处理）
   * 3. 调用Rust的初始化函数
   * 4. 验证初始化结果
   */
  Future<void> init(String configuration) async {
    // 设置Rust向Dart发送数据的端口
    // 这个端口用于接收来自Rust的事件通知
    ffi.set_stream_port(RustStreamReceiver.shared.port);
    
    // 设置Dart的NativeApi.postCObject函数指针
    // 允许Rust代码向Dart发送消息
    ffi.store_dart_post_cobject(NativeApi.postCObject);

    // iOS平台的特殊日志处理
    // 在iOS的VSCode调试环境中，Rust的日志无法正常显示
    // 因此需要通过专用端口接收日志并在Dart层打印
    if (Platform.isIOS && kDebugMode) {
      ffi.set_log_stream_port(RustLogStreamReceiver.logShared.port);
    }

    // 调用Rust的SDK初始化函数
    // 参数0：保留参数，暂未使用
    // configuration：配置字符串，转换为C字符串格式
    final code = ffi.init_sdk(0, configuration.toNativeUtf8());
    
    // 检查初始化结果
    // 非0返回值表示初始化失败
    if (code != 0) {
      throw Exception('Failed to initialize the SDK');
    }
  }
}

/* Rust日志流接收器
 * 
 * 专门用于接收来自Rust后端的日志消息
 * 
 * 设计原因：
 * - 在iOS平台上，VSCode无法直接显示Rust的日志输出
 * - 通过这个接收器将Rust日志转发到Dart日志系统
 * - 只在调试模式下启用，避免发布版本的性能损耗
 * 
 * 工作流程：
 * 1. Rust将日志消息通过FFI发送到指定端口
 * 2. _ffiPort接收原始字节数据
 * 3. 通过StreamController转换为字符串
 * 4. 使用Dart的日志系统输出
 * 
 * 单例模式：确保全局只有一个日志接收器实例
 */
class RustLogStreamReceiver {
  // 全局共享实例
  static RustLogStreamReceiver logShared = RustLogStreamReceiver._internal();
  
  // FFI原始接收端口
  late RawReceivePort _ffiPort;
  // 流控制器，将原始数据转换为流
  late StreamController<Uint8List> _streamController;
  // 流订阅，处理接收到的日志数据
  late StreamSubscription<Uint8List> _subscription;
  
  // 获取端口号，供Rust代码使用
  int get port => _ffiPort.sendPort.nativePort;

  /* 私有构造函数
   * 
   * 初始化整个日志接收管道：
   * 1. 创建FFI接收端口
   * 2. 设置数据处理流水线
   * 3. 启动日志监听
   */
  RustLogStreamReceiver._internal() {
    // 创建原始接收端口，用于接收来自Rust的数据
    _ffiPort = RawReceivePort();
    // 创建流控制器，处理数据流
    _streamController = StreamController();
    // 将接收到的数据添加到流中
    _ffiPort.handler = _streamController.add;

    // 监听数据流，处理日志消息
    _subscription = _streamController.stream.listen((data) {
      // 将字节数据解码为UTF-8字符串
      String decodedString = utf8.decode(data);
      // 通过Dart日志系统输出
      Log.info(decodedString);
    });
  }

  /* 工厂构造函数
   * 
   * 返回全局共享实例，确保单例模式
   */
  factory RustLogStreamReceiver() {
    return logShared;
  }

  /* 清理资源
   * 
   * 应用关闭时调用，清理所有相关资源：
   * 1. 关闭流控制器
   * 2. 取消数据订阅
   * 3. 关闭FFI端口
   */
  Future<void> dispose() async {
    await _streamController.close();
    await _subscription.cancel();
    _ffiPort.close();
  }
}
