/*
 * 字段控制器 - 数据库字段管理的核心
 * 
 * 设计理念：
 * 字段（Field）相当于数据库的列，定义了数据的类型和展示方式。
 * FieldController 统一管理所有字段相关的操作和状态变化。
 * 
 * 字段类型：
 * - 文本（Text）：纯文本内容
 * - 数字（Number）：支持格式化的数值
 * - 选择（Select）：单选/多选选项
 * - 日期（Date）：日期时间选择器
 * - 复选框（Checkbox）：布尔值
 * - URL：链接字段
 * - 关系（Relation）：关联其他数据库
 * - 公式（Formula）：计算字段
 * 
 * 核心功能：
 * 1. 字段 CRUD：创建、读取、更新、删除字段
 * 2. 字段设置：可见性、宽度、格式等个性化设置
 * 3. 过滤器管理：基于字段值的数据过滤
 * 4. 排序管理：按字段值排序数据
 * 5. 分组管理：按字段值分组显示
 * 
 * 监听机制：
 * - 字段变化：字段结构改变时通知
 * - 过滤器变化：过滤条件改变时更新视图
 * - 排序变化：排序规则改变时重排数据
 * - 设置变化：字段设置改变时更新显示
 * 
 * 性能优化：
 * - 使用 ChangeNotifier 减少不必要的重建
 * - 缓存字段信息避免重复请求
 * - 批量处理变更减少通知次数
 */

import 'dart:collection';

import 'package:appflowy/plugins/database/application/row/row_cache.dart';
import 'package:appflowy/plugins/database/application/setting/setting_listener.dart';
import 'package:appflowy/plugins/database/domain/database_view_service.dart';
import 'package:appflowy/plugins/database/domain/field_listener.dart';
import 'package:appflowy/plugins/database/domain/field_settings_listener.dart';
import 'package:appflowy/plugins/database/domain/field_settings_service.dart';
import 'package:appflowy/plugins/database/domain/filter_listener.dart';
import 'package:appflowy/plugins/database/domain/filter_service.dart';
import 'package:appflowy/plugins/database/domain/sort_listener.dart';
import 'package:appflowy/plugins/database/domain/sort_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../setting/setting_service.dart';
import 'field_info.dart';
import 'filter_entities.dart';
import 'sort_entities.dart';

/*
 * 字段信息通知器
 * 
 * 作用：管理字段列表的状态变化通知
 * 使用 ChangeNotifier 模式，当字段信息改变时通知所有监听者
 */
class _GridFieldNotifier extends ChangeNotifier {
  List<FieldInfo> _fieldInfos = [];

  set fieldInfos(List<FieldInfo> fieldInfos) {
    _fieldInfos = fieldInfos;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  UnmodifiableListView<FieldInfo> get fieldInfos =>
      UnmodifiableListView(_fieldInfos);
}

/*
 * 过滤器通知器
 * 
 * 作用：管理过滤器列表的状态变化
 * 当过滤条件改变时，触发数据重新过滤
 */
class _GridFilterNotifier extends ChangeNotifier {
  List<DatabaseFilter> _filters = [];

  set filters(List<DatabaseFilter> filters) {
    _filters = filters;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  List<DatabaseFilter> get filters => _filters;
}

/*
 * 排序通知器
 * 
 * 作用：管理排序规则的状态变化
 * 支持多级排序，按优先级依次应用
 */
class _GridSortNotifier extends ChangeNotifier {
  List<DatabaseSort> _sorts = [];

