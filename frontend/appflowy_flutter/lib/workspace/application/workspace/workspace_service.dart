import 'dart:async';

// 消息分发系统，用于与Rust后端通信
import 'package:appflowy_backend/dispatch/dispatch.dart';
// 错误处理相关的Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
// 文件夹管理相关的Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
// 用户工作区相关的Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
// 结果包装器，用于统一的错误处理
import 'package:appflowy_result/appflowy_result.dart';
// 64位整数类型
import 'package:fixnum/fixnum.dart' as fixnum;

/* 工作区服务类
 * 
 * 负责工作区级别的数据同步和后端通信
 * 
 * 核心职责：
 * 1. 工作区信息的获取和更新
 * 2. 视图（文档、数据库等）的创建和管理
 * 3. 工作区使用情况统计
 * 4. 计费和订阅管理
 * 5. 视图的移动和重新排序
 * 
 * 数据同步策略：
 * - 所有操作都通过Rust后端处理
 * - 支持离线操作，数据会在连接恢复时同步
 * - 使用Protocol Buffers确保数据一致性
 * 
 * 与Rust后端的通信：
 * - 使用FolderEvent系列事件进行文件夹操作
 * - 使用UserEvent系列事件进行用户相关操作
 * - 所有操作都是异步的，返回FlowyResult包装的结果
 */
class WorkspaceService {
  WorkspaceService({required this.workspaceId, required this.userId});

  // 工作区唯一标识符
  final String workspaceId;
  // 用户ID（64位整数）
  final fixnum.Int64 userId;

  /* 创建新视图
   * 
   * 在工作区中创建新的视图（文档、数据库、看板等）
   * 
   * 参数：
   * - name: 视图名称
   * - viewSection: 视图所属区域（公开或私有）
   * - index: 插入位置，null表示添加到末尾
   * - layout: 视图布局类型，默认为文档类型
   * - setAsCurrent: 是否设置为当前活动视图
   * - viewId: 自定义视图ID，通常自动生成
   * - extra: 额外的配置信息
   * 
   * 返回：
   * - 成功时返回创建的视图对象
   * - 失败时返回错误信息
   * 
   * 同步机制：
   * - 本地创建后立即同步到云端
   * - 支持离线创建，连接恢复时同步
   */
  Future<FlowyResult<ViewPB, FlowyError>> createView({
    required String name,
    required ViewSectionPB viewSection,
    int? index,
    ViewLayoutPB? layout,
    bool? setAsCurrent,
    String? viewId,
    String? extra,
  }) {
    // 构建创建视图的载荷
    final payload = CreateViewPayloadPB.create()
      ..parentViewId = workspaceId  // 父视图ID（工作区）
      ..name = name                // 视图名称
      ..layout = layout ?? ViewLayoutPB.Document  // 默认文档布局
      ..section = viewSection;     // 视图区域

    // 设置可选参数
    if (index != null) {
      payload.index = index;  // 插入位置
    }

    if (setAsCurrent != null) {
      payload.setAsCurrent = setAsCurrent;  // 是否设为当前视图
    }

    if (viewId != null) {
      payload.viewId = viewId;  // 自定义视图ID
    }

    if (extra != null) {
      payload.extra = extra;  // 额外配置
    }

    // 通过文件夹事件系统发送创建请求
    return FolderEventCreateView(payload).send();
  }

  /* 获取当前工作区信息
   * 
   * 从后端获取完整的工作区数据，包括：
   * - 工作区基本信息（名称、ID、创建时间等）
   * - 包含的视图列表
   * - 权限设置
   * - 共享状态
   * 
   * 返回：
   * - 成功时返回工作区对象
   * - 失败时返回错误信息
   * 
   * 缓存策略：
   * - 数据会在本地缓存
   * - 定期与服务器同步最新状态
   */
  Future<FlowyResult<WorkspacePB, FlowyError>> getWorkspace() {
    return FolderEventReadCurrentWorkspace().send();
  }

  /* 获取公开视图列表
   * 
   * 获取工作区中所有公开可访问的视图
   * 
   * 公开视图特点：
   * - 工作区成员都可以访问
   * - 可以被搜索到
   * - 支持协作编辑
   * 
   * 返回：
   * - 成功时返回视图列表
   * - 失败时返回错误信息
   * 
   * 权限控制：
   * - 基于用户在工作区的角色
   * - 支持细粒度的访问控制
   */
  Future<FlowyResult<List<ViewPB>, FlowyError>> getPublicViews() {
    final payload = GetWorkspaceViewPB.create()..value = workspaceId;
    return FolderEventReadWorkspaceViews(payload).send().then((result) {
      return result.fold(
        (views) => FlowyResult.success(views.items),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  /* 获取私有视图列表
   * 
   * 获取当前用户的私有视图
   * 
   * 私有视图特点：
   * - 仅创建者可以访问
   * - 不会出现在公共搜索中
   * - 可以选择性地与他人共享
   * 
   * 返回：
   * - 成功时返回视图列表
   * - 失败时返回错误信息
   * 
   * 隐私保护：
   * - 数据在传输和存储时加密
   * - 严格的访问控制机制
   */
  Future<FlowyResult<List<ViewPB>, FlowyError>> getPrivateViews() {
    final payload = GetWorkspaceViewPB.create()..value = workspaceId;
    return FolderEventReadPrivateViews(payload).send().then((result) {
      return result.fold(
        (views) => FlowyResult.success(views.items),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  /* 移动视图位置
   * 
   * 在工作区中重新排列视图的顺序
   * 
   * 参数：
   * - viewId: 要移动的视图ID
   * - fromIndex: 原始位置索引
   * - toIndex: 目标位置索引
   * 
   * 同步机制：
   * - 本地立即更新UI显示
   * - 并发地同步到所有客户端
   * - 支持冲突解决（最后操作获胜）
   * 
   * 应用场景：
   * - 用户拖拽重排视图顺序
   * - 按照优先级组织视图
   */
  Future<FlowyResult<void, FlowyError>> moveView({
    required String viewId,
    required int fromIndex,
    required int toIndex,
  }) {
    final payload = MoveViewPayloadPB.create()
      ..viewId = viewId
      ..from = fromIndex
      ..to = toIndex;

    return FolderEventMoveView(payload).send();
  }

  /* 获取工作区使用情况统计
   * 
   * 获取工作区的资源使用统计信息，包括：
   * - 存储空间使用量
   * - 文档数量统计
   * - 成员数量统计
   * - 流量使用情况
   * 
   * 返回：
   * - 成功时返回使用统计数据
   * - 未找到数据时返回null
   * - 失败时返回错误信息
   * 
   * 用途：
   * - 显示账户使用情况
   * - 计费和配额管理
   * - 性能优化参考
   */
  Future<FlowyResult<WorkspaceUsagePB?, FlowyError>> getWorkspaceUsage() async {
    final payload = UserWorkspaceIdPB(workspaceId: workspaceId);
    return UserEventGetWorkspaceUsage(payload).send();
  }

  /* 获取计费门户信息
   * 
   * 获取用户计费管理门户的访问信息
   * 
   * 返回信息包括：
   * - 计费门户URL
   * - 访问令牌
   * - 会话有效期
   * 
   * 应用场景：
   * - 订阅管理
   * - 支付设置
   * - 账单查看
   * - 计费历史
   * 
   * 安全机制：
   * - 使用临时令牌访问
   * - 会话超时自动失效
   * - 支持双因素认证
   */
  Future<FlowyResult<BillingPortalPB, FlowyError>> getBillingPortal() {
    return UserEventGetBillingPortal().send();
  }
}
