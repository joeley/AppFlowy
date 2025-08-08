import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy/plugins/ai_chat/application/chat_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/subject.pb.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

// 本地AI状态回调类型 - 用于通知AI服务状态变化
typedef PluginStateCallback = void Function(LocalAIPB state);
// 资源不足回调类型 - 用于通知资源不足情况
typedef PluginResourceCallback = void Function(LackOfAIResourcePB data);

/// 本地AI状态监听器 - 监听Rust后端发送的AI状态变化通知
/// 
/// 主要功能：
/// 1. 监听本地AI服务状态变化（启动、停止、就绪等）
/// 2. 监听资源状态变化（内存、CPU、磁盘等资源不足）
/// 3. 解析Rust流事件并转换为Dart对象
/// 
/// 设计思想：
/// - 基于Rust流通信机制，实现前后端实时通信
/// - 使用观察者模式，解耦事件发送和处理
/// - 通过回调函数将事件传递给上层BLoC
class LocalAIStateListener {
  LocalAIStateListener() {
    // 创建通知解析器，使用"appflowy_ai_plugin"作为标识符
    // 这个ID必须与后端发送通知时使用的ID一致
    _parser =
        ChatNotificationParser(id: "appflowy_ai_plugin", callback: _callback);
    // 订阅Rust流事件
    _subscription = RustStreamReceiver.listen(
      (observable) => _parser?.parse(observable),
    );
  }

  StreamSubscription<SubscribeObject>? _subscription; // Rust流订阅
  ChatNotificationParser? _parser; // 通知解析器

  PluginStateCallback? stateCallback; // 状态变化回调
  PluginResourceCallback? resourceCallback; // 资源不足回调

  /// 启动监听器
  /// 
  /// 参数：
  /// - [stateCallback]: AI状态变化回调
  /// - [resourceCallback]: 资源不足回调
  void start({
    PluginStateCallback? stateCallback,
    PluginResourceCallback? resourceCallback,
  }) {
    this.stateCallback = stateCallback;
    this.resourceCallback = resourceCallback;
  }

  /// 内部回调函数 - 处理从Rust后端接收到的通知
  /// 
  /// 参数：
  /// - [ty]: 通知类型
  /// - [result]: 通知数据（二进制格式）
  void _callback(
    ChatNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    result.map((r) {
      switch (ty) {
        case ChatNotification.UpdateLocalAIState:
          // 本地AI状态更新通知
          // 将二进制数据解析为LocalAIPB对象并调用回调
          stateCallback?.call(LocalAIPB.fromBuffer(r));
          break;
        case ChatNotification.LocalAIResourceUpdated:
          // 资源不足通知
          // 将二进制数据解析为LackOfAIResourcePB对象并调用回调
          resourceCallback?.call(LackOfAIResourcePB.fromBuffer(r));
          break;
        default:
          // 忽略其他类型的通知
          break;
      }
    });
  }

  /// 停止监听器
  /// 取消Rust流订阅，释放资源
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
