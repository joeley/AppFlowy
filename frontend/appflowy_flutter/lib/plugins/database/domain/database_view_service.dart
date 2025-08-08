import 'package:appflowy/plugins/database/application/row/row_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

import 'layout_service.dart';

/// 数据库视图后端服务 - 管理数据库视图的核心功能
/// 
/// 主要功能：
/// 1. 视图基本操作（打开、关闭、获取数据库ID）
/// 2. 布局管理（表格、看板、日历视图切换）
/// 3. 行和分组移动操作
/// 4. 字段管理
/// 5. 布局设置管理
/// 6. 分组加载
/// 
/// 设计思想：
/// - 以视图ID为中心，提供各种视图级别的操作
/// - 支持多种布局模式的不同设置
/// - 通过Protocol Buffers与后端通信
class DatabaseViewBackendService {
  DatabaseViewBackendService({required this.viewId});

  /// 视图ID
  final String viewId;

  /// 获取数据库ID
  /// 
  /// 返回与视图关联的数据库ID
  /// 一个数据库可以有多个视图（不同布局）
  Future<FlowyResult<String, FlowyError>> getDatabaseId() async {
    final payload = DatabaseViewIdPB(value: viewId);
    return DatabaseEventGetDatabaseId(payload)
        .send()
        .then((value) => value.map((l) => l.value));
  }

  /// 更新视图布局
  /// 
  /// 切换视图的布局类型（表格/看板/日历）
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [layout]: 新的布局类型
  static Future<FlowyResult<ViewPB, FlowyError>> updateLayout({
    required String viewId,
    required DatabaseLayoutPB layout,
  }) {
    final payload = UpdateViewPayloadPB.create()
      ..viewId = viewId
      ..layout = viewLayoutFromDatabaseLayout(layout);

    return FolderEventUpdateView(payload).send();
  }

  /// 打开数据库
  /// 
  /// 获取完整的数据库信息，包括所有字段和行数据
  Future<FlowyResult<DatabasePB, FlowyError>> openDatabase() async {
    final payload = DatabaseViewIdPB(value: viewId);
    return DatabaseEventGetDatabase(payload).send();
  }

  /// 移动分组中的行
  /// 
  /// 在看板视图中，将行从一个分组移动到另一个分组
  /// 
  /// 参数：
  /// - [fromRowId]: 要移动的行ID
  /// - [fromGroupId]: 源分组ID
  /// - [toGroupId]: 目标分组ID
  /// - [toRowId]: 目标位置的参考行ID（可选）
  Future<FlowyResult<void, FlowyError>> moveGroupRow({
    required RowId fromRowId,
    required String fromGroupId,
    required String toGroupId,
    RowId? toRowId,
  }) {
    final payload = MoveGroupRowPayloadPB.create()
      ..viewId = viewId
      ..fromRowId = fromRowId
      ..fromGroupId = fromGroupId
      ..toGroupId = toGroupId;

    if (toRowId != null) {
      payload.toRowId = toRowId;
    }

    return DatabaseEventMoveGroupRow(payload).send();
  }

  /// 移动行
  /// 
  /// 在视图中重新排序行的位置
  /// 
  /// 参数：
  /// - [fromRowId]: 要移动的行ID
  /// - [toRowId]: 目标位置的行ID
  Future<FlowyResult<void, FlowyError>> moveRow({
    required String fromRowId,
    required String toRowId,
  }) {
    final payload = MoveRowPayloadPB.create()
      ..viewId = viewId
      ..fromRowId = fromRowId
      ..toRowId = toRowId;

    return DatabaseEventMoveRow(payload).send();
  }

  /// 移动分组
  /// 
  /// 在看板视图中重新排序分组的位置
  /// 
  /// 参数：
  /// - [fromGroupId]: 要移动的分组ID
  /// - [toGroupId]: 目标位置的分组ID
  Future<FlowyResult<void, FlowyError>> moveGroup({
    required String fromGroupId,
    required String toGroupId,
  }) {
    final payload = MoveGroupPayloadPB.create()
      ..viewId = viewId
      ..fromGroupId = fromGroupId
      ..toGroupId = toGroupId;

    return DatabaseEventMoveGroup(payload).send();
  }

  /// 获取字段列表
  /// 
  /// 获取视图中的字段，可以指定特定字段ID
  /// 
  /// 参数：
  /// - [fieldIds]: 要获取的特定字段ID列表（可选）
  Future<FlowyResult<List<FieldPB>, FlowyError>> getFields({
    List<FieldIdPB>? fieldIds,
  }) {
    final payload = GetFieldPayloadPB.create()..viewId = viewId;

    if (fieldIds != null) {
      payload.fieldIds = RepeatedFieldIdPB(items: fieldIds);
    }
    return DatabaseEventGetFields(payload).send().then((result) {
      return result.fold(
        (l) => FlowyResult.success(l.items),
        (r) => FlowyResult.failure(r),
      );
    });
  }

  /// 获取布局设置
  /// 
  /// 获取特定布局类型的设置信息
  /// 
  /// 参数：
  /// - [layoutType]: 布局类型（表格/看板/日历）
  Future<FlowyResult<DatabaseLayoutSettingPB, FlowyError>> getLayoutSetting(
    DatabaseLayoutPB layoutType,
  ) {
    final payload = DatabaseLayoutMetaPB.create()
      ..viewId = viewId
      ..layout = layoutType;
    return DatabaseEventGetLayoutSetting(payload).send();
  }

  /// 更新布局设置
  /// 
  /// 更新特定布局类型的设置
  /// 
  /// 参数：
  /// - [layoutType]: 布局类型
  /// - [boardLayoutSetting]: 看板布局设置（可选）
  /// - [calendarLayoutSetting]: 日历布局设置（可选）
  Future<FlowyResult<void, FlowyError>> updateLayoutSetting({
    required DatabaseLayoutPB layoutType,
    BoardLayoutSettingPB? boardLayoutSetting,
    CalendarLayoutSettingPB? calendarLayoutSetting,
  }) {
    final payload = LayoutSettingChangesetPB.create()
      ..viewId = viewId
      ..layoutType = layoutType;

    if (boardLayoutSetting != null) {
      payload.board = boardLayoutSetting;
    }

    if (calendarLayoutSetting != null) {
      payload.calendar = calendarLayoutSetting;
    }

    return DatabaseEventSetLayoutSetting(payload).send();
  }

  /// 关闭视图
  /// 
  /// 关闭当前视图，释放相关资源
  Future<FlowyResult<void, FlowyError>> closeView() {
    final request = ViewIdPB(value: viewId);
    return FolderEventCloseView(request).send();
  }

  /// 加载分组
  /// 
  /// 加载视图的所有分组信息（主要用于看板视图）
  Future<FlowyResult<RepeatedGroupPB, FlowyError>> loadGroups() {
    final payload = DatabaseViewIdPB(value: viewId);
    return DatabaseEventGetGroups(payload).send();
  }
}