  set sorts(List<DatabaseSort> sorts) {
    _sorts = sorts;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  List<DatabaseSort> get sorts => _sorts;
}

/*
 * 回调类型定义
 * 
 * 这些回调用于通知外部组件字段相关的变化：
 * - OnReceiveUpdateFields：字段更新时的回调
 * - OnReceiveField：单个字段变化的回调
 * - OnReceiveFields：字段列表变化的回调
 * - OnReceiveFilters：过滤器变化的回调
 * - OnReceiveSorts：排序规则变化的回调
 */
typedef OnReceiveUpdateFields = void Function(List<FieldInfo>);
typedef OnReceiveField = void Function(FieldInfo);
typedef OnReceiveFields = void Function(List<FieldInfo>);
typedef OnReceiveFilters = void Function(List<DatabaseFilter>);
typedef OnReceiveSorts = void Function(List<DatabaseSort>);

/*
 * 字段控制器
 * 
 * 职责：
 * 1. 管理数据库视图的所有字段
 * 2. 处理字段的增删改查操作
 * 3. 管理字段相关的过滤器和排序
 * 4. 维护字段设置（如宽度、可见性等）
 * 5. 协调字段变化与视图更新
 * 
 * 初始化流程：
 * 1. 创建各种监听器和服务
 * 2. 启动监听器监听后端变化
 * 3. 建立回调机制通知外部
 * 
 * 依赖关系：
 * - 后端服务：通过 FFI 与 Rust 后端通信
 * - 监听器：监听后端推送的变化事件
 * - 通知器：通知 UI 层更新
 */
class FieldController {
  FieldController({required this.viewId})
      : _fieldListener = FieldsListener(viewId: viewId),
        _settingListener = DatabaseSettingListener(viewId: viewId),
        _filterBackendSvc = FilterBackendService(viewId: viewId),
        _filtersListener = FiltersListener(viewId: viewId),
        _databaseViewBackendSvc = DatabaseViewBackendService(viewId: viewId),
        _sortBackendSvc = SortBackendService(viewId: viewId),
        _sortsListener = SortsListener(viewId: viewId),
        _fieldSettingsListener = FieldSettingsListener(viewId: viewId),
        _fieldSettingsBackendSvc = FieldSettingsBackendService(viewId: viewId) {
    // 启动所有监听器
    _listenOnFieldChanges();     // 监听字段变化
    _listenOnSettingChanges();   // 监听设置变化
    _listenOnFilterChanges();    // 监听过滤器变化
    _listenOnSortChanged();      // 监听排序变化
    _listenOnFieldSettingsChanged(); // 监听字段设置变化
  }

  final String viewId;

  // Listeners
  final FieldsListener _fieldListener;
  final DatabaseSettingListener _settingListener;
  final FiltersListener _filtersListener;
  final SortsListener _sortsListener;
  final FieldSettingsListener _fieldSettingsListener;

  // FFI services
  final DatabaseViewBackendService _databaseViewBackendSvc;
  final FilterBackendService _filterBackendSvc;
  final SortBackendService _sortBackendSvc;
  final FieldSettingsBackendService _fieldSettingsBackendSvc;

  bool _isDisposed = false;

  // Field callbacks
  final Map<OnReceiveFields, VoidCallback> _fieldCallbacks = {};
  final _GridFieldNotifier _fieldNotifier = _GridFieldNotifier();

  // Field updated callbacks
  final Map<OnReceiveUpdateFields, void Function(List<FieldInfo>)>
      _updatedFieldCallbacks = {};

  // Filter callbacks
  final Map<OnReceiveFilters, VoidCallback> _filterCallbacks = {};
  _GridFilterNotifier? _filterNotifier = _GridFilterNotifier();

  // Sort callbacks
  final Map<OnReceiveSorts, VoidCallback> _sortCallbacks = {};
  _GridSortNotifier? _sortNotifier = _GridSortNotifier();

  // Database settings temporary storage
  final Map<String, GroupSettingPB> _groupConfigurationByFieldId = {};
  final List<FieldSettingsPB> _fieldSettings = [];

  // Getters
  List<FieldInfo> get fieldInfos => [..._fieldNotifier.fieldInfos];
  List<DatabaseFilter> get filters => [..._filterNotifier?.filters ?? []];
  List<DatabaseSort> get sorts => [..._sortNotifier?.sorts ?? []];
  List<GroupSettingPB> get groupSettings =>
      _groupConfigurationByFieldId.entries.map((e) => e.value).toList();

  FieldInfo? getField(String fieldId) {
    return _fieldNotifier.fieldInfos
        .firstWhereOrNull((element) => element.id == fieldId);
  }

  DatabaseFilter? getFilterByFilterId(String filterId) {
    return _filterNotifier?.filters
        .firstWhereOrNull((element) => element.filterId == filterId);
  }

  DatabaseFilter? getFilterByFieldId(String fieldId) {
    return _filterNotifier?.filters
        .firstWhereOrNull((element) => element.fieldId == fieldId);
  }

