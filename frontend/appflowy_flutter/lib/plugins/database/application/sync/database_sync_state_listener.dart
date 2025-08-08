/*
 * 数据库同步状态监听器
 * 
 * 设计理念：
 * 监听后端的数据库同步状态变化，实时更新UI。
 * 使用 Rust 流来接收后端的实时事件。
 * 
 * 重要说明：
 * databaseId 是数据库的ID，不是视图的ID。
 * 一个数据库可以有多个视图（表格、看板、日历等）。
 * 
 * 同步状态：
 * - Syncing：正在同步
 * - Synced：已同步
 * - SyncFailed：同步失败
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy/core/notification/grid_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/subject.pb.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

/// 数据库同步状态回调类型
typedef DatabaseSyncStateCallback = void Function(
  DatabaseSyncStatePB syncState,
);

/*
 * 数据库同步状态监听器
 * 
 * 职责：
 * 1. 监听指定数据库的同步状态
 * 2. 解析 Rust 流中的同步事件
 * 3. 通知监听者同步状态变化
 * 
 * 生命周期：
 * start() -> 监听事件 -> stop() 停止监听
 */
class DatabaseSyncStateListener {
  DatabaseSyncStateListener({
    // 注意：这里是数据库ID，不是视图ID
    // 一个数据库可以对应多个视图
    required this.databaseId,
  });

  final String databaseId;  // 数据库ID
  StreamSubscription<SubscribeObject>? _subscription;  // Rust 流订阅
  DatabaseNotificationParser? _parser;  // 通知解析器

  DatabaseSyncStateCallback? didReceiveSyncState;  // 同步状态回调

  /*
   * 启动监听器
   * 
   * 参数：
   * - didReceiveSyncState：同步状态变化回调
   * 
   * 工作流程：
   * 1. 保存回调函数
   * 2. 创建通知解析器
   * 3. 订阅 Rust 流事件
   */
  void start({
    DatabaseSyncStateCallback? didReceiveSyncState,
  }) {
    // 保存回调函数
    this.didReceiveSyncState = didReceiveSyncState;

    // 创建数据库通知解析器
    _parser = DatabaseNotificationParser(
      id: databaseId,      // 监听指定数据库
      callback: _callback, // 事件处理回调
    );
    // 订阅 Rust 流，监听后端事件
    _subscription = RustStreamReceiver.listen(
      (observable) => _parser?.parse(observable),
    );
  }

  /*
   * 事件处理回调（内部方法）
   * 
   * 参数：
   * - ty：通知类型
   * - result：通知数据（二进制）或错误
   * 
   * 处理逻辑：
   * 只处理数据库同步更新事件，
   * 将二进制数据解析为 DatabaseSyncStatePB。
   */
  void _callback(
    DatabaseNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case DatabaseNotification.DidUpdateDatabaseSyncUpdate:
        // 处理数据库同步更新通知
        result.map(
          (r) {
            // 解析二进制数据为同步状态对象
            final value = DatabaseSyncStatePB.fromBuffer(r);
            // 触发回调，通知同步状态变化
            didReceiveSyncState?.call(value);
          },
        );
        break;
      default:
        // 忽略其他类型的通知
        break;
    }
  }

  /*
   * 停止监听器
   * 
   * 清理步骤：
   * 1. 取消 Rust 流订阅
   * 2. 置空引用，避免内存泄漏
   */
  Future<void> stop() async {
    await _subscription?.cancel();  // 取消订阅
    _subscription = null;            // 清空引用
  }
}
