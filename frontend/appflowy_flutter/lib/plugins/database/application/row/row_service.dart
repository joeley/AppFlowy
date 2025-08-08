import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

import '../field/field_info.dart';

/// 行ID类型别名
typedef RowId = String;

/// 行后端服务 - 提供数据库行的所有操作接口
/// 
/// 主要功能：
/// 1. 行CRUD操作（创建、读取、更新、删除）
/// 2. 行位置管理（在指定位置插入行）
/// 3. 行元数据管理（图标、封面、文档状态）
/// 4. 行复制功能
/// 5. 初始化行数据
/// 
/// 设计思想：
/// - 提供静态方法供全局调用
/// - 提供实例方法简化特定视图的操作
/// - 支持通过RowDataBuilder构建初始单元格数据
class RowBackendService {
  RowBackendService({required this.viewId});

  /// 视图ID
  final String viewId;

  /// 创建新行
  /// 
  /// 在指定视图中创建新行，可以指定位置和初始数据
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [groupId]: 分组ID（用于看板视图）
  /// - [withCells]: 构建初始单元格数据的回调
  /// - [position]: 插入位置类型（前/后）
  /// - [targetRowId]: 目标行ID（参考位置）
  static Future<FlowyResult<RowMetaPB, FlowyError>> createRow({
    required String viewId,
    String? groupId,
    void Function(RowDataBuilder builder)? withCells,
    OrderObjectPositionTypePB? position,
    String? targetRowId,
  }) {
    final payload = CreateRowPayloadPB(
      viewId: viewId,
      groupId: groupId,
      rowPosition: OrderObjectPositionPB(
        position: position,
        objectId: targetRowId,
      ),
    );

    if (withCells != null) {
      final rowBuilder = RowDataBuilder();
      withCells(rowBuilder);
      payload.data.addAll(rowBuilder.build());
    }

    return DatabaseEventCreateRow(payload).send();
  }

  /// 初始化行
  /// 
  /// 初始化指定行的数据，通常在创建后调用
  /// 
  /// 参数：
  /// - [rowId]: 行ID
  Future<FlowyResult<void, FlowyError>> initRow(RowId rowId) async {
    final payload = DatabaseViewRowIdPB()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventInitRow(payload).send();
  }

  /// 在指定行前创建新行
  /// 
  /// 便捷方法，在指定行前插入新行
  Future<FlowyResult<RowMetaPB, FlowyError>> createRowBefore(RowId rowId) {
    return createRow(
      viewId: viewId,
      position: OrderObjectPositionTypePB.Before,
      targetRowId: rowId,
    );
  }

  /// 在指定行后创建新行
  /// 
  /// 便捷方法，在指定行后插入新行
  Future<FlowyResult<RowMetaPB, FlowyError>> createRowAfter(RowId rowId) {
    return createRow(
      viewId: viewId,
      position: OrderObjectPositionTypePB.After,
      targetRowId: rowId,
    );
  }

  /// 获取行元数据（静态方法）
  /// 
  /// 获取指定行的元数据信息
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [rowId]: 行ID
  static Future<FlowyResult<RowMetaPB, FlowyError>> getRow({
    required String viewId,
    required String rowId,
  }) {
    final payload = DatabaseViewRowIdPB()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventGetRowMeta(payload).send();
  }

  /// 获取行元数据（实例方法）
  /// 
  /// 获取当前视图中指定行的元数据
  Future<FlowyResult<RowMetaPB, FlowyError>> getRowMeta(RowId rowId) {
    final payload = DatabaseViewRowIdPB.create()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventGetRowMeta(payload).send();
  }

  /// 更新行元数据
  /// 
  /// 更新行的元数据信息，如图标、封面、文档状态
  /// 
  /// 参数：
  /// - [rowId]: 行ID
  /// - [iconURL]: 图标URL
  /// - [cover]: 封面信息
  /// - [isDocumentEmpty]: 文档是否为空
  Future<FlowyResult<void, FlowyError>> updateMeta({
    required String rowId,
    String? iconURL,
    RowCoverPB? cover,
    bool? isDocumentEmpty,
  }) {
    final payload = UpdateRowMetaChangesetPB.create()
      ..viewId = viewId
      ..id = rowId;

    if (iconURL != null) {
      payload.iconUrl = iconURL;
    }
    if (cover != null) {
      payload.cover = cover;
    }

    if (isDocumentEmpty != null) {
      payload.isDocumentEmpty = isDocumentEmpty;
    }

    return DatabaseEventUpdateRowMeta(payload).send();
  }

  /// 移除行封面
  /// 
  /// 移除指定行的封面图片
  /// 
  /// 参数：
  /// - [rowId]: 行ID
  Future<FlowyResult<void, FlowyError>> removeCover(String rowId) async {
    final payload = RemoveCoverPayloadPB.create()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventRemoveCover(payload).send();
  }

  /// 删除多行
  /// 
  /// 批量删除指定的行
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [rowIds]: 要删除的行ID列表
  static Future<FlowyResult<void, FlowyError>> deleteRows(
    String viewId,
    List<RowId> rowIds,
  ) {
    final payload = RepeatedRowIdPB.create()
      ..viewId = viewId
      ..rowIds.addAll(rowIds);

    return DatabaseEventDeleteRows(payload).send();
  }

  /// 复制行
  /// 
  /// 创建指定行的副本，包括其所有数据
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [rowId]: 要复制的行ID
  static Future<FlowyResult<void, FlowyError>> duplicateRow(
    String viewId,
    RowId rowId,
  ) {
    final payload = DatabaseViewRowIdPB(
      viewId: viewId,
      rowId: rowId,
    );

    return DatabaseEventDuplicateRow(payload).send();
  }
}

/// 行数据构建器
/// 
/// 用于构建创建行时的初始单元格数据
/// 
/// 使用方式：
/// ```dart
/// RowBackendService.createRow(
///   viewId: viewId,
///   withCells: (builder) {
///     builder.insertText(fieldInfo, "Hello");
///     builder.insertNumber(numberField, 42);
///   },
/// );
/// ```
class RowDataBuilder {
  /// 存储字段ID到单元格数据的映射
  final _cellDataByFieldId = <String, String>{};

  /// 插入文本数据
  /// 
  /// 在指定文本字段中插入文本内容
  void insertText(FieldInfo fieldInfo, String text) {
    assert(fieldInfo.fieldType == FieldType.RichText);
    _cellDataByFieldId[fieldInfo.field.id] = text;
  }

  /// 插入数字数据
  /// 
  /// 在指定数字字段中插入数字
  void insertNumber(FieldInfo fieldInfo, int num) {
    assert(fieldInfo.fieldType == FieldType.Number);
    _cellDataByFieldId[fieldInfo.field.id] = num.toString();
  }

  /// 插入日期数据
  /// 
  /// 在指定日期字段中插入日期，转换为Unix时间戳
  void insertDate(FieldInfo fieldInfo, DateTime date) {
    assert(fieldInfo.fieldType == FieldType.DateTime);
    final timestamp = date.millisecondsSinceEpoch ~/ 1000;
    _cellDataByFieldId[fieldInfo.field.id] = timestamp.toString();
  }

  /// 构建最终数据
  /// 
  /// 返回字段ID到单元格数据的映射
  Map<String, String> build() {
    return _cellDataByFieldId;
  }
}