  DatabaseSort? getSortBySortId(String sortId) {
    return _sortNotifier?.sorts
        .firstWhereOrNull((element) => element.sortId == sortId);
  }

  DatabaseSort? getSortByFieldId(String fieldId) {
    return _sortNotifier?.sorts
        .firstWhereOrNull((element) => element.fieldId == fieldId);
  }

  /*
   * 监听过滤器变化
   * 
   * 功能：
   * 监听后端过滤器的变化，实时更新过滤条件
   * 过滤器变化会影响数据的显示，需要重新计算可见行
   * 
   * 处理流程：
   * 1. 接收后端的过滤器变更通知
   * 2. 更新本地过滤器列表
   * 3. 更新字段信息（标记哪些字段有过滤器）
   * 4. 通知监听者重新渲染
   */
  void _listenOnFilterChanges() {
    _filtersListener.start(
      onFilterChanged: (result) {
        if (_isDisposed) {
          return;
        }

        result.fold(
          (FilterChangesetNotificationPB changeset) {
            _filterNotifier?.filters =
                _filterListFromPBs(changeset.filters.items);
            _fieldNotifier.fieldInfos =
                _updateFieldInfos(_fieldNotifier.fieldInfos);
          },
          (err) => Log.error(err),
        );
      },
    );
  }

  /*
   * 监听排序变化
   * 
   * 功能：
   * 监听后端排序规则的变化，支持多级排序
   * 
   * 排序变更类型：
   * - 删除排序：移除某个字段的排序
   * - 插入排序：添加新的排序规则
   * - 更新排序：修改排序方向（升序/降序）
   * 
   * 处理策略：
   * 1. 批量处理变更，减少重排次数
   * 2. 维护排序优先级顺序
   * 3. 更新字段的排序标记
   */
  void _listenOnSortChanged() {
    // 内部函数：处理删除的排序
    void deleteSortFromChangeset(
      List<DatabaseSort> newDatabaseSorts,
      SortChangesetNotificationPB changeset,
    ) {
      // 提取所有要删除的排序 ID
      final deleteSortIds = changeset.deleteSorts.map((e) => e.id).toList();
      if (deleteSortIds.isNotEmpty) {
        // 保留不在删除列表中的排序
        newDatabaseSorts.retainWhere(
          (element) => !deleteSortIds.contains(element.sortId),
        );
      }
    }

    // 内部函数：处理新增的排序
    void insertSortFromChangeset(
      List<DatabaseSort> newDatabaseSorts,
      SortChangesetNotificationPB changeset,
    ) {
      for (final newSortPB in changeset.insertSorts) {
        // 检查排序是否已存在
        final sortIndex = newDatabaseSorts
            .indexWhere((element) => element.sortId == newSortPB.sort.id);
        if (sortIndex == -1) {
          // 不存在则在指定位置插入新排序
          newDatabaseSorts.insert(
            newSortPB.index,
            DatabaseSort.fromPB(newSortPB.sort),
          );
        }
      }
    }

    // 内部函数：处理更新的排序
    void updateSortFromChangeset(
      List<DatabaseSort> newDatabaseSorts,
      SortChangesetNotificationPB changeset,
    ) {
      for (final updatedSort in changeset.updateSorts) {
        // 创建新的排序对象
        final newDatabaseSort = DatabaseSort.fromPB(updatedSort);

        // 查找现有排序的位置
        final sortIndex = newDatabaseSorts.indexWhere(
          (element) => element.sortId == updatedSort.id,
        );

        if (sortIndex != -1) {
          // 找到则替换，保持位置不变
          newDatabaseSorts.removeAt(sortIndex);
          newDatabaseSorts.insert(sortIndex, newDatabaseSort);
        } else {
          // 没找到则添加到末尾
          newDatabaseSorts.add(newDatabaseSort);
        }
      }
    }

    // 内部函数：更新受影响字段的排序标记
    void updateFieldInfos(
      List<DatabaseSort> newDatabaseSorts,
      SortChangesetNotificationPB changeset,
    ) {
      // 收集所有受影响的字段 ID
      final changedFieldIds = HashSet<String>.from([
        ...changeset.insertSorts.map((sort) => sort.sort.fieldId),
        ...changeset.updateSorts.map((sort) => sort.fieldId),
        ...changeset.deleteSorts.map((sort) => sort.fieldId),
        ...?_sortNotifier?.sorts.map((sort) => sort.fieldId),
      ]);

      // 创建字段信息副本
      final newFieldInfos = [...fieldInfos];

      // 遍历所有受影响的字段
      for (final fieldId in changedFieldIds) {
        final index =
            newFieldInfos.indexWhere((fieldInfo) => fieldInfo.id == fieldId);
        if (index == -1) {
          continue;  // 字段不存在，跳过
        }
        // 更新字段的 hasSort 标记
        newFieldInfos[index] = newFieldInfos[index].copyWith(
          hasSort: newDatabaseSorts.any((sort) => sort.fieldId == fieldId),
        );
      }

      // 通知字段信息变化
      _fieldNotifier.fieldInfos = newFieldInfos;
    }

    // 启动排序监听器
    _sortsListener.start(
      onSortChanged: (result) {
        if (_isDisposed) {
          return;  // 已释放则直接返回
        }
        result.fold(
          (SortChangesetNotificationPB changeset) {
            // 获取当前排序列表的副本
            final List<DatabaseSort> newDatabaseSorts = sorts;
            // 按顺序处理变化：删除 -> 插入 -> 更新
            deleteSortFromChangeset(newDatabaseSorts, changeset);
            insertSortFromChangeset(newDatabaseSorts, changeset);
            updateSortFromChangeset(newDatabaseSorts, changeset);

            // 更新受影响字段的标记并通知变化
            updateFieldInfos(newDatabaseSorts, changeset);
            _sortNotifier?.sorts = newDatabaseSorts;
          },
          (err) => Log.error(err),
        );
      },
    );
  }

