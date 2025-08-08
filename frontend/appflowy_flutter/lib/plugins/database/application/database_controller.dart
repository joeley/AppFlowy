import 'dart:async';

import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/view/view_cache.dart';
import 'package:appflowy/plugins/database/domain/database_view_service.dart';
import 'package:appflowy/plugins/database/domain/group_listener.dart';
import 'package:appflowy/plugins/database/domain/layout_service.dart';
import 'package:appflowy/plugins/database/domain/layout_setting_listener.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'defines.dart';
import 'row/row_cache.dart';

/// 分组配置变化回调
typedef OnGroupConfigurationChanged = void Function(List<GroupSettingPB>);
/// 按字段分组回调
typedef OnGroupByField = void Function(List<GroupPB>);
/// 更新分组回调
typedef OnUpdateGroup = void Function(List<GroupPB>);
/// 删除分组回调
typedef OnDeleteGroup = void Function(List<String>);
/// 插入分组回调
typedef OnInsertGroup = void Function(InsertedGroupPB);

/// 分组相关的回调集合
/// 用于监听分组的各种变化事件
class GroupCallbacks {
  GroupCallbacks({
    this.onGroupConfigurationChanged,  // 分组配置变化
    this.onGroupByField,  // 按字段分组
    this.onUpdateGroup,  // 分组更新
    this.onDeleteGroup,  // 分组删除
    this.onInsertGroup,  // 分组插入
  });

  final OnGroupConfigurationChanged? onGroupConfigurationChanged;
  final OnGroupByField? onGroupByField;
  final OnUpdateGroup? onUpdateGroup;
  final OnDeleteGroup? onDeleteGroup;
  final OnInsertGroup? onInsertGroup;
}

/// 数据库布局设置回调
/// 监听布局设置的变化（如看板布局、日历设置等）
class DatabaseLayoutSettingCallbacks {
  DatabaseLayoutSettingCallbacks({
    required this.onLayoutSettingsChanged,  // 布局设置变化回调
  });

  final void Function(DatabaseLayoutSettingPB) onLayoutSettingsChanged;
}

/// 数据库核心回调集合
/// 管理数据库的所有状态变化事件
class DatabaseCallbacks {
  DatabaseCallbacks({
    this.onDatabaseChanged,  // 数据库变化
    this.onNumOfRowsChanged,  // 行数变化
    this.onFieldsChanged,  // 字段变化
    this.onFiltersChanged,  // 过滤器变化
    this.onSortsChanged,  // 排序变化
    this.onRowsUpdated,  // 行更新
    this.onRowsDeleted,  // 行删除
    this.onRowsCreated,  // 行创建
  });

  OnDatabaseChanged? onDatabaseChanged;
  OnFieldsChanged? onFieldsChanged;
  OnFiltersChanged? onFiltersChanged;
  OnSortsChanged? onSortsChanged;
  OnNumOfRowsChanged? onNumOfRowsChanged;
  OnRowsDeleted? onRowsDeleted;
  OnRowsUpdated? onRowsUpdated;
  OnRowsCreated? onRowsCreated;
}

/// 数据库控制器
/// 
/// AppFlowy数据库功能的核心控制器，管理：
/// 1. 视图模式切换（表格、看板、日历等）
/// 2. 数据的增删改查
/// 3. 字段管理和类型转换
/// 4. 分组、排序、过滤等高级功能
/// 5. 布局设置和个性化配置
/// 
/// 架构设计：
/// - 使用观察者模式监听数据变化
/// - 通过回调集合管理多个监听者
/// - 与后端服务通信获取和更新数据
class DatabaseController {
  DatabaseController({required this.view})
      : _databaseViewBackendSvc = DatabaseViewBackendService(viewId: view.id),  // 后端服务
        fieldController = FieldController(viewId: view.id),  // 字段控制器
        _groupListener = DatabaseGroupListener(view.id),  // 分组监听器
        databaseLayout = databaseLayoutFromViewLayout(view.layout),  // 布局类型
        _layoutListener = DatabaseLayoutSettingListener(view.id) {  // 布局监听器
    // 初始化视图缓存
    _viewCache = DatabaseViewCache(
      viewId: viewId,
      fieldController: fieldController,
    );

    // 设置各种监听器
    _listenOnRowsChanged();  // 监听行数据变化
    _listenOnFieldsChanged();  // 监听字段变化
    _listenOnGroupChanged();  // 监听分组变化
    _listenOnLayoutChanged();  // 监听布局变化
  }

