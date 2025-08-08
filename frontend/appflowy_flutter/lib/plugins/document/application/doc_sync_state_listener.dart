import 'dart:async';
import 'dart:typed_data';

// 文档通知系统
import 'package:appflowy/core/notification/document_notification.dart';
// 文档相关Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-document/protobuf.dart';
// 错误处理相关定义
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
// 通知订阅对象定义
import 'package:appflowy_backend/protobuf/flowy-notification/subject.pb.dart';
// Rust流接收器
import 'package:appflowy_backend/rust_stream.dart';
// 结果包装器
import 'package:appflowy_result/appflowy_result.dart';

/* 文档同步状态回调函数类型定义
 * 
 * 当接收到新的同步状态时调用
 * 参数：syncState - 新的文档同步状态
 */
typedef DocumentSyncStateCallback = void Function(
  DocumentSyncStatePB syncState,
);

/* 文档同步状态监听器
 * 
 * 专门监听单个文档的同步状态变化的组件
 * 
 * 核心功能：
 * 1. 监听来自Rust后端的文档同步状态通知
 * 2. 解析同步状态消息
 * 3. 通过回调函数通知上层组件
 * 4. 管理监听生命周期
 * 
 * 同步状态类型：
 * - Syncing: 正在同步中
 * - Synchronized: 已同步完成
 * - SyncFailed: 同步失败
 * - Offline: 离线状态
 * 
 * 工作原理：
 * 1. 订阅全局的Rust事件流
 * 2. 过滤出与当前文档相关的通知
 * 3. 解析同步状态数据
 * 4. 调用回调函数通知状态变化
 * 
 * 生命周期管理：
 * - start(): 开始监听
 * - stop(): 停止监听并清理资源
 * - 自动过滤非本文档的通知
 */
class DocumentSyncStateListener {
  DocumentSyncStateListener({
    required this.id,
  });

  // 文档ID，用于过滤相关通知
  final String id;
  
  // Rust流订阅，接收通知事件
  StreamSubscription<SubscribeObject>? _subscription;
  
  // 文档通知解析器，解析特定文档的通知
  DocumentNotificationParser? _parser;
  
  // 同步状态变化回调函数
  DocumentSyncStateCallback? didReceiveSyncState;

  /* 开始监听文档同步状态
   * 
   * 启动监听器并设置回调函数
   * 
   * 参数：
   * - didReceiveSyncState: 同步状态变化回调函数
   * 
   * 执行步骤：
   * 1. 保存回调函数引用
   * 2. 创建文档通知解析器
   * 3. 订阅全局Rust事件流
   * 4. 开始过滤和处理相关通知
   */
  void start({
    DocumentSyncStateCallback? didReceiveSyncState,
  }) {
    // 保存回调函数
    this.didReceiveSyncState = didReceiveSyncState;

    // 创建专门解析当前文档通知的解析器
    _parser = DocumentNotificationParser(
      id: id,  // 文档ID，用于过滤通知
      callback: _callback,  // 内部回调处理函数
    );
    
    // 订阅全局Rust事件流
    // 所有来自Rust后端的通知都会通过这个流发送
    _subscription = RustStreamReceiver.listen(
      (observable) => _parser?.parse(observable),
    );
  }

  /* 内部通知回调处理函数
   * 
   * 处理解析器传递过来的文档通知
   * 
   * 参数：
   * - ty: 文档通知类型
   * - result: 通知数据结果（成功时包含数据，失败时包含错误）
   * 
   * 处理逻辑：
   * - 只处理文档同步状态更新通知
   * - 解析Protocol Buffer数据
   * - 调用上层回调函数
   */
  void _callback(
    DocumentNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case DocumentNotification.DidUpdateDocumentSyncState:
        // 处理文档同步状态更新通知
        result.map(
          (r) {
            // 从字节数据解析同步状态对象
            final value = DocumentSyncStatePB.fromBuffer(r);
            // 通知上层组件状态变化
            didReceiveSyncState?.call(value);
          },
        );
        break;
      default:
        // 忽略其他类型的通知
        break;
    }
  }

  /* 停止监听并清理资源
   * 
   * 当不再需要监听时调用，确保资源正确释放
   * 
   * 清理操作：
   * 1. 取消Rust事件流订阅
   * 2. 清空订阅引用
   * 3. 解析器会自动清理
   * 
   * 重要性：
   * - 防止内存泄漏
   * - 避免接收不需要的通知
   * - 确保监听器完全停止
   */
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
