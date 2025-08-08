/*
 * 数据库设置监听器
 * 
 * 设计理念：
 * 监听后端的数据库设置变化事件，实时更新UI。
 * 当设置发生变化时（如过滤器、排序规则等），
 * 通过监听器通知前端进行相应更新。
 * 
 * 使用场景：
 * - 协作编辑时同步其他用户的设置变化
 * - 实时更新视图配置
 * - 保持多个视图的设置同步
 */

import 'dart:typed_data';

import 'package:appflowy/core/notification/grid_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/setting_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flowy_infra/notifier.dart';

/// 设置更新通知值类型
/// 封装设置变化或错误信息
typedef UpdateSettingNotifiedValue
    = FlowyResult<DatabaseViewSettingPB, FlowyError>;

/*
 * 数据库设置监听器
 * 
 * 职责：
 * 1. 监听指定视图的设置变化事件
 * 2. 解析通知数据并转换为设置对象
 * 3. 管理通知的订阅和取消
 * 
 * 生命周期：
 * start() -> 监听事件 -> stop() 停止监听
 */
class DatabaseSettingListener {
  DatabaseSettingListener({required this.viewId});

  final String viewId;

  DatabaseNotificationListener? _listener;  // 数据库通知监听器
  PublishNotifier<UpdateSettingNotifiedValue>? _updateSettingNotifier =
      PublishNotifier();  // 设置更新通知发布器

  /*
   * 启动监听器
   * 
   * 参数：
   * - onSettingUpdated：设置更新回调函数
   * 
   * 工作流程：
   * 1. 添加回调函数到通知发布器
   * 2. 创建并启动数据库通知监听器
   */
  void start({
    required void Function(UpdateSettingNotifiedValue) onSettingUpdated,
  }) {
    // 添加监听器
    _updateSettingNotifier?.addPublishListener(onSettingUpdated);
    // 创建通知监听器
    _listener =
        DatabaseNotificationListener(objectId: viewId, handler: _handler);
  }

  /*
   * 事件处理函数（内部方法）
   * 
   * 参数：
   * - ty：通知类型
   * - result：通知数据（二进制）或错误
   * 
   * 处理逻辑：
   * 只处理设置更新事件，
   * 将二进制数据解析为 DatabaseViewSettingPB。
   */
  void _handler(
    DatabaseNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case DatabaseNotification.DidUpdateSettings:
        // 处理设置更新通知
        result.fold(
          // 成功：解析二进制数据为设置对象
          (payload) => _updateSettingNotifier?.value = FlowyResult.success(
            DatabaseViewSettingPB.fromBuffer(payload),
          ),
          // 失败：转发错误
          (error) => _updateSettingNotifier?.value = FlowyResult.failure(error),
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
   * 1. 停止数据库通知监听
   * 2. 释放通知发布器资源
   * 3. 置空引用，避免内存泄漏
   */
  Future<void> stop() async {
    await _listener?.stop();          // 停止监听
    _updateSettingNotifier?.dispose(); // 释放发布器
    _updateSettingNotifier = null;     // 清空引用
  }
}