  /*
   * 监听数据库设置变化
   * 
   * 包含内容：
   * - 分组设置：按哪个字段分组
   * - 过滤器设置：全局过滤条件
   * - 排序设置：默认排序规则
   * - 字段设置：字段的显示配置
   * 
   * 触发时机：
   * - 用户修改视图设置
   * - 切换视图布局
   * - 导入外部配置
   */
  void _listenOnSettingChanges() {
    _settingListener.start(
      onSettingUpdated: (result) {
        if (_isDisposed) {
          return;
        }

        result.fold(
          (setting) => _updateSetting(setting),
          (r) => Log.error(r),
        );
      },
    );
  }

  /*
   * 监听字段变化
   * 
   * 这是最核心的监听器，处理所有字段结构的变化。
   * 
   * 变化类型：
   * 1. 删除字段：移除字段及其所有数据
   * 2. 插入字段：添加新字段到指定位置
   * 3. 更新字段：修改字段类型、名称、配置等
   * 
   * 附加处理：
   * - 自动加载字段设置
   * - 通知已更新的字段给监听者
   * - 维护字段顺序
   * 
   * 性能考虑：
   * - 使用异步加载字段设置
   * - 批量处理多个字段变更
   * - 只通知真正变化的字段
   */
  void _listenOnFieldChanges() {
    Future<FieldInfo> attachFieldSettings(FieldInfo fieldInfo) async {
      return _fieldSettingsBackendSvc
          .getFieldSettings(fieldInfo.id)
          .then((result) {
        final fieldSettings = result.fold(
          (fieldSettings) => fieldSettings,
          (err) => null,
        );
        if (fieldSettings == null) {
          return fieldInfo;
        }
        final updatedFieldInfo =
            fieldInfo.copyWith(fieldSettings: fieldSettings);

        final index = _fieldSettings
            .indexWhere((element) => element.fieldId == fieldInfo.id);
        if (index != -1) {
          _fieldSettings.removeAt(index);
        }
        _fieldSettings.add(fieldSettings);

        return updatedFieldInfo;
      });
    }

    List<FieldInfo> deleteFields(List<FieldIdPB> deletedFields) {
      if (deletedFields.isEmpty) {
        return fieldInfos;
      }
      final List<FieldInfo> newFields = fieldInfos;
      final Map<String, FieldIdPB> deletedFieldMap = {
        for (final fieldOrder in deletedFields) fieldOrder.fieldId: fieldOrder,
      };

      newFields.retainWhere((field) => deletedFieldMap[field.id] == null);
      return newFields;
    }

    Future<List<FieldInfo>> insertFields(
      List<IndexFieldPB> insertedFields,
      List<FieldInfo> fieldInfos,
    ) async {
      if (insertedFields.isEmpty) {
        return fieldInfos;
      }
      final List<FieldInfo> newFieldInfos = fieldInfos;
      for (final indexField in insertedFields) {
        final initial = FieldInfo.initial(indexField.field_1);
        final fieldInfo = await attachFieldSettings(initial);
        if (newFieldInfos.length > indexField.index) {
          newFieldInfos.insert(indexField.index, fieldInfo);
        } else {
          newFieldInfos.add(fieldInfo);
        }
      }
      return newFieldInfos;
    }

    Future<(List<FieldInfo>, List<FieldInfo>)> updateFields(
      List<FieldPB> updatedFieldPBs,
      List<FieldInfo> fieldInfos,
    ) async {
      if (updatedFieldPBs.isEmpty) {
        return (<FieldInfo>[], fieldInfos);
      }

      final List<FieldInfo> newFieldInfo = fieldInfos;
      final List<FieldInfo> updatedFields = [];
      for (final updatedFieldPB in updatedFieldPBs) {
        final index =
            newFieldInfo.indexWhere((field) => field.id == updatedFieldPB.id);
        if (index != -1) {
          newFieldInfo.removeAt(index);
          final initial = FieldInfo.initial(updatedFieldPB);
          final fieldInfo = await attachFieldSettings(initial);
          newFieldInfo.insert(index, fieldInfo);
          updatedFields.add(fieldInfo);
        }
      }

      return (updatedFields, newFieldInfo);
    }

    // Listen on field's changes
    _fieldListener.start(
      onFieldsChanged: (result) async {
        result.fold(
          (changeset) async {
            if (_isDisposed) {
              return;
            }
            List<FieldInfo> updatedFields;
            List<FieldInfo> fieldInfos = deleteFields(changeset.deletedFields);
            fieldInfos =
                await insertFields(changeset.insertedFields, fieldInfos);
            (updatedFields, fieldInfos) =
                await updateFields(changeset.updatedFields, fieldInfos);

            _fieldNotifier.fieldInfos = _updateFieldInfos(fieldInfos);
            for (final listener in _updatedFieldCallbacks.values) {
              listener(updatedFields);
            }
          },
          (err) => Log.error(err),
        );
      },
    );
  }