  final ViewPB view;  // 视图对象
  final DatabaseViewBackendService _databaseViewBackendSvc;  // 后端服务接口
  final FieldController fieldController;  // 字段控制器
  DatabaseLayoutPB databaseLayout;  // 当前布局类型
  DatabaseLayoutSettingPB? databaseLayoutSetting;  // 布局设置
  late DatabaseViewCache _viewCache;  // 视图缓存

  // 回调集合 - 支持多个监听者
  final List<DatabaseCallbacks> _databaseCallbacks = [];  // 数据库回调
  final List<GroupCallbacks> _groupCallbacks = [];  // 分组回调
  final List<DatabaseLayoutSettingCallbacks> _layoutCallbacks = [];  // 布局回调
  final Set<ValueChanged<bool>> _compactModeCallbacks = {};  // 紧凑模式回调

  // Getters
  /// 获取行缓存
  RowCache get rowCache => _viewCache.rowCache;

  /// 获取视图 ID
  String get viewId => view.id;

  // 监听器
  final DatabaseGroupListener _groupListener;  // 分组监听器
  final DatabaseLayoutSettingListener _layoutListener;  // 布局设置监听器

  /// 加载状态通知器
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  /// 紧凑模式通知器（控制视图显示密度）
  final ValueNotifier<bool> _compactMode = ValueNotifier(true);

  /// 设置加载状态
  void setIsLoading(bool isLoading) => _isLoading.value = isLoading;

  /// 获取加载状态通知器
  ValueNotifier<bool> get isLoading => _isLoading;

  /// 设置紧凑模式
  /// 紧凑模式会减少行高和间距，显示更多内容
  void setCompactMode(bool compactMode) {
    _compactMode.value = compactMode;
    // 通知所有监听者
    for (final callback in Set.of(_compactModeCallbacks)) {
      callback.call(compactMode);
    }
  }

  /// 获取紧凑模式通知器
  ValueNotifier<bool> get compactModeNotifier => _compactMode;

  /// 添加监听器
  /// 支持添加多种类型的监听器以监听不同的事件
  void addListener({
    DatabaseCallbacks? onDatabaseChanged,  // 数据库变化监听
    DatabaseLayoutSettingCallbacks? onLayoutSettingsChanged,  // 布局设置监听
    GroupCallbacks? onGroupChanged,  // 分组变化监听
    ValueChanged<bool>? onCompactModeChanged,  // 紧凑模式监听
  }) {
    if (onLayoutSettingsChanged != null) {
      _layoutCallbacks.add(onLayoutSettingsChanged);
    }

    if (onDatabaseChanged != null) {
      _databaseCallbacks.add(onDatabaseChanged);
    }

    if (onGroupChanged != null) {
      _groupCallbacks.add(onGroupChanged);
    }

    if (onCompactModeChanged != null) {
      _compactModeCallbacks.add(onCompactModeChanged);
    }
  }

  /// 移除监听器
  /// 移除之前添加的监听器
  void removeListener({
    DatabaseCallbacks? onDatabaseChanged,
    DatabaseLayoutSettingCallbacks? onLayoutSettingsChanged,
    GroupCallbacks? onGroupChanged,
    ValueChanged<bool>? onCompactModeChanged,
  }) {
    if (onDatabaseChanged != null) {
      _databaseCallbacks.remove(onDatabaseChanged);
    }

    if (onLayoutSettingsChanged != null) {
      _layoutCallbacks.remove(onLayoutSettingsChanged);
    }

    if (onGroupChanged != null) {
      _groupCallbacks.remove(onGroupChanged);
    }

    if (onCompactModeChanged != null) {
      _compactModeCallbacks.remove(onCompactModeChanged);
    }
  }

