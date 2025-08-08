import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;

/// 过滤器后端服务 - 管理数据库视图的过滤功能
/// 
/// 主要功能：
/// 1. 获取所有过滤器
/// 2. 添加/更新各种类型的过滤器
/// 3. 删除过滤器
/// 
/// 支持的过滤器类型：
/// - 文本过滤器（包含/不包含/等于等）
/// - 复选框过滤器（选中/未选中）
/// - 数字过滤器（大于/小于/等于等）
/// - 日期过滤器（范围/特定日期）
/// - 选项过滤器（单选/多选）
/// - URL过滤器
/// - 检查列表过滤器
/// - 时间过滤器
/// - 媒体过滤器
/// 
/// 设计思想：
/// - 为每种字段类型提供专门的过滤方法
/// - 支持创建和更新操作（通过filterId区分）
/// - 通过Protocol Buffers序列化过滤条件
class FilterBackendService {
  const FilterBackendService({required this.viewId});

  /// 视图ID
  final String viewId;

  /// 获取所有过滤器
  /// 
  /// 获取当前视图的所有过滤器列表
  Future<FlowyResult<List<FilterPB>, FlowyError>> getAllFilters() {
    final payload = DatabaseViewIdPB()..value = viewId;

    return DatabaseEventGetAllFilters(payload).send().then((result) {
      return result.fold(
        (repeated) => FlowyResult.success(repeated.items),
        (r) => FlowyResult.failure(r),
      );
    });
  }

