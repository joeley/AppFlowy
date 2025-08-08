/*
 * 数据库计算功能监听器
 * 
 * 设计理念：
 * 监听后端的计算变化事件，实时更新UI显示。
 * 当数据变化导致计算结果更新时，通过监听器通知前端。
 * 
 * 工作流程：
 * 1. 数据变化 -> 后端重新计算
 * 2. 后端发送通知 -> 监听器接收
 * 3. 解析通知内容 -> 更新UI
 * 
 * 使用场景：
 * - 实时更新表格底部的统计信息
 * - 协作编辑时同步其他用户的计算变化
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy/core/notification/grid_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flowy_infra/notifier.dart';

/// 计算更新值类型别名
/// 封装计算变化通知或错误信息
typedef UpdateCalculationValue
    = FlowyResult<CalculationChangesetNotificationPB, FlowyError>;

/*
 * 计算功能监听器
 * 
 * 职责：
 * 1. 监听指定视图的计算变化事件
 * 2. 解析通知数据并转换为适合UI使用的格式
 * 3. 管理通知的订阅和取消
 * 
 * 生命周期：
 * start() -> 监听事件 -> stop() 停止监听
 */
class CalculationsListener {
  CalculationsListener({required this.viewId});

  final String viewId;

  /// 计算通知发布器，用于向订阅者广播变化
  PublishNotifier<UpdateCalculationValue>? _calculationNotifier =
      PublishNotifier();
  /// 数据库通知监听器，用于接收后端事件
  DatabaseNotificationListener? _listener;

  /*
   * 启动监听器
   * 
   * 参数：
   * - onCalculationChanged：计算变化回调函数
   * 
   * 工作流程：
   * 1. 添加回调函数到通知发布器
   * 2. 创建数据库通知监听器
   * 3. 开始监听指定视图的事件
   */
  void start({
    required void Function(UpdateCalculationValue) onCalculationChanged,
  }) {
    // 添加监听器到通知发布器
    _calculationNotifier?.addPublishListener(onCalculationChanged);
    // 创建并配置数据库通知监听器
    _listener = DatabaseNotificationListener(
      objectId: viewId,  // 监听指定视图的事件
      handler: _handler, // 事件处理函数
    );
  }

  /*
   * 事件处理函数（内部方法）
   * 
   * 参数：
   * - ty：通知类型
   * - result：通知数据（二进制）或错误
   * 
   * 处理逻辑：
   * 1. 检查通知类型是否为计算更新
   * 2. 解析二进制数据为 CalculationChangesetNotificationPB
   * 3. 向订阅者广播解析后的数据
   */
  void _handler(
    DatabaseNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case DatabaseNotification.DidUpdateCalculation:
        // 处理计算更新通知
        _calculationNotifier?.value = result.fold(
          // 成功：解析二进制数据为计算变化通知对象
          (payload) => FlowyResult.success(
            CalculationChangesetNotificationPB.fromBuffer(payload),
          ),
          // 失败：直接转发错误
          (err) => FlowyResult.failure(err),
        );
      default:
        // 忽略其他类型的通知
        break;
    }
  }

  /*
   * 停止监听器
   * 
   * 清理步骤：
   * 1. 停止数据库通知监听
   * 2. 释放通知发布器资源
   * 3. 置空引用，避免内存泄漏
   */
  Future<void> stop() async {
    // 停止监听后端事件
    await _listener?.stop();
    // 释放通知发布器
    _calculationNotifier?.dispose();
    // 清空引用
    _calculationNotifier = null;
  }
}
