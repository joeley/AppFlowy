/*
 * 文档监听器
 * 
 * 设计理念：
 * 监听文档的实时变化事件，包括内容更新和协作状态。
 * 通过Rust流接收后端推送的事件，实现实时同步。
 * 
 * 核心功能：
 * 1. 监听文档内容变化
 * 2. 监听协作者状态变化
 * 3. 事件解析和分发
 * 4. 生命周期管理
 * 
 * 事件类型：
 * - DidReceiveUpdate：文档内容更新
 * - DidUpdateDocumentAwarenessState：协作状态更新
 * 
 * 使用场景：
 * - 实时协作编辑
 * - 自动保存触发
 * - 冲突检测
 * - 协作者在线状态
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy/core/notification/document_notification.dart';
import 'package:appflowy_backend/protobuf/flowy-document/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-notification/subject.pb.dart';
import 'package:appflowy_backend/rust_stream.dart';
import 'package:appflowy_result/appflowy_result.dart';

/* 文档事件更新回调类型 */
typedef OnDocumentEventUpdate = void Function(DocEventPB docEvent);

/* 文档协作状态更新回调类型 */
typedef OnDocumentAwarenessStateUpdate = void Function(
  DocumentAwarenessStatesPB awarenessStates,
);

/*
 * 文档监听器类
 * 
 * 职责：
 * 1. 订阅文档相关事件
 * 2. 解析事件数据
 * 3. 调用对应回调
 * 4. 管理订阅生命周期
 */
class DocumentListener {
  DocumentListener({
    required this.id,
  });

  final String id;  /* 文档ID */

  StreamSubscription<SubscribeObject>? _subscription;  /* Rust流订阅 */
  DocumentNotificationParser? _parser;  /* 通知解析器 */

  OnDocumentEventUpdate? _onDocEventUpdate;  /* 文档更新回调 */
  OnDocumentAwarenessStateUpdate? _onDocAwarenessUpdate;  /* 协作状态回调 */

  /*
   * 启动监听
   * 
   * 功能：
   * 开始监听文档事件，设置回调函数。
   * 
   * 参数：
   * - onDocEventUpdate：文档内容更新回调
   * - onDocAwarenessUpdate：协作状态更新回调
   * 
   * 处理流程：
   * 1. 保存回调函数
   * 2. 创建通知解析器
   * 3. 订阅Rust流事件
   */
  void start({
    OnDocumentEventUpdate? onDocEventUpdate,
    OnDocumentAwarenessStateUpdate? onDocAwarenessUpdate,
  }) {
    /* 保存回调函数 */
    _onDocEventUpdate = onDocEventUpdate;
    _onDocAwarenessUpdate = onDocAwarenessUpdate;

    /* 创建解析器，绑定文档ID和回调 */
    _parser = DocumentNotificationParser(
      id: id,
      callback: _callback,
    );
    
    /* 订阅Rust流事件 */
    _subscription = RustStreamReceiver.listen(
      (observable) => _parser?.parse(observable),
    );
  }

  /*
   * 事件回调处理
   * 
   * 功能：
   * 根据事件类型分发到对应的处理函数。
   * 
   * 参数：
   * - ty：通知类型
   * - result：事件数据（二进制）
   * 
   * 处理逻辑：
   * 1. DidReceiveUpdate：解析为DocEventPB并调用更新回调
   * 2. DidUpdateDocumentAwarenessState：解析为DocumentAwarenessStatesPB并调用协作回调
   * 3. 其他：忽略
   */
  void _callback(
    DocumentNotification ty,
    FlowyResult<Uint8List, FlowyError> result,
  ) {
    switch (ty) {
      case DocumentNotification.DidReceiveUpdate:
        /* 处理文档内容更新 */
        result.map(
          (s) => _onDocEventUpdate?.call(DocEventPB.fromBuffer(s)),
        );
        break;
      case DocumentNotification.DidUpdateDocumentAwarenessState:
        /* 处理协作状态更新 */
        result.map(
          (s) => _onDocAwarenessUpdate?.call(
            DocumentAwarenessStatesPB.fromBuffer(s),
          ),
        );
        break;
      default:
        break;
    }
  }

  /*
   * 停止监听
   * 
   * 功能：
   * 停止监听文档事件，清理资源。
   * 
   * 清理内容：
   * 1. 清空回调函数
   * 2. 取消流订阅
   * 3. 释放引用
   * 
   * 使用时机：
   * - 文档关闭时
   * - 切换文档时
   * - 组件销毁时
   */
  Future<void> stop() async {
    /* 清空回调 */
    _onDocAwarenessUpdate = null;
    _onDocEventUpdate = null;
    /* 取消订阅 */
    await _subscription?.cancel();
    _subscription = null;
  }
}
