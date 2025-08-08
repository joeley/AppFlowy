import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';

import 'notification_helper.dart';

/* 用户通知来源标识 - 必须与Rust后端的USER_OBSERVABLE_SOURCE值保持一致 */
const String _source = 'User';

/*
 * 用户通知解析器
 * 
 * 专门用于解析用户账户和认证相关的通知事件
 * 
 * 支持的用户通知类型包括:
 * - DidUpdateUserProfile: 用户资料更新通知
 * - DidUpdateUserWorkspace: 用户工作空间更新通知
 * - DidUpdateUserSetting: 用户设置更新通知
 * - DidSignIn: 用户登录通知
 * - DidSignOut: 用户登出通知
 * - DidExpireUserToken: 用户令牌过期通知
 * 
 * 使用场景:
 * - 用户状态变更同步
 * - 认证状态监听
 * - 个人资料实时更新
 * - 权限变更通知
 * - 会话管理
 * 
 * 注意:
 * - 此解析器要求必须提供用户ID作为过滤条件
 * - 只处理与指定用户相关的通知
 * - 用于确保用户数据的安全性和隔离性
 */
class UserNotificationParser
    extends NotificationParser<UserNotification, FlowyError> {
  UserNotificationParser({
    required String super.id, // 必需的用户ID - 确保只处理指定用户的通知
    required super.callback,
  }) : super(
          /* 类型解析器 - 只处理来自User源的通知，根据数值类型返回对应枚举值 */
          tyParser: (ty, source) =>
              source == _source ? UserNotification.valueOf(ty) : null,
          /* 错误解析器 - 将字节数据反序列化为FlowyError对象 */
          errorParser: (bytes) => FlowyError.fromBuffer(bytes),
        );
}
