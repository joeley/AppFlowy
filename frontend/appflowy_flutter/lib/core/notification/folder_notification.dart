import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/protobuf.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'notification_helper.dart';

/* 文件夹通知来源标识 - 必须与Rust后端的FOLDER_OBSERVABLE_SOURCE值保持一致 */
const String _source = 'Workspace';

/*
 * 文件夹通知解析器
 * 
 * 专门用于解析工作空间和文件夹结构相关的通知事件
 * 
 * 支持的文件夹通知类型包括:
 * - DidCreateView: 视图创建通知
 * - DidDeleteView: 视图删除通知  
 * - DidUpdateView: 视图更新通知
 * - DidMoveView: 视图移动通知
 * - DidUpdateWorkspace: 工作空间更新通知
 * 
 * 使用场景:
 * - 文件夹树结构变更同步
 * - 视图层级关系维护
 * - 工作空间状态更新
 */
class FolderNotificationParser
    extends NotificationParser<FolderNotification, FlowyError> {
  FolderNotificationParser({
    super.id,
    required super.callback,
  }) : super(
          /* 类型解析器 - 只处理来自Workspace源的通知 */
          tyParser: (ty, source) =>
              source == _source ? FolderNotification.valueOf(ty) : null,
          /* 错误解析器 - 将字节数据反序列化为FlowyError对象 */
          errorParser: (bytes) => FlowyError.fromBuffer(bytes),
        );
}

/* 文件夹通知处理器类型定义 - 接收通知类型和结果数据的回调函数 */
typedef FolderNotificationHandler = Function(
  FolderNotification ty,
  FlowyResult<Uint8List, FlowyError> result,
);

/*
 * 文件夹通知监听器
 * 
 * 提供便捷的通知监听接口，封装了通知解析器和流订阅的生命周期管理
 * 
 * 工作原理:
 * 1. 创建时自动订阅Rust通知流
 * 2. 使用FolderNotificationParser解析通知
 * 3. 通过handler回调将解析结果传递给业务层
 * 4. 支持优雅关闭和资源清理
 * 
 * 使用模式:
 * ```dart
 * final listener = FolderNotificationListener(
 *   objectId: 'folder_id',
 *   handler: (ty, result) {
 *     // 处理文件夹通知
 *   },
 * );
 * // 使用完毕后需要主动停止
 * await listener.stop();
 * ```
 */
class FolderNotificationListener {
  FolderNotificationListener({
    required String objectId,
    required FolderNotificationHandler handler,
  }) : _parser = FolderNotificationParser(
          id: objectId,
          callback: handler,
        ) {
    // 订阅Rust通知流，自动解析接收到的通知对象
    _subscription =
        RustStreamReceiver.listen((observable) => _parser?.parse(observable));
  }

  /* 通知解析器实例 - 负责解析具体的文件夹通知 */
  FolderNotificationParser? _parser;
  
  /* 流订阅对象 - 用于接收来自Rust后端的通知流 */
  StreamSubscription<SubscribeObject>? _subscription;

  /*
   * 停止监听并清理资源
   * 
   * 执行步骤:
   * 1. 清空解析器引用
   * 2. 取消流订阅
   * 3. 释放相关资源
   */
  Future<void> stop() async {
    _parser = null;
    await _subscription?.cancel();
  }
}
