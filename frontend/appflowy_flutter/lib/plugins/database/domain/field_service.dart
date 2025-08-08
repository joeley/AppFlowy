import 'dart:typed_data';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

/// 字段后端服务 - 提供数据库字段的所有操作接口
/// 
/// 主要功能：
/// 1. 字段CRUD操作（创建、更新、删除、复制）
/// 2. 字段类型管理（类型转换、类型选项更新）
/// 3. 字段顺序管理（移动、插入位置控制）
/// 4. 字段属性管理（名称、图标、冻结状态）
/// 5. 清空字段数据
/// 
/// 设计思想：
/// - 大部分方法为静态方法，便于直接调用
/// - 部分实例方法通过viewId和fieldId简化调用
/// - 通过Protocol Buffers与后端通信
/// 
/// 更多实现细节请参考：`rust-lib/flowy-database/event_map.rs`
class FieldBackendService {
  FieldBackendService({required this.viewId, required this.fieldId});

  /// 视图ID
  final String viewId;
  
  /// 字段ID
  final String fieldId;

  /// 创建新字段
  /// 
  /// 在指定视图中创建新字段。位置参数仅对当前视图有效，
  /// 在其他视图中会追加到末尾
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fieldType]: 字段类型，默认为富文本
  /// - [fieldName]: 字段名称
  /// - [icon]: 字段图标
  /// - [typeOptionData]: 类型选项数据
  /// - [position]: 插入位置
  static Future<FlowyResult<FieldPB, FlowyError>> createField({
    required String viewId,
    FieldType fieldType = FieldType.RichText,
    String? fieldName,
    String? icon,
    Uint8List? typeOptionData,
    OrderObjectPositionPB? position,
  }) {
    final payload = CreateFieldPayloadPB(
      viewId: viewId,
      fieldType: fieldType,
      fieldName: fieldName,
      typeOptionData: typeOptionData,
      fieldPosition: position,
    );

    return DatabaseEventCreateField(payload).send();
  }

  /// 移动字段位置
  /// 
  /// 在视图中重新排序字段
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fromFieldId]: 要移动的字段ID
  /// - [toFieldId]: 目标位置字段ID
  static Future<FlowyResult<void, FlowyError>> moveField({
    required String viewId,
    required String fromFieldId,
    required String toFieldId,
  }) {
    final payload = MoveFieldPayloadPB(
      viewId: viewId,
      fromFieldId: fromFieldId,
      toFieldId: toFieldId,
    );

    return DatabaseEventMoveField(payload).send();
  }

  /// 删除字段
  /// 
  /// 删除指定字段及其所有数据
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fieldId]: 要删除的字段ID
  static Future<FlowyResult<void, FlowyError>> deleteField({
    required String viewId,
    required String fieldId,
  }) {
    final payload = DeleteFieldPayloadPB(
      viewId: viewId,
      fieldId: fieldId,
    );

    return DatabaseEventDeleteField(payload).send();
  }

  /// 清空字段数据
  /// 
  /// 清空指定字段中所有单元格的数据，但保留字段定义
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fieldId]: 要清空的字段ID
  static Future<FlowyResult<void, FlowyError>> clearField({
    required String viewId,
    required String fieldId,
  }) {
    final payload = ClearFieldPayloadPB(
      viewId: viewId,
      fieldId: fieldId,
    );

    return DatabaseEventClearField(payload).send();
  }

  /// 复制字段
  /// 
  /// 创建指定字段的副本，包括其所有设置
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fieldId]: 要复制的字段ID
  static Future<FlowyResult<void, FlowyError>> duplicateField({
    required String viewId,
    required String fieldId,
  }) {
    final payload = DuplicateFieldPayloadPB(viewId: viewId, fieldId: fieldId);

    return DatabaseEventDuplicateField(payload).send();
  }

  /// 更新字段属性
  /// 
  /// 更新字段的基本属性，如名称、图标、冻结状态
  /// 
  /// 参数：
  /// - [name]: 新的字段名称
  /// - [icon]: 新的字段图标
  /// - [frozen]: 是否冻结字段（固定在左侧）
  Future<FlowyResult<void, FlowyError>> updateField({
    String? name,
    String? icon,
    bool? frozen,
  }) {
    final payload = FieldChangesetPB.create()
      ..viewId = viewId
      ..fieldId = fieldId;

    if (name != null) {
      payload.name = name;
    }

    if (icon != null) {
      payload.icon = icon;
    }

    if (frozen != null) {
      payload.frozen = frozen;
    }

    return DatabaseEventUpdateField(payload).send();
  }

  /// 更改字段类型
  /// 
  /// 将字段转换为另一种类型，会尝试转换现有数据
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fieldId]: 要更改的字段ID
  /// - [fieldType]: 新的字段类型
  /// - [fieldName]: 可选的新名称
  static Future<FlowyResult<void, FlowyError>> updateFieldType({
    required String viewId,
    required String fieldId,
    required FieldType fieldType,
    String? fieldName,
  }) {
    final payload = UpdateFieldTypePayloadPB()
      ..viewId = viewId
      ..fieldId = fieldId
      ..fieldType = fieldType;

    // Only set if fieldName is not null
    if (fieldName != null) {
      payload.fieldName = fieldName;
    }

    return DatabaseEventUpdateFieldType(payload).send();
  }

  /// 更新字段类型选项
  /// 
  /// 更新字段特定类型的配置选项（如选择器的选项列表）
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [fieldId]: 字段ID
  /// - [typeOptionData]: 类型选项数据（Protocol Buffer格式）
  static Future<FlowyResult<void, FlowyError>> updateFieldTypeOption({
    required String viewId,
    required String fieldId,
    required List<int> typeOptionData,
  }) {
    final payload = TypeOptionChangesetPB.create()
      ..viewId = viewId
      ..fieldId = fieldId
      ..typeOptionData = typeOptionData;

    return DatabaseEventUpdateFieldTypeOption(payload).send();
  }

  /// 获取所有字段
  /// 
  /// 获取指定视图的所有字段列表
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  static Future<FlowyResult<List<FieldPB>, FlowyError>> getFields({
    required String viewId,
  }) {
    final payload = GetFieldPayloadPB.create()..viewId = viewId;

    return DatabaseEventGetFields(payload).send().fold(
          (repeated) => FlowySuccess(repeated.items),
          (error) => FlowyFailure(error),
        );
  }

  /// 获取主字段
  /// 
  /// 返回视图的主字段（通常是第一列，用作行标题）
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  static Future<FlowyResult<FieldPB, FlowyError>> getPrimaryField({
    required String viewId,
  }) {
    final payload = DatabaseViewIdPB.create()..value = viewId;
    return DatabaseEventGetPrimaryField(payload).send();
  }

  /// 在当前字段前创建新字段
  /// 
  /// 便捷方法，在当前字段前插入新字段
  Future<FlowyResult<FieldPB, FlowyError>> createBefore({
    FieldType fieldType = FieldType.RichText,
    String? fieldName,
    Uint8List? typeOptionData,
  }) {
    return createField(
      viewId: viewId,
      fieldType: fieldType,
      fieldName: fieldName,
      typeOptionData: typeOptionData,
      position: OrderObjectPositionPB(
        position: OrderObjectPositionTypePB.Before,
        objectId: fieldId,
      ),
    );
  }

  /// 在当前字段后创建新字段
  /// 
  /// 便捷方法，在当前字段后插入新字段
  Future<FlowyResult<FieldPB, FlowyError>> createAfter({
    FieldType fieldType = FieldType.RichText,
    String? fieldName,
    Uint8List? typeOptionData,
  }) {
    return createField(
      viewId: viewId,
      fieldType: fieldType,
      fieldName: fieldName,
      typeOptionData: typeOptionData,
      position: OrderObjectPositionPB(
        position: OrderObjectPositionTypePB.After,
        objectId: fieldId,
      ),
    );
  }

  /// 更新当前字段类型
  /// 
  /// 便捷方法，更新当前实例字段的类型
  Future<FlowyResult<void, FlowyError>> updateType({
    required FieldType fieldType,
    String? fieldName,
  }) =>
      updateFieldType(
        viewId: viewId,
        fieldId: fieldId,
        fieldType: fieldType,
        fieldName: fieldName,
      );

  /// 删除当前字段
  /// 
  /// 便捷方法，删除当前实例字段
  Future<FlowyResult<void, FlowyError>> delete() =>
      deleteField(viewId: viewId, fieldId: fieldId);

  /// 复制当前字段
  /// 
  /// 便捷方法，复制当前实例字段
  Future<FlowyResult<void, FlowyError>> duplicate() =>
      duplicateField(viewId: viewId, fieldId: fieldId);
}
