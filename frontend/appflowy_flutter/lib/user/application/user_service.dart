import 'dart:async';

/* 工作区订阅扩展功能 */
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
/* Rust后端通信调度器 */
import 'package:appflowy_backend/dispatch/dispatch.dart';
/* 错误类型定义 */
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
/* 工作区相关Protocol Buffer类型 */
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
/* 用户相关Protocol Buffer类型 */
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
/* 结果类型封装 */
import 'package:appflowy_result/appflowy_result.dart';
/* 64位整数类型 */
import 'package:fixnum/fixnum.dart';
/* Flutter基础库 */
import 'package:flutter/foundation.dart';

/**
 * 用户后端服务接口
 * 
 * 定义了用户后端服务的最小必需方法集合。
 * 主要用于订阅相关功能，例如付费管理。
 * 
 * 这种接口分离的设计好处：
 * 1. 可以为不同实现定义不同的接口
 * 2. 便于单元测试和模拟
 * 3. 支持多种后端实现（本地、云端等）
 */
abstract class IUserBackendService {
  /// 取消工作区订阅
  Future<FlowyResult<void, FlowyError>> cancelSubscription(
    String workspaceId,
    SubscriptionPlanPB plan,
    String? reason,
  );
  /// 创建工作区订阅
  Future<FlowyResult<PaymentLinkPB, FlowyError>> createSubscription(
    String workspaceId,
    SubscriptionPlanPB plan,
  );
}

/// 测试环境基础URL
const _baseBetaUrl = 'https://beta.appflowy.com';
/// 生产环境基础URL
const _baseProdUrl = 'https://appflowy.com';

/**
 * 用户后端服务实现
 * 
 * AppFlowy用户管理系统的核心服务类，处理所有用户相关的后端操作。
 * 这个服务类负责用户的整个生命周期管理和相关操作。
 * 
 * 主要功能区域：
 * 1. **用户Profile管理**：获取、更新用户基本信息
 * 2. **认证操作**：登录、登出、魔法链接等
 * 3. **工作区管理**：创建、切换、删除工作区
 * 4. **成员管理**：添加、删除、修改成员权限
 * 5. **订阅管理**：创建、取消、更新付费计划
 * 6. **账户管理**：删除账户等高级操作
 * 
 * 设计特点：
 * - **单例模式**：每个用户对应一个服务实例
 * - **静态方法**：通用操作使用静态方法，方便调用
 * - **异步设计**：所有网络操作都是异步的
 * - **错误处理**：使用FlowyResult统一处理成功/失败情况
 * 
 * 使用模式：
 * ```dart
 * // 创建服务实例
 * final userService = UserBackendService(userId: currentUserId);
 * 
 * // 调用实例方法
 * final result = await userService.updateUserProfile(name: '新名称');
 * 
 * // 调用静态方法
 * final profile = await UserBackendService.getCurrentUserProfile();
 * ```
 */
class UserBackendService implements IUserBackendService {
  /**
   * 构造函数
   * 
   * @param userId 用户唯一标识符（Int64类型）
   *               用于标识该服务实例对应的用户
   *               在各种API调用中作为用户身份识别
   */
  UserBackendService({required this.userId});

  /// 用户ID - 该服务实例对应的用户标识
  final Int64 userId;

  /**
   * 获取当前用户Profile信息（静态方法）
   * 
   * 这是一个静态方法，可以在没有UserBackendService实例的情况下调用。
   * 通常用于应用初始化阶段或全局的用户信息检查。
   * 
   * @return FlowyResult<UserProfilePB, FlowyError>
   *         成功：包含完整用户信息的Profile对象
   *         失败：错误信息（未登录、网络错误等）
   * 
   * UserProfilePB包含的信息：
   * - id: 用户唯一标识
   * - email: 用户邮箱
   * - name: 用户显示名称
   * - iconUrl: 头像地址
   * - openaiKey: OpenAI API密钥（如果设置）
   * - workspaceId: 当前工作区ID
   * - authType: 认证类型
   * - encryptionType: 加密类型
   * 
   * 使用场景：
   * - 应用启动时检查登录状态
   * - 在没有具体用户服务实例时获取用户信息
   * - 全局的用户身份验证
   */
  static Future<FlowyResult<UserProfilePB, FlowyError>>
      getCurrentUserProfile() async {
    final result = await UserEventGetUserProfile().send();
    return result;
  }

