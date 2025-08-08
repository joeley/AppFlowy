import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:appflowy_backend/log.dart';

// 订阅对象的Protocol Buffer定义
import 'protobuf/flowy-notification/subject.pb.dart';

/* 观察者回调函数类型定义
 * 
 * 用于处理来自Rust后端的事件通知
 * 参数：observable - 包含事件类型和数据的订阅对象
 */
typedef ObserverCallback = void Function(SubscribeObject observable);

/* Rust流接收器
 * 
 * AppFlowy中最重要的通信组件之一，负责接收来自Rust后端的实时事件流
 * 
 * 核心功能：
 * 1. 接收Rust主动推送的事件通知
 * 2. 反序列化Protocol Buffer数据
 * 3. 将事件分发给各个订阅者
 * 4. 处理通信错误和异常
 * 
 * 设计模式：
 * - 单例模式：确保全应用只有一个流接收器
 * - 观察者模式：支持多个组件监听事件
 * - 广播流：事件可以被多个订阅者同时接收
 * 
 * 通信机制：
 * Rust后端 -> FFI端口 -> 原始字节流 -> Protocol Buffer解析 -> 事件分发 -> 业务组件
 * 
 * 应用场景：
 * - 文档内容实时同步通知
 * - 数据库记录变更通知
 * - 用户状态变化通知
 * - 网络连接状态变化
 * - 错误和警告消息
 */
class RustStreamReceiver {
  // 全局共享实例（单例模式）
  static RustStreamReceiver shared = RustStreamReceiver._internal();
  
  // FFI原始接收端口，接收来自Rust的字节数据
  late RawReceivePort _ffiPort;
  // 字节流控制器，将FFI数据转换为流
  late StreamController<Uint8List> _streamController;
  // 事件对象流控制器，广播解析后的事件对象
  late StreamController<SubscribeObject> _observableController;
  // 字节流订阅，处理原始数据
  late StreamSubscription<Uint8List> _ffiSubscription;

  // 获取FFI端口号，供Rust代码使用
  int get port => _ffiPort.sendPort.nativePort;
  
  // 获取事件流控制器，供外部组件监听
  StreamController<SubscribeObject> get observable => _observableController;

  /* 私有构造函数
   * 
   * 初始化完整的事件流水线：
   * 1. 创建FFI接收端口
   * 2. 设置字节流和事件流控制器
   * 3. 建立数据处理管道
   * 4. 启动事件监听
   */
  RustStreamReceiver._internal() {
    // 创建FFI端口，接收来自Rust的数据
    _ffiPort = RawReceivePort();
    // 创建字节流控制器
    _streamController = StreamController();
    // 创建广播事件流控制器，允许多个订阅者
    _observableController = StreamController.broadcast();

    // 设置FFI端口处理器，将接收到的数据添加到字节流
    _ffiPort.handler = _streamController.add;
    // 订阅字节流，处理每个接收到的数据包
    _ffiSubscription = _streamController.stream.listen(_streamCallback);
  }

  /* 工厂构造函数
   * 
   * 返回全局共享实例，确保单例模式
   */
  factory RustStreamReceiver() {
    return shared;
  }

  /* 静态监听方法
   * 
   * 提供便捷的事件监听接口
   * 
   * 参数：
   * - callback: 事件处理回调函数
   * 
   * 返回：
   * - StreamSubscription: 流订阅对象，可用于取消监听
   * 
   * 使用示例：
   * ```dart
   * final subscription = RustStreamReceiver.listen((event) {
   *   print('收到事件: ${event.subject}');
   * });
   * ```
   */
  static StreamSubscription<SubscribeObject> listen(
      void Function(SubscribeObject subject) callback) {
    return RustStreamReceiver.shared.observable.stream.listen(callback);
  }

  /* 流数据回调处理
   * 
   * 处理从Rust接收到的原始字节数据：
   * 1. 使用Protocol Buffers反序列化
   * 2. 将解析后的事件对象发送到事件流
   * 3. 错误处理和日志记录
   * 
   * 参数：
   * - bytes: 来自Rust的原始字节数据
   * 
   * 错误处理：
   * - 记录详细的错误信息和堆栈跟踪
   * - 重新抛出异常，让上层组件处理
   */
  void _streamCallback(Uint8List bytes) {
    try {
      // 使用Protocol Buffers反序列化订阅对象
      final observable = SubscribeObject.fromBuffer(bytes);
      // 将解析后的事件对象添加到广播流
      _observableController.add(observable);
    } catch (e, s) {
      // 记录反序列化错误
      Log.error(
          'RustStreamReceiver SubscribeObject deserialize error: ${e.runtimeType}');
      Log.error('Stack trace \n $s');
      // 重新抛出异常，让调用者处理
      rethrow;
    }
  }

  /* 清理资源
   * 
   * 应用关闭时调用，清理所有相关资源：
   * 1. 取消字节流订阅
   * 2. 关闭字节流控制器
   * 3. 关闭事件流控制器
   * 4. 关闭FFI端口
   * 
   * 确保没有内存泄漏和资源占用
   */
  Future<void> dispose() async {
    await _ffiSubscription.cancel();
    await _streamController.close();
    await _observableController.close();
    _ffiPort.close();
  }
}