  /// 打开数据库
  /// 加载数据库数据、字段、分组和布局设置
  Future<FlowyResult<void, FlowyError>> open() async {
    return _databaseViewBackendSvc.openDatabase().then((result) {
      return result.fold(
        (DatabasePB database) async {
          databaseLayout = database.layoutType;

          // 加载实际的数据库字段数据
          final fieldsOrFail = await fieldController.loadFields(
            fieldIds: database.fields,
          );
          return fieldsOrFail.fold(
            (fields) {
              // 在字段加载完成后通知数据库变化
              // 数据库必须等字段加载完才能使用
              for (final callback in _databaseCallbacks) {
                callback.onDatabaseChanged?.call(database);
              }
              _viewCache.rowCache.setInitialRows(database.rows);
              return Future(() async {
                await _loadGroups();
                await _loadLayoutSetting();
                return FlowyResult.success(fields);
              });
            },
            (err) {
              Log.error(err);
              return FlowyResult.failure(err);
            },
          );
        },
        (err) => FlowyResult.failure(err),
      );
    });
  }

  /// 在分组之间移动行
  /// 用于看板视图中卡片在不同列之间的拖动
  Future<FlowyResult<void, FlowyError>> moveGroupRow({
    required RowMetaPB fromRow,  // 源行
    required String fromGroupId,  // 源分组ID
    required String toGroupId,  // 目标分组ID
    RowMetaPB? toRow,  // 目标位置的行（可选）
  }) {
    return _databaseViewBackendSvc.moveGroupRow(
      fromRowId: fromRow.id,
      fromGroupId: fromGroupId,
      toGroupId: toGroupId,
      toRowId: toRow?.id,
    );
  }

  /// 移动行位置
  /// 用于调整行的顺序
  Future<FlowyResult<void, FlowyError>> moveRow({
    required String fromRowId,  // 要移动的行ID
    required String toRowId,  // 目标位置ID
  }) {
    return _databaseViewBackendSvc.moveRow(
      fromRowId: fromRowId,
      toRowId: toRowId,
    );
  }

  /// 移动分组位置
  /// 用于调整分组顺序（如看板视图中的列顺序）
  Future<FlowyResult<void, FlowyError>> moveGroup({
    required String fromGroupId,  // 要移动的分组ID
    required String toGroupId,  // 目标位置的分组ID
  }) {
    return _databaseViewBackendSvc.moveGroup(
      fromGroupId: fromGroupId,
      toGroupId: toGroupId,
    );
  }

  /// 更新布局设置
  /// 根据不同的视图类型更新对应的设置
  Future<void> updateLayoutSetting({
    BoardLayoutSettingPB? boardLayoutSetting,  // 看板布局设置
    CalendarLayoutSettingPB? calendarLayoutSetting,  // 日历布局设置
  }) async {
    await _databaseViewBackendSvc
        .updateLayoutSetting(
      boardLayoutSetting: boardLayoutSetting,
      calendarLayoutSetting: calendarLayoutSetting,
      layoutType: databaseLayout,
    )
        .then((result) {
      result.fold((l) => null, (r) => Log.error(r));
    });
  }

  /// 释放资源
  /// 关闭视图、停止监听器、清理回调
  Future<void> dispose() async {
    await _databaseViewBackendSvc.closeView();
    await fieldController.dispose();
    await _groupListener.stop();
    await _viewCache.dispose();
    _databaseCallbacks.clear();
    _groupCallbacks.clear();
    _layoutCallbacks.clear();
    _compactModeCallbacks.clear();
    _isLoading.dispose();
  }

  /// 加载分组数据
  /// 从后端获取分组信息并通知监听者
  Future<void> _loadGroups() async {
    final groupsResult = await _databaseViewBackendSvc.loadGroups();
    groupsResult.fold(
      (groups) {
        for (final callback in _groupCallbacks) {
          callback.onGroupByField?.call(groups.items);
        }
      },
      (err) => Log.error(err),
    );
  }