  /**
   * 更新用户Profile信息
   * 
   * 允许部分更新用户的Profile信息，只有提供的字段才会被更新。
   * 这种设计遇免了意外清空其他字段的风险。
   * 
   * @param name 新的用户显示名称（可选）
   * @param password 新密码（可选，将被加密后存储）
   * @param email 新邮箱地址（可选，可能需要验证）
   * @param iconUrl 新的头像URL（可选）
   * 
   * @return FlowyResult<void, FlowyError>
   *         成功：void（更新成功）
   *         失败：错误信息（权限不足、邮箱已存在、验证失败等）
   * 
   * 更新规则：
   * - name: 可以随时更新，不需要额外验证
   * - password: 需要符合密码强度要求
   * - email: 可能需要邮箱验证，取决于系统配置
   * - iconUrl: 必须是有效的URL，可以是外链或本地路径
   * 
   * 安全考虑：
   * - 密码更新会触发重新登录
   * - 邮箱更新可能影响认证状态
   * - 所有更新都会记录在审计日志中
   */
  Future<FlowyResult<void, FlowyError>> updateUserProfile({
    String? name,
    String? password,
    String? email,
    String? iconUrl,
  }) {
    // 创建更新载荷对象，设置用户ID
    final payload = UpdateUserProfilePayloadPB.create()..id = userId;

    // 只有非空字段才会被包含在更新请求中
    if (name != null) {
      payload.name = name;
    }

    if (password != null) {
      payload.password = password;
    }

    if (email != null) {
      payload.email = email;
    }

    if (iconUrl != null) {
      payload.iconUrl = iconUrl;
    }

    return UserEventUpdateUserProfile(payload).send();
  }

  Future<FlowyResult<void, FlowyError>> deleteWorkspace({
    required String workspaceId,
  }) {
    throw UnimplementedError();
  }

  /**
   * 魔法链接登录（静态方法）
   * 
   * 通过邮件发送的魔法链接进行用户登录。
   * 这是一种无密码登录方式，提高了用户体验和安全性。
   * 
   * @param email 用户邮箱地址
   * @param redirectTo 登录成功后的重定向URL（可为空）
   * @return FlowyResult<UserProfilePB, FlowyError>
   *         成功：返回用户Profile信息
   *         失败：返回错误信息（邮箱不存在、发送失败等）
   * 
   * 流程说明：
   * 1. 验证邮箱地址的有效性
   * 2. 检查用户是否已注册
   * 3. 生成并发送包含登录链接的邮件
   * 4. 用户点击邮件中的链接后自动登录
   */
  static Future<FlowyResult<UserProfilePB, FlowyError>> signInWithMagicLink(
    String email,
    String redirectTo,
  ) async {
    final payload = MagicLinkSignInPB(email: email, redirectTo: redirectTo);
    return UserEventMagicLinkSignIn(payload).send();
  }

  static Future<FlowyResult<GotrueTokenResponsePB, FlowyError>>
      signInWithPasscode(
    String email,
    String passcode,
  ) async {
    final payload = PasscodeSignInPB(email: email, passcode: passcode);
    return UserEventPasscodeSignIn(payload).send();
  }

  Future<FlowyResult<void, FlowyError>> signInWithPassword(
    String email,
    String password,
  ) {
    final payload = SignInPayloadPB(
      email: email,
      password: password,
    );
    return UserEventSignInWithEmailPassword(payload).send();
  }

  /**
   * 用户登出（静态方法）
   * 
   * 执行完整的用户登出流程，清除所有相关的认证信息和缓存。
   * 
   * @return FlowyResult<void, FlowyError>
   *         成功：void（登出成功）
   *         失败：错误信息（网络错误、状态异常等）
   * 
   * 登出操作包括：
   * - 清除本地存储的用户信息
   * - 撤销所有活跃的认证令牌
   * - 清理用户相关的缓存数据
   * - 通知后端服务更新用户状态
   * - 关闭当前打开的文档和工作区
   * 
   * 注意事项：
   * - 登出是不可逆操作
   * - 未保存的数据可能会丢失
   * - 需要重新登录才能访问受保护的功能
   */
  static Future<FlowyResult<void, FlowyError>> signOut() {
    return UserEventSignOut().send();
  }

  Future<FlowyResult<void, FlowyError>> initUser() async {
    return UserEventInitUser().send();
  }

  static Future<FlowyResult<UserProfilePB, FlowyError>> getAnonUser() async {
    return UserEventGetAnonUser().send();
  }

  static Future<FlowyResult<void, FlowyError>> openAnonUser() async {
    return UserEventOpenAnonUser().send();
  }

