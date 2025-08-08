/*
 * AppFlowy 数据库系统架构文档
 * 
 * 设计理念：
 * AppFlowy 的数据库系统采用 MVC 架构，实现了类似 Notion Database 的功能。
 * 核心思想是将数据与视图分离，同一份数据可以有多种展示形式（表格、看板、日历等）。
 * 
 * 架构分层：
 * 1. 后端层（Rust）：负责数据持久化、业务逻辑处理
 * 2. 控制器层（Flutter）：管理数据流转、状态同步
 * 3. 视图层（Flutter）：负责 UI 渲染和用户交互
 * 
 * 核心组件：
 * - DatabaseController：数据库总控制器，协调各个子系统
 * - FieldController：字段（列）管理器，处理字段的增删改
 * - RowController：行管理器，处理行数据的操作
 * - CellController：单元格控制器，管理单个单元格的数据
 * 
 * 数据流：
 * 用户操作 -> Controller -> Backend Service (FFI) -> Rust Backend
 * Backend 变化 -> Listener -> Controller -> UI 更新
 * 
 * 缓存策略：
 * - ViewCache：视图级缓存，存储当前视图的所有数据
 * - RowCache：行级缓存，优化行数据的访问
 * - CellMemCache：单元格缓存，减少重复数据加载
 * 
 * 监听机制：
 * 使用观察者模式，通过 Listener 监听后端数据变化，
 * 支持多个监听者同时监听同一事件，实现实时同步。
 */

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

/*
 * 分组功能回调定义
 * 
 * 分组是数据库视图的重要特性，允许用户按某个字段对数据进行分类展示。
 * 例如：在看板视图中，每个列就是一个分组。
 */

/// 分组配置变化回调
/// 当分组的设置发生变化时触发（如分组字段、分组条件等）
typedef OnGroupConfigurationChanged = void Function(List<GroupSettingPB>);

/// 按字段分组回调
/// 当选择新的字段进行分组时触发
typedef OnGroupByField = void Function(List<GroupPB>);

/// 更新分组回调
/// 当已有分组的内容发生变化时触发
typedef OnUpdateGroup = void Function(List<GroupPB>);

/// 删除分组回调
/// 当分组被删除时触发
typedef OnDeleteGroup = void Function(List<String>);

/// 插入分组回调
/// 当新增分组时触发
typedef OnInsertGroup = void Function(InsertedGroupPB);

/*
 * 分组回调集合
 * 
 * 设计目的：
 * 将所有分组相关的回调封装在一起，便于管理和传递。
 * 使用可选参数设计，调用者只需要监听感兴趣的事件。
 * 
 * 使用场景：
 * - 看板视图：监听分组变化来更新列
 * - 表格视图：监听分组设置来显示分组行
 */
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

/*
 * 数据库布局设置回调
 * 
 * 功能说明：
 * 每种视图布局（表格、看板、日历）都有独特的设置项。
 * 例如：
 * - 看板：卡片显示哪些字段、是否显示封面等
 * - 日历：首日是周一还是周日、时间格式等
 * - 表格：行高、是否显示网格线等
 */
class DatabaseLayoutSettingCallbacks {
  DatabaseLayoutSettingCallbacks({
    required this.onLayoutSettingsChanged,  // 布局设置变化回调
  });

  final void Function(DatabaseLayoutSettingPB) onLayoutSettingsChanged;
}

/*
 * 数据库核心回调集合
 * 
 * 设计理念：
 * 采用细粒度的事件通知机制，让监听者可以精确地响应特定变化。
 * 避免全量刷新，提高性能和用户体验。
 * 
 * 事件类型说明：
 * - onDatabaseChanged：数据库元信息变化（如名称、描述等）
 * - onNumOfRowsChanged：行数变化（用于更新统计信息）
 * - onFieldsChanged：字段结构变化（新增、删除、修改字段）
 * - onFiltersChanged：过滤条件变化（影响数据显示）
 * - onSortsChanged：排序规则变化（影响数据顺序）
 * - onRowsUpdated：行内容更新（单元格数据变化）
 * - onRowsDeleted：行被删除
 * - onRowsCreated：新增行
 */
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