  /*
   * 监听字段设置变化
   * 
   * 字段设置包括：
   * - 可见性：是否在视图中显示
   * - 宽度：列宽（表格视图）
   * - 格式：数字格式、日期格式等
   * - 包装：文本是否换行
   * 
   * 设置的作用域：
   * 字段设置是视图级别的，同一个字段在不同视图可以有不同设置
   */
  void _listenOnFieldSettingsChanged() {
    FieldInfo? updateFieldSettings(FieldSettingsPB updatedFieldSettings) {
      final newFields = [...fieldInfos];

      if (newFields.isEmpty) {
        return null;
      }

      final index = newFields
          .indexWhere((field) => field.id == updatedFieldSettings.fieldId);

      if (index != -1) {
        newFields[index] =
            newFields[index].copyWith(fieldSettings: updatedFieldSettings);
        _fieldNotifier.fieldInfos = newFields;
        _fieldSettings
          ..removeWhere(
            (field) => field.fieldId == updatedFieldSettings.fieldId,
          )
          ..add(updatedFieldSettings);
        return newFields[index];
      }

      return null;
    }

    _fieldSettingsListener.start(
      onFieldSettingsChanged: (result) {
        if (_isDisposed) {
          return;
        }
        result.fold(
          (fieldSettings) {
            final updatedFieldInfo = updateFieldSettings(fieldSettings);
            if (updatedFieldInfo == null) {
              return;
            }

            for (final listener in _updatedFieldCallbacks.values) {
              listener([updatedFieldInfo]);
            }
          },
          (err) => Log.error(err),
        );
      },
    );
  }

