import 'dart:async';

// 页面引用功能相关
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_page_bloc.dart';
// 垃圾回收站服务
import 'package:appflowy/plugins/trash/application/trash_service.dart';
// 图标和表情符号选择器
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
// 消息分发系统
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
// 文档相关Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-document/entities.pb.dart';
// 错误处理相关定义
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
// 文件夹和视图相关定义
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
// 结果包装器
import 'package:appflowy_result/appflowy_result.dart';
// 集合工具
import 'package:collection/collection.dart';

/* 视图后端服务类
 * 
 * AppFlowy中最重要的服务类之一，负责视图（文档、数据库、看板等）的完整生命周期管理
 * 
 * 核心功能：
 * 1. 视图的CRUD操作（创建、读取、更新、删除）
 * 2. 视图层次结构管理（父子关系、移动、重组）
 * 3. 视图元数据管理（图标、名称、描述等）
 * 4. 权限和可见性控制
 * 5. 发布和分享功能
 * 6. 版本控制和历史记录
 * 
 * 数据同步特性：
 * - 实时协作：多用户同时编辑
 * - 增量同步：只同步变更部分
 * - 冲突解决：操作转换算法
 * - 离线支持：本地优先架构
 * - 版本控制：完整的操作历史
 * 
 * 架构设计：
 * - 静态方法设计，便于全局调用
 * - 基于事件的异步通信
 * - Protocol Buffers序列化
 * - 统一的错误处理机制
 * 
 * 与Rust后端通信：
 * - FolderEvent*: 文件夹和视图操作
 * - DocumentEvent*: 文档特定操作
 * - 所有操作都通过消息分发系统
 */
class ViewBackendService {
  /* 创建视图
   * 
   * AppFlowy中创建新视图的核心方法，支持多种视图类型
   * 
   * 参数说明：
   * - layoutType: 视图布局类型（文档、数据库、看板、日历等）
   * - parentViewId: 父视图ID，确定视图的层级关系
   * - name: 视图名称，用户可见的标题
   * - openAfterCreate: 是否在创建后立即打开视图
   * - initialDataBytes: 初始数据，用于文档类型的预填充内容
   * - ext: 扩展配置，用于特殊视图类型的额外参数
   * - index: 在父视图中的位置索引
   * - section: 视图所属区域（公开/私有）
   * - viewId: 自定义视图ID（通常自动生成）
   * 
   * 数据同步机制：
   * - 本地创建后立即同步到Rust后端
   * - 支持乐观更新（UI先更新，后同步）
   * - 创建失败时自动回滚UI状态
   * - 多端实时同步新创建的视图
   * 
   * 支持的视图类型：
   * - Document: 富文本文档
   * - Grid: 表格数据库
   * - Board: 看板视图
   * - Calendar: 日历视图
   * - Chat: AI聊天界面
   * 
   * 返回值：
   * - 成功：包含完整视图数据的ViewPB对象
   * - 失败：详细的错误信息和错误代码
   */
  static Future<FlowyResult<ViewPB, FlowyError>> createView({
    /// 视图布局类型（文档、数据库、看板等）
    required ViewLayoutPB layoutType,

    /// 父视图ID，确定视图层级关系
    required String parentViewId,

    /// 视图名称
    required String name,

    /// 创建后是否立即打开并设为当前视图
    /// 默认false表示不会打开，设为true则会打开并在应用重启时自动恢复
    bool openAfterCreate = false,

    /// 初始数据字节数组
    /// 目前仅支持文档类型的初始数据预填充
    List<int>? initialDataBytes,

    /// 扩展配置映射
    /// 用于传递特定视图类型的自定义配置
    /// 例如链接到现有数据库时需要传递 "database_id": "xxx"
    Map<String, String> ext = const {},

    /// 在父视图中的位置索引
    /// null表示添加到列表末尾
    int? index,
    ViewSectionPB? section,
    final String? viewId,
  }) {
    // 构造创建视图的载荷数据
    final payload = CreateViewPayloadPB.create()
      ..parentViewId = parentViewId
      ..name = name
      ..layout = layoutType
      ..setAsCurrent = openAfterCreate
      ..initialData = initialDataBytes ?? [];

    // 添加扩展配置
    if (ext.isNotEmpty) {
      payload.meta.addAll(ext);
    }

    // 设置位置索引
    if (index != null) {
      payload.index = index;
    }

    // 设置视图区域
    if (section != null) {
      payload.section = section;
    }

    // 设置自定义视图ID
    if (viewId != null) {
      payload.viewId = viewId;
    }

    // 通过文件夹事件系统发送创建请求
    return FolderEventCreateView(payload).send();
  }