  /// 加载布局设置
  /// 获取当前布局的个性化设置
  Future<void> _loadLayoutSetting() {
    return _databaseViewBackendSvc
        .getLayoutSetting(databaseLayout)
        .then((result) {
      result.fold(
        (newDatabaseLayoutSetting) {
          databaseLayoutSetting = newDatabaseLayoutSetting;

          for (final callback in _layoutCallbacks) {
            callback.onLayoutSettingsChanged(newDatabaseLayoutSetting);
          }
        },
        (r) => Log.error(r),
      );
    });
  }

  /// 监听行数据变化
  /// 设置行的增删改监听器
  void _listenOnRowsChanged() {
    final callbacks = DatabaseViewCallbacks(
      onNumOfRowsChanged: (rows, rowByRowId, reason) {
        for (final callback in _databaseCallbacks) {
          callback.onNumOfRowsChanged?.call(rows, rowByRowId, reason);
        }
      },
      onRowsDeleted: (ids) {
        for (final callback in _databaseCallbacks) {
          callback.onRowsDeleted?.call(ids);
        }
      },
      onRowsUpdated: (ids, reason) {
        for (final callback in _databaseCallbacks) {
          callback.onRowsUpdated?.call(ids, reason);
        }
      },
      onRowsCreated: (ids) {
        for (final callback in _databaseCallbacks) {
          callback.onRowsCreated?.call(ids);
        }
      },
    );
    _viewCache.addListener(callbacks);
  }

  /// 监听字段变化
  /// 设置字段、排序、过滤的监听器
  void _listenOnFieldsChanged() {
    fieldController.addListener(
      onReceiveFields: (fields) {
        for (final callback in _databaseCallbacks) {
          callback.onFieldsChanged?.call(UnmodifiableListView(fields));
        }
      },
      onSorts: (sorts) {
        for (final callback in _databaseCallbacks) {
          callback.onSortsChanged?.call(sorts);
        }
      },
      onFilters: (filters) {
        for (final callback in _databaseCallbacks) {
          callback.onFiltersChanged?.call(filters);
        }
      },
    );
  }

  /// 监听分组变化
  /// 处理分组的增删改事件
  void _listenOnGroupChanged() {
    _groupListener.start(
      onNumOfGroupsChanged: (result) {
        result.fold(
          (changeset) {
            if (changeset.updateGroups.isNotEmpty) {
              for (final callback in _groupCallbacks) {
                callback.onUpdateGroup?.call(changeset.updateGroups);
              }
            }

            if (changeset.deletedGroups.isNotEmpty) {
              for (final callback in _groupCallbacks) {
                callback.onDeleteGroup?.call(changeset.deletedGroups);
              }
            }

            for (final insertedGroup in changeset.insertedGroups) {
              for (final callback in _groupCallbacks) {
                callback.onInsertGroup?.call(insertedGroup);
              }
            }
          },
          (r) => Log.error(r),
        );
      },
      onGroupByNewField: (result) {
        result.fold(
          (groups) {
            for (final callback in _groupCallbacks) {
              callback.onGroupByField?.call(groups);
            }
          },
          (r) => Log.error(r),
        );
      },
    );
  }

  /// 监听布局变化
  /// 处理布局设置的更新
  void _listenOnLayoutChanged() {
    _layoutListener.start(
      onLayoutChanged: (result) {
        result.fold(
          (newLayout) {
            databaseLayoutSetting = newLayout;
            databaseLayoutSetting?.freeze();

            for (final callback in _layoutCallbacks) {
              callback.onLayoutSettingsChanged(newLayout);
            }
          },
          (r) => Log.error(r),
        );
      },
    );
  }

  /// 初始化紧凑模式
  /// 设置初始的紧凑模式状态
  void initCompactMode(bool enableCompactMode) {
    if (_compactMode.value != enableCompactMode) {
      _compactMode.value = enableCompactMode;
    }
  }
}