  /*
   * 更新数据库视图设置
   * 
   * 这是一个中心化的设置更新方法，统一处理所有设置变化。
   * 
   * 更新内容：
   * 1. 分组配置：清空旧配置，应用新的分组设置
   * 2. 过滤器：更新过滤条件列表
   * 3. 排序规则：更新排序列表
   * 4. 字段设置：更新所有字段的个性化设置
   * 
   * 执行顺序很重要，确保依赖关系正确
   */
  void _updateSetting(DatabaseViewSettingPB setting) {
    _groupConfigurationByFieldId.clear();
    for (final configuration in setting.groupSettings.items) {
      _groupConfigurationByFieldId[configuration.fieldId] = configuration;
    }

    _filterNotifier?.filters = _filterListFromPBs(setting.filters.items);

    _sortNotifier?.sorts = _sortListFromPBs(setting.sorts.items);

    _fieldSettings.clear();
    _fieldSettings.addAll(setting.fieldSettings.items);

    _fieldNotifier.fieldInfos = _updateFieldInfos(_fieldNotifier.fieldInfos);
  }

  /*
   * 更新字段信息
   * 
   * 为每个字段附加额外的状态信息：
   * - fieldSettings：字段的视图级设置
   * - isGroupField：是否是分组字段
   * - hasFilter：是否有过滤器
   * - hasSort：是否有排序
   * 
   * 这些标记用于 UI 显示（如显示排序/过滤图标）
   */
  List<FieldInfo> _updateFieldInfos(List<FieldInfo> fieldInfos) {
    return fieldInfos
        .map(
          (field) => field.copyWith(
            fieldSettings: _fieldSettings
                .firstWhereOrNull((setting) => setting.fieldId == field.id),
            isGroupField: _groupConfigurationByFieldId[field.id] != null,
            hasFilter: getFilterByFieldId(field.id) != null,
            hasSort: getSortByFieldId(field.id) != null,
          ),
        )
        .toList();
  }

  /*
   * 加载所有字段
   * 
   * 这是打开数据库时的必要步骤，必须在其他操作之前完成。
   * 
   * 加载流程：
   * 1. 从后端获取字段列表
   * 2. 创建 FieldInfo 对象
   * 3. 并行加载相关设置：
   *    - 过滤器配置
   *    - 排序规则
   *    - 字段设置
   *    - 全局设置
   * 4. 合并所有信息到字段对象
   * 
   * 错误处理：
   * 任何步骤失败都会返回错误，避免不完整的初始化
   */
  Future<FlowyResult<void, FlowyError>> loadFields({
    required List<FieldIdPB> fieldIds,
  }) async {
    final result = await _databaseViewBackendSvc.getFields(fieldIds: fieldIds);
    return Future(
      () => result.fold(
        (newFields) async {
          if (_isDisposed) {
            return FlowyResult.success(null);
          }

          _fieldNotifier.fieldInfos =
              newFields.map((field) => FieldInfo.initial(field)).toList();
          await Future.wait([
            _loadFilters(),
            _loadSorts(),
            _loadAllFieldSettings(),
            _loadSettings(),
          ]);
          _fieldNotifier.fieldInfos =
              _updateFieldInfos(_fieldNotifier.fieldInfos);

          return FlowyResult.success(null);
        },
        (err) => FlowyResult.failure(err),
      ),
    );
  }

  /*
   * 加载所有过滤器
   * 
   * 从后端获取当前视图的所有过滤器配置
   * 这是字段加载流程的一部分
   */
  Future<FlowyResult<void, FlowyError>> _loadFilters() async {
    return _filterBackendSvc.getAllFilters().then((result) {
      return result.fold(
        (filterPBs) {
          _filterNotifier?.filters = _filterListFromPBs(filterPBs);
          return FlowyResult.success(null);
        },
        (err) => FlowyResult.failure(err),
      );
    });
  }

  /*
   * 加载所有排序规则
   * 
   * 从后端获取当前视图的排序配置
   * 支持多级排序，按优先级顺序应用
   */
  Future<FlowyResult<void, FlowyError>> _loadSorts() async {
    return _sortBackendSvc.getAllSorts().then((result) {
      return result.fold(
        (sortPBs) {
          _sortNotifier?.sorts = _sortListFromPBs(sortPBs);
          return FlowyResult.success(null);
        },
        (err) => FlowyResult.failure(err),
      );
    });
  }