  /// The orphan view is meant to be a view that is not attached to any parent view. By default, this
  /// view will not be shown in the view list unless it is attached to a parent view that is shown in
  /// the view list.
  static Future<FlowyResult<ViewPB, FlowyError>> createOrphanView({
    required String viewId,
    required ViewLayoutPB layoutType,
    required String name,
    String? desc,

    /// The initial data should be a JSON that represent the DocumentDataPB.
    /// Currently, only support create document with initial data.
    List<int>? initialDataBytes,
  }) {
    final payload = CreateOrphanViewPayloadPB.create()
      ..viewId = viewId
      ..name = name
      ..layout = layoutType
      ..initialData = initialDataBytes ?? [];

    return FolderEventCreateOrphanView(payload).send();
  }

  static Future<FlowyResult<ViewPB, FlowyError>> createDatabaseLinkedView({
    required String parentViewId,
    required String databaseId,
    required ViewLayoutPB layoutType,
    required String name,
  }) {
    return createView(
      layoutType: layoutType,
      parentViewId: parentViewId,
      name: name,
      ext: {'database_id': databaseId},
    );
  }

  /// Returns a list of views that are the children of the given [viewId].
  static Future<FlowyResult<List<ViewPB>, FlowyError>> getChildViews({
    required String viewId,
  }) {
    if (viewId.isEmpty) {
      return Future.value(
        FlowyResult<List<ViewPB>, FlowyError>.success(<ViewPB>[]),
      );
    }

    final payload = ViewIdPB.create()..value = viewId;

    return FolderEventGetView(payload).send().then((result) {
      return result.fold(
        (view) => FlowyResult.success(view.childViews),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  static Future<FlowyResult<void, FlowyError>> deleteView({
    required String viewId,
  }) {
    final request = RepeatedViewIdPB.create()..items.add(viewId);
    return FolderEventDeleteView(request).send();
  }

  static Future<FlowyResult<void, FlowyError>> deleteViews({
    required List<String> viewIds,
  }) {
    final request = RepeatedViewIdPB.create()..items.addAll(viewIds);
    return FolderEventDeleteView(request).send();
  }

  static Future<FlowyResult<ViewPB, FlowyError>> duplicate({
    required ViewPB view,
    required bool openAfterDuplicate,
    // should include children views
    required bool includeChildren,
    String? parentViewId,
    String? suffix,
    required bool syncAfterDuplicate,
  }) {
    final payload = DuplicateViewPayloadPB.create()
      ..viewId = view.id
      ..openAfterDuplicate = openAfterDuplicate
      ..includeChildren = includeChildren
      ..syncAfterCreate = syncAfterDuplicate;

    if (parentViewId != null) {
      payload.parentViewId = parentViewId;
    }

    if (suffix != null) {
      payload.suffix = suffix;
    }

    return FolderEventDuplicateView(payload).send();
  }

  static Future<FlowyResult<void, FlowyError>> favorite({
    required String viewId,
  }) {
    final request = RepeatedViewIdPB.create()..items.add(viewId);
    return FolderEventToggleFavorite(request).send();
  }

  static Future<FlowyResult<ViewPB, FlowyError>> updateView({
    required String viewId,
    String? name,
    bool? isFavorite,
    String? extra,
  }) {
    final payload = UpdateViewPayloadPB.create()..viewId = viewId;

    if (name != null) {
      payload.name = name;
    }

    if (isFavorite != null) {
      payload.isFavorite = isFavorite;
    }

    if (extra != null) {
      payload.extra = extra;
    }

    return FolderEventUpdateView(payload).send();
  }

  static Future<FlowyResult<void, FlowyError>> updateViewIcon({
    required ViewPB view,
    required EmojiIconData viewIcon,
  }) {
    final viewId = view.id;
    final oldIcon = view.icon.toEmojiIconData();
    final icon = viewIcon.toViewIcon();
    final payload = UpdateViewIconPayloadPB.create()
      ..viewId = viewId
      ..icon = icon;
    if (oldIcon.type == FlowyIconType.custom &&
        viewIcon.emoji != oldIcon.emoji) {
      DocumentEventDeleteFile(
        DeleteFilePB(url: oldIcon.emoji),
      ).send().onFailure((e) {
        Log.error(
          'updateViewIcon error while deleting :${oldIcon.emoji}, error: ${e.msg}, ${e.code}',
        );
      });
    }
    return FolderEventUpdateViewIcon(payload).send();
  }

  // deprecated
  static Future<FlowyResult<void, FlowyError>> moveView({
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

  /// Move the view to the new parent view.
  ///
  /// supports nested view
  /// if the [prevViewId] is null, the view will be moved to the beginning of the list
  static Future<FlowyResult<void, FlowyError>> moveViewV2({
    required String viewId,
    required String newParentId,
    required String? prevViewId,
    ViewSectionPB? fromSection,
    ViewSectionPB? toSection,
  }) {
    final payload = MoveNestedViewPayloadPB(
      viewId: viewId,
      newParentId: newParentId,
      prevViewId: prevViewId,
      fromSection: fromSection,
      toSection: toSection,
    );

    return FolderEventMoveNestedView(payload).send();
  }

  /// Fetches a flattened list of all Views.
  ///
  /// Views do not contain their children in this list, as they all exist
  /// in the same level in this version.
  ///
  static Future<FlowyResult<RepeatedViewPB, FlowyError>> getAllViews() async {
    return FolderEventGetAllViews().send();
  }

  static Future<FlowyResult<ViewPB, FlowyError>> getView(
    String viewId,
  ) async {
    if (viewId.isEmpty) {
      Log.error('ViewId is empty');
    }
    final payload = ViewIdPB.create()..value = viewId;
    return FolderEventGetView(payload).send();
  }

  static Future<MentionPageStatus> getMentionPageStatus(String pageId) async {
    final view = await ViewBackendService.getView(pageId).then(
      (value) => value.toNullable(),
    );

    // found the page
    if (view != null) {
      return (view, false, false);
    }

    // if the view is not found, try to fetch from trash
    final trashViews = await TrashService().readTrash();
    final trash = trashViews.fold(
      (l) => l.items.firstWhereOrNull((element) => element.id == pageId),
      (r) => null,
    );
    if (trash != null) {
      final trashView = ViewPB()
        ..id = trash.id
        ..name = trash.name;
      return (trashView, true, false);
    }

    // the page was deleted
    return (null, false, true);
  }

  static Future<FlowyResult<RepeatedViewPB, FlowyError>> getViewAncestors(
    String viewId,
  ) async {
    final payload = ViewIdPB.create()..value = viewId;
    return FolderEventGetViewAncestors(payload).send();
  }

  Future<FlowyResult<ViewPB, FlowyError>> getChildView({
    required String parentViewId,
    required String childViewId,
  }) async {
    final payload = ViewIdPB.create()..value = parentViewId;
    return FolderEventGetView(payload).send().then((result) {
      return result.fold(
        (app) => FlowyResult.success(
          app.childViews.firstWhere((e) => e.id == childViewId),
        ),
        (error) => FlowyResult.failure(error),
      );
    });
  }

  static Future<FlowyResult<void, FlowyError>> updateViewsVisibility(
    List<ViewPB> views,
    bool isPublic,
  ) async {
    final payload = UpdateViewVisibilityStatusPayloadPB(
      viewIds: views.map((e) => e.id).toList(),
      isPublic: isPublic,
    );
    return FolderEventUpdateViewVisibilityStatus(payload).send();
  }

  static Future<FlowyResult<PublishInfoResponsePB, FlowyError>> getPublishInfo(
    ViewPB view,
  ) async {
    final payload = ViewIdPB()..value = view.id;
    return FolderEventGetPublishInfo(payload).send();
  }

  static Future<FlowyResult<void, FlowyError>> publish(
    ViewPB view, {
    String? name,
    List<String>? selectedViewIds,
  }) async {
    final payload = PublishViewParamsPB()..viewId = view.id;

    if (name != null) {
      payload.publishName = name;
    }

    if (selectedViewIds != null && selectedViewIds.isNotEmpty) {
      payload.selectedViewIds = RepeatedViewIdPB(items: selectedViewIds);
    }

    return FolderEventPublishView(payload).send();
  }

  static Future<FlowyResult<void, FlowyError>> unpublish(
    ViewPB view,
  ) async {
    final payload = UnpublishViewsPayloadPB(viewIds: [view.id]);
    return FolderEventUnpublishViews(payload).send();
  }

  static Future<FlowyResult<void, FlowyError>> setPublishNameSpace(
    String name,
  ) async {
    final payload = SetPublishNamespacePayloadPB()..newNamespace = name;
    return FolderEventSetPublishNamespace(payload).send();
  }

  static Future<FlowyResult<PublishNamespacePB, FlowyError>>
      getPublishNameSpace() async {
    return FolderEventGetPublishNamespace().send();
  }

  static Future<List<ViewPB>> getAllChildViews(ViewPB view) async {
    final views = <ViewPB>[];

    final childViews =
        await ViewBackendService.getChildViews(viewId: view.id).fold(
      (s) => s,
      (f) => [],
    );

    for (final child in childViews) {
      // filter the view itself
      if (child.id == view.id) {
        continue;
      }
      views.add(child);
      views.addAll(await getAllChildViews(child));
    }

    return views;
  }

  static Future<(bool, List<ViewPB>)> containPublishedPage(ViewPB view) async {
    final childViews = await ViewBackendService.getAllChildViews(view);
    final views = [view, ...childViews];
    final List<ViewPB> publishedPages = [];

    for (final view in views) {
      final publishInfo = await ViewBackendService.getPublishInfo(view);
      if (publishInfo.isSuccess) {
        publishedPages.add(view);
      }
    }

    return (publishedPages.isNotEmpty, publishedPages);
  }

  static Future<FlowyResult<void, FlowyError>> lockView(String viewId) async {
    final payload = ViewIdPB()..value = viewId;
    return FolderEventLockView(payload).send();
  }

  static Future<FlowyResult<void, FlowyError>> unlockView(String viewId) async {
    final payload = ViewIdPB()..value = viewId;
    return FolderEventUnlockView(payload).send();
  }
}