  /// 插入或更新文本过滤器
  /// 
  /// 创建新的文本过滤器或更新现有过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件（包含/不包含/等于等）
  /// - [content]: 过滤内容
  Future<FlowyResult<void, FlowyError>> insertTextFilter({
    required String fieldId,
    String? filterId,
    required TextFilterConditionPB condition,
    required String content,
  }) {
    final filter = TextFilterPB()
      ..condition = condition
      ..content = content;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.RichText,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.RichText,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新复选框过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件（选中/未选中）
  Future<FlowyResult<void, FlowyError>> insertCheckboxFilter({
    required String fieldId,
    String? filterId,
    required CheckboxFilterConditionPB condition,
  }) {
    final filter = CheckboxFilterPB()..condition = condition;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.Checkbox,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.Checkbox,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新数字过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件（大于/小于/等于等）
  /// - [content]: 比较值
  Future<FlowyResult<void, FlowyError>> insertNumberFilter({
    required String fieldId,
    String? filterId,
    required NumberFilterConditionPB condition,
    String content = "",
  }) {
    final filter = NumberFilterPB()
      ..condition = condition
      ..content = content;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.Number,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.Number,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新日期过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [fieldType]: 字段类型
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件（范围/特定日期等）
  /// - [start]: 开始时间戳
  /// - [end]: 结束时间戳
  /// - [timestamp]: 特定时间戳
  Future<FlowyResult<void, FlowyError>> insertDateFilter({
    required String fieldId,
    required FieldType fieldType,
    String? filterId,
    required DateFilterConditionPB condition,
    int? start,
    int? end,
    int? timestamp,
  }) {
    final filter = DateFilterPB()..condition = condition;

    if (timestamp != null) {
      filter.timestamp = $fixnum.Int64(timestamp);
    }
    if (start != null) {
      filter.start = $fixnum.Int64(start);
    }
    if (end != null) {
      filter.end = $fixnum.Int64(end);
    }

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: fieldType,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: fieldType,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新URL过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件
  /// - [content]: URL内容
  Future<FlowyResult<void, FlowyError>> insertURLFilter({
    required String fieldId,
    String? filterId,
    required TextFilterConditionPB condition,
    String content = "",
  }) {
    final filter = TextFilterPB()
      ..condition = condition
      ..content = content;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.URL,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.URL,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新选项过滤器
  /// 
  /// 用于单选和多选字段的过滤
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [fieldType]: 字段类型（单选/多选）
  /// - [condition]: 过滤条件（包含/不包含等）
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [optionIds]: 选项ID列表
  Future<FlowyResult<void, FlowyError>> insertSelectOptionFilter({
    required String fieldId,
    required FieldType fieldType,
    required SelectOptionFilterConditionPB condition,
    String? filterId,
    List<String> optionIds = const [],
  }) {
    final filter = SelectOptionFilterPB()
      ..condition = condition
      ..optionIds.addAll(optionIds);

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: fieldType,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: fieldType,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新检查列表过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [condition]: 过滤条件
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [optionIds]: 选项ID列表
  Future<FlowyResult<void, FlowyError>> insertChecklistFilter({
    required String fieldId,
    required ChecklistFilterConditionPB condition,
    String? filterId,
    List<String> optionIds = const [],
  }) {
    final filter = ChecklistFilterPB()..condition = condition;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.Checklist,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.Checklist,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入或更新时间过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件
  /// - [content]: 时间值
  Future<FlowyResult<void, FlowyError>> insertTimeFilter({
    required String fieldId,
    String? filterId,
    required NumberFilterConditionPB condition,
    String content = "",
  }) {
    final filter = TimeFilterPB()
      ..condition = condition
      ..content = content;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.Time,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.Time,
            data: filter.writeToBuffer(),
          );
  }

  /// 插入通用过滤器
  /// 
  /// 底层插入过滤器的通用方法
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [fieldType]: 字段类型
  /// - [data]: 过滤器数据（Protocol Buffer序列化后）
  Future<FlowyResult<void, FlowyError>> insertFilter({
    required String fieldId,
    required FieldType fieldType,
    required List<int> data,
  }) async {
    final filterData = FilterDataPB()
      ..fieldId = fieldId
      ..fieldType = fieldType
      ..data = data;

    final insertFilterPayload = InsertFilterPB()..data = filterData;

    final payload = DatabaseSettingChangesetPB()
      ..viewId = viewId
      ..insertFilter = insertFilterPayload;

    final result = await DatabaseEventUpdateDatabaseSetting(payload).send();
    return result.fold(
      (l) => FlowyResult.success(l),
      (err) {
        Log.error(err);
        return FlowyResult.failure(err);
      },
    );
  }

  /// 更新通用过滤器
  /// 
  /// 底层更新过滤器的通用方法
  /// 
  /// 参数：
  /// - [filterId]: 过滤器ID
  /// - [fieldId]: 字段ID
  /// - [fieldType]: 字段类型
  /// - [data]: 过滤器数据（Protocol Buffer序列化后）
  Future<FlowyResult<void, FlowyError>> updateFilter({
    required String filterId,
    required String fieldId,
    required FieldType fieldType,
    required List<int> data,
  }) async {
    final filterData = FilterDataPB()
      ..fieldId = fieldId
      ..fieldType = fieldType
      ..data = data;

    final updateFilterPayload = UpdateFilterDataPB()
      ..filterId = filterId
      ..data = filterData;

    final payload = DatabaseSettingChangesetPB()
      ..viewId = viewId
      ..updateFilterData = updateFilterPayload;

    final result = await DatabaseEventUpdateDatabaseSetting(payload).send();
    return result.fold(
      (l) => FlowyResult.success(l),
      (err) {
        Log.error(err);
        return FlowyResult.failure(err);
      },
    );
  }

  /// 插入或更新媒体过滤器
  /// 
  /// 参数：
  /// - [fieldId]: 字段ID
  /// - [filterId]: 过滤器ID（更新时提供）
  /// - [condition]: 过滤条件
  /// - [content]: 媒体内容
  Future<FlowyResult<void, FlowyError>> insertMediaFilter({
    required String fieldId,
    String? filterId,
    required MediaFilterConditionPB condition,
    String content = "",
  }) {
    final filter = MediaFilterPB()
      ..condition = condition
      ..content = content;

    return filterId == null
        ? insertFilter(
            fieldId: fieldId,
            fieldType: FieldType.Media,
            data: filter.writeToBuffer(),
          )
        : updateFilter(
            filterId: filterId,
            fieldId: fieldId,
            fieldType: FieldType.Media,
            data: filter.writeToBuffer(),
          );
  }

  /// 删除过滤器
  /// 
  /// 删除指定的过滤器
  /// 
  /// 参数：
  /// - [filterId]: 要删除的过滤器ID
  Future<FlowyResult<void, FlowyError>> deleteFilter({
    required String filterId,
  }) async {
    final deleteFilterPayload = DeleteFilterPB()..filterId = filterId;

    final payload = DatabaseSettingChangesetPB()
      ..viewId = viewId
      ..deleteFilter = deleteFilterPayload;

    final result = await DatabaseEventUpdateDatabaseSetting(payload).send();
    return result.fold(
      (l) => FlowyResult.success(l),
      (err) {
        Log.error(err);
        return FlowyResult.failure(err);
      },
    );
  }
}