  /*
   * 加载所有字段设置
   * 
   * 获取每个字段的个性化设置
   * 这些设置是视图级别的，不同视图可以有不同配置
   */
  Future<FlowyResult<void, FlowyError>> _loadAllFieldSettings() async {
    return _fieldSettingsBackendSvc.getAllFieldSettings().then((result) {
      return result.fold(
        (fieldSettingsList) {
          _fieldSettings.clear();
          _fieldSettings.addAll(fieldSettingsList);
          return FlowyResult.success(null);
        },
        (err) => FlowyResult.failure(err),
      );
    });
  }

  Future<FlowyResult<void, FlowyError>> _loadSettings() async {
    return SettingBackendService(viewId: viewId).getSetting().then(
          (result) => result.fold(
            (setting) {
              _groupConfigurationByFieldId.clear();
              for (final configuration in setting.groupSettings.items) {
                _groupConfigurationByFieldId[configuration.fieldId] =
                    configuration;
              }
              return FlowyResult.success(null);
            },
            (err) => FlowyResult.failure(err),
          ),
        );
  }

  /*
   * 转换过滤器数据
   * 
   * 将后端的 FilterPB 转换为前端的 DatabaseFilter 对象
   * 便于在 UI 层使用
   */
  List<DatabaseFilter> _filterListFromPBs(List<FilterPB> filterPBs) {
    return filterPBs.map(DatabaseFilter.fromPB).toList();
  }

  /*
   * 转换排序数据
   * 
   * 将后端的 SortPB 转换为前端的 DatabaseSort 对象
   * 包含排序字段和排序方向信息
   */
  List<DatabaseSort> _sortListFromPBs(List<SortPB> sortPBs) {
    return sortPBs.map(DatabaseSort.fromPB).toList();
  }

  /*
   * 添加监听器
   * 
   * 允许外部组件监听字段相关的变化事件。
   * 
   * 参数说明：
   * - onReceiveFields：监听字段列表变化
   * - onFieldsChanged：监听字段更新
   * - onFilters：监听过滤器变化
   * - onSorts：监听排序变化
   * - listenWhen：条件函数，返回 false 时跳过通知
   * 
   * 设计特点：
   * - 支持选择性监听，只监听需要的事件
   * - 条件监听，减少不必要的更新
   * - 自动管理回调生命周期
   */
  void addListener({
    OnReceiveFields? onReceiveFields,
    OnReceiveUpdateFields? onFieldsChanged,
    OnReceiveFilters? onFilters,
    OnReceiveSorts? onSorts,
    bool Function()? listenWhen,
  }) {
    if (onFieldsChanged != null) {
      void callback(List<FieldInfo> updateFields) {
        if (listenWhen != null && listenWhen() == false) {
          return;
        }
        onFieldsChanged(updateFields);
      }

      _updatedFieldCallbacks[onFieldsChanged] = callback;
    }

    if (onReceiveFields != null) {
      void callback() {
        if (listenWhen != null && listenWhen() == false) {
          return;
        }
        onReceiveFields(fieldInfos);
      }

      _fieldCallbacks[onReceiveFields] = callback;
      _fieldNotifier.addListener(callback);
    }

    if (onFilters != null) {
      void callback() {
        if (listenWhen != null && listenWhen() == false) {
          return;
        }
        onFilters(filters);
      }

      _filterCallbacks[onFilters] = callback;
      _filterNotifier?.addListener(callback);
    }

    if (onSorts != null) {
      void callback() {
        if (listenWhen != null && listenWhen() == false) {
          return;
        }
        onSorts(sorts);
      }

      _sortCallbacks[onSorts] = callback;
      _sortNotifier?.addListener(callback);
    }
  }

  /*
   * 添加单字段监听器
   * 
   * 用于监听特定字段的变化，适合只关心某个字段的场景。
   * 比如：单元格编辑器只需要监听对应字段的变化。
   * 
   * 优势：
   * - 减少不必要的通知
   * - 提高性能
   * - 简化逻辑
   */
  void addSingleFieldListener(
    String fieldId, {
    required OnReceiveField onFieldChanged,
    bool Function()? listenWhen,
  }) {
    void key(List<FieldInfo> fieldInfos) {
      final fieldInfo = fieldInfos.firstWhereOrNull(
        (fieldInfo) => fieldInfo.id == fieldId,
      );
      if (fieldInfo != null) {
        onFieldChanged(fieldInfo);
      }
    }

    void callback() {
      if (listenWhen != null && listenWhen() == false) {
        return;
      }
      key(fieldInfos);
    }

    _fieldCallbacks[key] = callback;
    _fieldNotifier.addListener(callback);
  }