/*
 * 数据库控制器 - 数据库系统的核心
 * 
 * 职责定位：
 * DatabaseController 是整个数据库系统的中枢，负责协调各个子系统的工作。
 * 它不直接处理具体的业务逻辑，而是作为协调者，将任务分发给专门的控制器。
 * 
 * 核心功能：
 * 1. 视图管理：支持表格、看板、日历等多种视图模式
 * 2. 数据操作：通过 RowCache 管理行数据的增删改查
 * 3. 字段系统：通过 FieldController 管理字段结构
 * 4. 高级特性：分组、排序、过滤等数据组织功能
 * 5. 个性化：布局设置、紧凑模式等用户偏好
 * 
 * 设计模式：
 * - 观察者模式：通过回调集合支持多个监听者
 * - 门面模式：对外提供统一的接口，隐藏内部复杂性
 * - 依赖注入：通过构造函数注入所需的服务和控制器
 * 
 * 生命周期：
 * 创建 -> open() 初始化 -> 监听事件 -> 处理用户操作 -> dispose() 释放资源
 * 
 * 性能优化：
 * - 使用缓存减少后端调用
 * - 批量处理事件通知
 * - 懒加载数据
 */
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

  /*
   * 状态管理
   * 
   * 加载状态：用于显示加载动画，提升用户体验
   * 紧凑模式：允许用户选择信息密度，平衡信息量和可读性
   */
  /// 加载状态通知器
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  /// 紧凑模式通知器（控制视图显示密度）
  final ValueNotifier<bool> _compactMode = ValueNotifier(true);

  /// 设置加载状态
  void setIsLoading(bool isLoading) => _isLoading.value = isLoading;

  /// 获取加载状态通知器
  ValueNotifier<bool> get isLoading => _isLoading;

  /*
   * 设置紧凑模式
   * 
   * 紧凑模式会减少行高和间距，显示更多内容。
   * 适合需要浏览大量数据的场景。
   */
  void setCompactMode(bool compactMode) {
    _compactMode.value = compactMode;  // 更新内部状态
    // 通知所有监听者（使用 Set.of 创建副本，避免在遍历时修改集合）
    for (final callback in Set.of(_compactModeCallbacks)) {
      callback.call(compactMode);
    }
  }

  /// 获取紧凑模式通知器
  ValueNotifier<bool> get compactModeNotifier => _compactMode;

  /*
   * 添加监听器
   * 
   * 支持添加多种类型的监听器以监听不同的事件。
   * 使用可选参数设计，调用者只需要添加关心的监听器。
   */
  void addListener({
    DatabaseCallbacks? onDatabaseChanged,  // 数据库变化监听
    DatabaseLayoutSettingCallbacks? onLayoutSettingsChanged,  // 布局设置监听
    GroupCallbacks? onGroupChanged,  // 分组变化监听
    ValueChanged<bool>? onCompactModeChanged,  // 紧凑模式监听
  }) {
    // 根据参数添加对应的监听器到相应集合
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

  /*
   * 打开数据库
   * 
   * 初始化流程：
   * 1. 从后端加载数据库基本信息
   * 2. 加载字段定义（必须优先加载，因为行数据依赖字段）
   * 3. 初始化行缓存
   * 4. 加载分组设置（如果有）
   * 5. 加载布局特定设置
   * 
   * 错误处理：
   * 任何步骤失败都会返回错误，避免部分初始化状态
   */
  Future<FlowyResult<void, FlowyError>> open() async {
    return _databaseViewBackendSvc.openDatabase().then((result) {
      return result.fold(
        (DatabasePB database) async {
          // 保存布局类型
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
              // 设置初始行数据
              _viewCache.rowCache.setInitialRows(database.rows);
              // 异步加载分组和布局设置
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

  /*
   * 在分组之间移动行
   * 
   * 使用场景：
   * 主要用于看板视图，当用户拖动卡片到另一个列时调用。
   * 移动行会自动更新该行对应的分组字段值。
   * 
   * 参数说明：
   * - fromRow：要移动的行
   * - fromGroupId：源分组ID
   * - toGroupId：目标分组ID
   * - toRow：目标位置的参考行（可选，用于精确定位）
   */
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

  /*
   * 移动行位置
   * 
   * 用于在同一视图内调整行的顺序。
   * 通常用于用户手动拖动排序的场景。
   */
  Future<FlowyResult<void, FlowyError>> moveRow({
    required String fromRowId,  // 要移动的行ID
    required String toRowId,  // 目标位置ID
  }) {
    return _databaseViewBackendSvc.moveRow(
      fromRowId: fromRowId,
      toRowId: toRowId,
    );
  }

  /*
   * 移动分组位置
   * 
   * 用于调整分组顺序，比如看板视图中的列顺序。
   * 用户可以拖动分组标题来重新排列。
   */
  Future<FlowyResult<void, FlowyError>> moveGroup({
    required String fromGroupId,  // 要移动的分组ID
    required String toGroupId,  // 目标位置的分组ID
  }) {
    return _databaseViewBackendSvc.moveGroup(
      fromGroupId: fromGroupId,
      toGroupId: toGroupId,
    );
  }

  /*
   * 更新布局设置
   * 
   * 根据不同的视图类型更新对应的设置。
   * 每种视图都有自己特有的设置项。
   */
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

  /*
   * 释放资源
   * 
   * 清理顺序很重要：
   * 1. 先关闭后端连接，停止数据流
   * 2. 停止所有监听器，避免内存泄漏
   * 3. 清理缓存数据
   * 4. 清空回调集合
   * 5. 释放 ValueNotifier
   * 
   * 注意：必须确保所有异步操作完成后才能释放
   */
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
