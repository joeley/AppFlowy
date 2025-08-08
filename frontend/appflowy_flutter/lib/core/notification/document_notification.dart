import 'package:appflowy/core/notification/notification_helper.dart';
import 'package:appflowy_backend/protobuf/flowy-document/notification.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';

/* 文档通知来源标识 - 必须与Rust后端的DOCUMENT_OBSERVABLE_SOURCE值保持一致 */
const String _source = 'Document';

/*
 * 文档通知解析器
 * 
 * 专门用于解析文档相关的通知事件，继承自通用的NotificationParser
 * 
 * 支持的文档通知类型包括:
 * - DidReceiveUpdate: 文档内容更新通知
 * - DidUpdateDocumentAwarenessState: 文档协作状态更新通知
 * 
 * 使用场景:
 * - 文档实时协作编辑
 * - 文档内容变更监听
 * - 协作用户状态同步
 */
class DocumentNotificationParser
    extends NotificationParser<DocumentNotification, FlowyError> {
  DocumentNotificationParser({
    super.id,
    required super.callback,
  }) : super(
          /* 类型解析器 - 只处理来自Document源的通知，根据数值类型返回对应的枚举值 */
          tyParser: (ty, source) =>
              source == _source ? DocumentNotification.valueOf(ty) : null,
          /* 错误解析器 - 将字节数据反序列化为FlowyError对象 */
          errorParser: (bytes) => FlowyError.fromBuffer(bytes),
        );
}