  void removeListener({
    OnReceiveFields? onFieldsListener,
    OnReceiveSorts? onSortsListener,
    OnReceiveFilters? onFiltersListener,
    OnReceiveUpdateFields? onChangesetListener,
  }) {
    if (onFieldsListener != null) {
      final callback = _fieldCallbacks.remove(onFieldsListener);
      if (callback != null) {
        _fieldNotifier.removeListener(callback);
      }
    }
    if (onFiltersListener != null) {
      final callback = _filterCallbacks.remove(onFiltersListener);
      if (callback != null) {
        _filterNotifier?.removeListener(callback);
      }
    }

    if (onSortsListener != null) {
      final callback = _sortCallbacks.remove(onSortsListener);
      if (callback != null) {
        _sortNotifier?.removeListener(callback);
      }
    }
  }

  void removeSingleFieldListener({
    required String fieldId,
    required OnReceiveField onFieldChanged,
  }) {
    void key(List<FieldInfo> fieldInfos) {
      final fieldInfo = fieldInfos.firstWhereOrNull(
        (fieldInfo) => fieldInfo.id == fieldId,
      );
      if (fieldInfo != null) {
        onFieldChanged(fieldInfo);
      }
    }

    final callback = _fieldCallbacks.remove(key);
    if (callback != null) {
      _fieldNotifier.removeListener(callback);
    }
  }

  /*
   * 释放资源
   * 
   * 清理顺序：
   * 1. 停止所有监听器，断开与后端的连接
   * 2. 移除所有回调，避免内存泄漏
   * 3. 释放通知器资源
   * 
   * 注意：
   * - 设置 _isDisposed 标记防止异步操作继续执行
   * - 确保所有监听器都正确停止
   * - 清理所有回调引用
   */
  Future<void> dispose() async {
    if (_isDisposed) {
      Log.warn('FieldController is already disposed');
      return;
    }
    _isDisposed = true;
    await _fieldListener.stop();
    await _filtersListener.stop();
    await _settingListener.stop();
    await _sortsListener.stop();
    await _fieldSettingsListener.stop();

    for (final callback in _fieldCallbacks.values) {
      _fieldNotifier.removeListener(callback);
    }
    _fieldNotifier.dispose();

    for (final callback in _filterCallbacks.values) {
      _filterNotifier?.removeListener(callback);
    }
    _filterNotifier?.dispose();
    _filterNotifier = null;

    for (final callback in _sortCallbacks.values) {
      _sortNotifier?.removeListener(callback);
    }
    _sortNotifier?.dispose();
    _sortNotifier = null;
  }
}

/*
 * 行缓存依赖实现
 * 
 * 作用：
 * 为 RowCache 提供字段信息的访问接口。
 * 实现了字段委托和行生命周期管理。
 * 
 * 设计模式：
 * - 委托模式：将字段访问委托给 FieldController
 * - 生命周期管理：确保资源正确释放
 */
class RowCacheDependenciesImpl extends RowFieldsDelegate with RowLifeCycle {
  RowCacheDependenciesImpl(FieldController cache) : _fieldController = cache;

  final FieldController _fieldController;
  OnReceiveFields? _onFieldFn;

  @override
  UnmodifiableListView<FieldInfo> get fieldInfos =>
      UnmodifiableListView(_fieldController.fieldInfos);

  @override
  void onFieldsChanged(void Function(List<FieldInfo>) callback) {
    if (_onFieldFn != null) {
      _fieldController.removeListener(onFieldsListener: _onFieldFn!);
    }

    _onFieldFn = (fieldInfos) => callback(fieldInfos);
    _fieldController.addListener(onReceiveFields: _onFieldFn);
  }

  @override
  void onRowDisposed() {
    if (_onFieldFn != null) {
      _fieldController.removeListener(onFieldsListener: _onFieldFn!);
      _onFieldFn = null;
    }
  }
}
