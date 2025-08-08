import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy_backend/protobuf/flowy-database2/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/protobuf.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'notification_helper.dart';

/* 数据库通知来源标识 - 必须与Rust后端的DATABASE_OBSERVABLE_SOURCE值保持一致 */
const String _source = 'Database';

/*
 * 数据库通知解析器
 * 
 * 专门用于解析数据库(网格视图)相关的通知事件
 * 
 * 支持的数据库通知类型包括:
 * - DidInsertRow: 行插入通知
 * - DidDeleteRow: 行删除通知
 * - DidUpdateRow: 行更新通知
 * - DidUpdateField: 字段更新通知
 * - DidUpdateCell: 单元格更新通知
 * - DidUpdateDatabase: 数据库配置更新通知
 * - DidUpdateFilter: 过滤器更新通知
 * - DidUpdateSort: 排序规则更新通知
 * 
 * 使用场景:
 * - 表格数据实时同步
 * - 多用户协作编辑
 * - 数据库结构变更通知
 * - 视图配置更新
 */
class DatabaseNotificationParser
    extends NotificationParser<DatabaseNotification, FlowyError> {
  DatabaseNotificationParser({
    super.id,
    required super.callback,
  }) : super(
          /* 类型解析器 - 只处理来自Database源的通知 */
          tyParser: (ty, source) =>
              source == _source ? DatabaseNotification.valueOf(ty) : null,
          /* 错误解析器 - 将字节数据反序列化为FlowyError对象 */
          errorParser: (bytes) => FlowyError.fromBuffer(bytes),
        );
}

/* 数据库通知处理器类型定义 - 接收通知类型和结果数据的回调函数 */
typedef DatabaseNotificationHandler = Function(
  DatabaseNotification ty,
  FlowyResult<Uint8List, FlowyError> result,
);

/*
 * 数据库通知监听器
 * 
 * 提供数据库通知的便捷监听接口，封装通知解析和流管理逻辑
 * 
 * 工作原理:
 * 1. 创建时自动订阅Rust通知流
 * 2. 使用DatabaseNotificationParser解析数据库相关通知
 * 3. 通过handler回调将解析结果传递给业务层
 * 4. 支持完整的生命周期管理和资源清理
 * 
 * 典型使用场景:
 * - 表格视图数据变更监听
 * - 数据库架构变更响应
 * - 实时协作状态同步
 * 
 * 使用示例:
 * ```dart
 * final listener = DatabaseNotificationListener(
 *   objectId: 'database_id',
 *   handler: (ty, result) {
 *     switch (ty) {
 *       case DatabaseNotification.DidInsertRow:
 *         // 处理新增行
 *         break;
 *       case DatabaseNotification.DidUpdateCell:
 *         // 处理单元格更新
 *         break;
 *     }
 *   },
 * );
 * // 不再需要时记得停止监听
 * await listener.stop();
 * ```
 */
class DatabaseNotificationListener {
  DatabaseNotificationListener({
    required String objectId,
    required DatabaseNotificationHandler handler,
  }) : _parser = DatabaseNotificationParser(id: objectId, callback: handler) {
    // 订阅Rust通知流，自动解析接收到的数据库通知
    _subscription =
        RustStreamReceiver.listen((observable) => _parser?.parse(observable));
  }

  /* 数据库通知解析器实例 - 负责解析具体的数据库通知 */
  DatabaseNotificationParser? _parser;
  
  /* 流订阅对象 - 用于接收来自Rust后端的通知流 */
  StreamSubscription<SubscribeObject>? _subscription;

  /*
   * 停止监听并完全清理资源
   * 
   * 执行步骤:
   * 1. 清空解析器引用，停止通知处理
   * 2. 取消流订阅，断开与Rust后端的连接
   * 3. 清空订阅引用，确保资源完全释放
   */
  Future<void> stop() async {
    _parser = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