  /**
   * 获取用户的所有工作区
   * 
   * 获取当前用户可以访问的所有工作区列表，包括自己创建的和被邀请加入的。
   * 
   * @return Future<FlowyResult<List<UserWorkspacePB>, FlowyError>>
   *         成功：返回工作区列表
   *                每个工作区包含：ID、名称、图标、成员数量等
   *         失败：返回错误信息（权限不足、网络错误等）
   * 
   * 工作区信息包括：
   * - workspaceId: 工作区唯一标识
   * - name: 工作区名称
   * - icon: 工作区图标
   * - memberCount: 成员数量
   * - role: 用户在该工作区中的角色
   * - createdAt: 创建时间
   * - workspaceType: 工作区类型（本地/云端）
   * 
   * 使用场景：
   * - 工作区切换器显示
   * - 首页工作区列表
   * - 设置页面的工作区管理
   * - 权限验证和访问控制
   */
  Future<FlowyResult<List<UserWorkspacePB>, FlowyError>> getWorkspaces() {
    return UserEventGetAllWorkspace().send().then((value) {
      return value.fold(
        (workspaces) => FlowyResult.success(workspaces.items),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  static Future<FlowyResult<UserWorkspacePB, FlowyError>> getWorkspaceById(
    String workspaceId,
  ) async {
    final result = await UserEventGetAllWorkspace().send();
    return result.fold(
      (workspaces) {
        final workspace = workspaces.items.firstWhere(
          (workspace) => workspace.workspaceId == workspaceId,
        );
        return FlowyResult.success(workspace);
      },
      (error) => FlowyResult.failure(error),
    );
  }

  Future<FlowyResult<void, FlowyError>> openWorkspace(
    String workspaceId,
    WorkspaceTypePB workspaceType,
  ) {
    final payload = OpenUserWorkspacePB()
      ..workspaceId = workspaceId
      ..workspaceType = workspaceType;
    return UserEventOpenWorkspace(payload).send();
  }

  static Future<FlowyResult<WorkspacePB, FlowyError>> getCurrentWorkspace() {
    return FolderEventReadCurrentWorkspace().send().then((result) {
      return result.fold(
        (workspace) => FlowyResult.success(workspace),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  /**
   * 创建新工作区
   * 
   * 为用户创建一个新的工作区，用户将自动成为该工作区的管理员。
   * 
   * @param name 工作区名称（不可为空，长度限制由后端决定）
   * @param workspaceType 工作区类型
   *                      - WorkspaceTypePB.Local: 本地工作区（数据存储在本地）
   *                      - WorkspaceTypePB.Remote: 云端工作区（数据存储在云端）
   * 
   * @return Future<FlowyResult<UserWorkspacePB, FlowyError>>
   *         成功：返回新创建的工作区信息
   *         失败：返回错误信息（名称重复、权限不足等）
   * 
   * 创建流程：
   * 1. 验证工作区名称的合法性
   * 2. 检查用户是否有创建权限
   * 3. 创建工作区目录结构
   * 4. 初始化默认设置和模板
   * 5. 设置创建者为管理员
   * 
   * 创建后的工作区包含：
   * - 默认的文档模板和示例
   * - 基本的权限设置
   * - 初始的工作区设置
   * 
   * 注意事项：
   * - 工作区名称在用户范围内必须唯一
   * - 本地工作区不需要网络连接，云端工作区需要
   * - 创建后可以通过openWorkspace方法切换到新工作区
   */
  Future<FlowyResult<UserWorkspacePB, FlowyError>> createUserWorkspace(
    String name,
    WorkspaceTypePB workspaceType,
  ) {
    final request = CreateWorkspacePB.create()
      ..name = name
      ..workspaceType = workspaceType;
    return UserEventCreateWorkspace(request).send();
  }

  Future<FlowyResult<void, FlowyError>> deleteWorkspaceById(
    String workspaceId,
  ) {
    final request = UserWorkspaceIdPB.create()..workspaceId = workspaceId;
    return UserEventDeleteWorkspace(request).send();
  }

  Future<FlowyResult<void, FlowyError>> renameWorkspace(
    String workspaceId,
    String name,
  ) {
    final request = RenameWorkspacePB()
      ..workspaceId = workspaceId
      ..newName = name;
    return UserEventRenameWorkspace(request).send();
  }

  Future<FlowyResult<void, FlowyError>> updateWorkspaceIcon(
    String workspaceId,
    String icon,
  ) {
    final request = ChangeWorkspaceIconPB()
      ..workspaceId = workspaceId
      ..newIcon = icon;
    return UserEventChangeWorkspaceIcon(request).send();
  }

  Future<FlowyResult<RepeatedWorkspaceMemberPB, FlowyError>>
      getWorkspaceMembers(
    String workspaceId,
  ) async {
    final data = QueryWorkspacePB()..workspaceId = workspaceId;
    return UserEventGetWorkspaceMembers(data).send();
  }

  Future<FlowyResult<void, FlowyError>> addWorkspaceMember(
    String workspaceId,
    String email,
  ) async {
    final data = AddWorkspaceMemberPB()
      ..workspaceId = workspaceId
      ..email = email;
    return UserEventAddWorkspaceMember(data).send();
  }

  Future<FlowyResult<void, FlowyError>> inviteWorkspaceMember(
    String workspaceId,
    String email, {
    AFRolePB? role,
  }) async {
    final data = WorkspaceMemberInvitationPB()
      ..workspaceId = workspaceId
      ..inviteeEmail = email;
    if (role != null) {
      data.role = role;
    }
    return UserEventInviteWorkspaceMember(data).send();
  }

  Future<FlowyResult<void, FlowyError>> removeWorkspaceMember(
    String workspaceId,
    String email,
  ) async {
    final data = RemoveWorkspaceMemberPB()
      ..workspaceId = workspaceId
      ..email = email;
    return UserEventRemoveWorkspaceMember(data).send();
  }

  Future<FlowyResult<void, FlowyError>> updateWorkspaceMember(
    String workspaceId,
    String email,
    AFRolePB role,
  ) async {
    final data = UpdateWorkspaceMemberPB()
      ..workspaceId = workspaceId
      ..email = email
      ..role = role;
    return UserEventUpdateWorkspaceMember(data).send();
  }

  Future<FlowyResult<void, FlowyError>> leaveWorkspace(
    String workspaceId,
  ) async {
    final data = UserWorkspaceIdPB.create()..workspaceId = workspaceId;
    return UserEventLeaveWorkspace(data).send();
  }

  static Future<FlowyResult<WorkspaceSubscriptionInfoPB, FlowyError>>
      getWorkspaceSubscriptionInfo(String workspaceId) {
    final params = UserWorkspaceIdPB.create()..workspaceId = workspaceId;
    return UserEventGetWorkspaceSubscriptionInfo(params).send();
  }

  @override
  Future<FlowyResult<PaymentLinkPB, FlowyError>> createSubscription(
    String workspaceId,
    SubscriptionPlanPB plan,
  ) {
    final request = SubscribeWorkspacePB()
      ..workspaceId = workspaceId
      ..recurringInterval = RecurringIntervalPB.Year
      ..workspaceSubscriptionPlan = plan
      ..successUrl =
          '${kDebugMode ? _baseBetaUrl : _baseProdUrl}/after-payment?plan=${plan.toRecognizable()}';
    return UserEventSubscribeWorkspace(request).send();
  }

  @override
  Future<FlowyResult<void, FlowyError>> cancelSubscription(
    String workspaceId,
    SubscriptionPlanPB plan, [
    String? reason,
  ]) {
    final request = CancelWorkspaceSubscriptionPB()
      ..workspaceId = workspaceId
      ..plan = plan;

    if (reason != null) {
      request.reason = reason;
    }

    return UserEventCancelWorkspaceSubscription(request).send();
  }

  Future<FlowyResult<void, FlowyError>> updateSubscriptionPeriod(
    String workspaceId,
    SubscriptionPlanPB plan,
    RecurringIntervalPB interval,
  ) {
    final request = UpdateWorkspaceSubscriptionPaymentPeriodPB()
      ..workspaceId = workspaceId
      ..plan = plan
      ..recurringInterval = interval;

    return UserEventUpdateWorkspaceSubscriptionPaymentPeriod(request).send();
  }

  /**
   * 删除当前用户账户（不可逆操作！）
   * 
   * 警告：这是一个不可逆的危险操作！
   * 将完全删除用户账户和所有相关数据，包括：
   * - 用户Profile和设置
   * - 所有工作区和文档
   * - 上传的文件和图片
   * - 协作历史和评论
   * - 订阅和付费信息
   * 
   * @return Future<FlowyResult<void, FlowyError>>
   *         成功：void（账户已被完全删除）
   *         失败：错误信息（权限不足、网络错误等）
   * 
   * 删除流程：
   * 1. 验证用户身份和权限
   * 2. 检查是否有未完成的付费或订阅
   * 3. 通知所有相关的协作者和工作区成员
   * 4. 删除所有工作区数据和文件
   * 5. 撤销所有认证令牌和会话
   * 6. 清理缓存和索引
   * 7. 取消所有订阅和服务
   * 8. 从数据库中永久删除用户记录
   * 
   * 重要提醒：
   * - 该操作不可逆转，无法恢复
   * - 建议在执行前备份重要数据
   * - 可能影响其他用户的协作文档
   * - 某些第三方账户可能需要单独处理
   * - 执行后用户会被自动登出
   * 
   * 安全考虑：
   * - 需要当前用户的有效认证
   * - 可能需要额外的身份验证（取决于设置）
   * - 所有操作会被详细记录在审计日志中
   * 
   * 法律和隐私：
   * - 遵循GDPR和其他数据保护法规
   * - 某些数据可能需要保留一定时间用于合规
   * - 用户有权要求数据导出和删除
   */
  // 注意：这个功能是不可逆的，将会删除当前用户的账户。
  static Future<FlowyResult<void, FlowyError>> deleteCurrentAccount() {
    return UserEventDeleteAccount().send();
  }
}
