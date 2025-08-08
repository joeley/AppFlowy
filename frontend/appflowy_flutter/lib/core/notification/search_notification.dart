import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-search/notification.pbenum.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'notification_helper.dart';

/* 搜索通知基础来源标识 - 必须与Rust后端的SEARCH_OBSERVABLE_SOURCE值保持一致 */
const _source = 'Search';

/*
 * 搜索通知解析器
 * 
 * 专门用于解析搜索功能相关的通知事件，支持多通道搜索
 * 
 * 特色功能:
 * - 支持通道(channel)机制，允许多个独立搜索会话
 * - 通过组合源标识和通道名称实现精确匹配
 * 
 * 支持的搜索通知类型包括:
 * - DidUpdateResults: 搜索结果更新通知
 * - DidUpdateSearchState: 搜索状态变更通知
 * - DidCompleteSearch: 搜索完成通知
 * 
 * 使用场景:
 * - 全文搜索结果实时更新
 * - 搜索进度状态同步
 * - 多搜索任务并发管理
 */
class SearchNotificationParser
    extends NotificationParser<SearchNotification, FlowyError> {
  SearchNotificationParser({
    super.id,
    required super.callback,
    String? channel,
  }) : super(
          /* 类型解析器 - 支持通道匹配，格式为"Search{channel}" */
          tyParser: (ty, source) => source == "$_source$channel"
              ? SearchNotification.valueOf(ty)
              : null,
          /* 错误解析器 - 将字节数据反序列化为FlowyError对象 */
          errorParser: (bytes) => FlowyError.fromBuffer(bytes),
        );
}

/* 搜索通知处理器类型定义 - 接收通知类型和结果数据的回调函数 */
typedef SearchNotificationHandler = Function(
  SearchNotification ty,
  FlowyResult<Uint8List, FlowyError> result,
);

/*
 * 搜索通知监听器
 * 
 * 提供搜索通知的便捷监听接口，支持多通道搜索会话管理
 * 
 * 核心特性:
 * - 支持可选的通道参数，实现多搜索会话隔离
 * - 自动处理通知流订阅和解析
 * - 完整的生命周期管理
 * 
 * 通道机制说明:
 * - 通道允许同时进行多个独立的搜索任务
 * - 每个通道有独立的通知流，互不干扰
 * - 通道名称会与基础源标识组合形成完整的源标识符
 * 
 * 使用示例:
 * ```dart
 * // 创建带通道的搜索监听器
 * final listener = SearchNotificationListener(
 *   objectId: 'search_session_1',
 *   channel: 'documents', // 可选通道名
 *   handler: (ty, result) {
 *     switch (ty) {
 *       case SearchNotification.DidUpdateResults:
 *         // 处理搜索结果更新
 *         break;
 *       case SearchNotification.DidCompleteSearch:
 *         // 处理搜索完成
 *         break;
 *     }
 *   },
 * );
 * // 搜索结束后清理资源
 * await listener.stop();
 * ```
 */
class SearchNotificationListener {
  SearchNotificationListener({
    required String objectId,
    required SearchNotificationHandler handler,
    String? channel,
  }) : _parser = SearchNotificationParser(
          id: objectId,
          callback: handler,
          channel: channel,
        ) {
    // 订阅Rust通知流，自动解析接收到的搜索通知
    _subscription =
        RustStreamReceiver.listen((observable) => _parser?.parse(observable));
  }

  /* 流订阅对象 - 用于接收来自Rust后端的通知流 */
  StreamSubscription<SubscribeObject>? _subscription;
  
  /* 搜索通知解析器实例 - 负责解析具体的搜索通知 */
  SearchNotificationParser? _parser;

  /*
   * 停止搜索监听并清理所有资源
   * 
   * 清理步骤:
   * 1. 清空解析器引用，停止通知解析
   * 2. 取消流订阅，断开与后端连接
   * 3. 清空订阅引用，确保内存完全释放
   * 
   * 注意: 停止后该监听器实例不能再次使用
   */
  Future<void> stop() async {
    _parser = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
