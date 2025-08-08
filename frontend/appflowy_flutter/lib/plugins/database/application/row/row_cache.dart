/*
 * 行缓存 - 数据库行数据的集中管理
 * 
 * 设计理念：
 * RowCache 作为数据库视图中所有行数据的中心缓存，
 * 管理行的增删改查操作，并协调单元格缓存。
 * 
 * 核心功能：
 * 1. 行列表管理：维护有序的行列表
 * 2. 单元格缓存：管理所有单元格的数据缓存
 * 3. 变化通知：当行数据变化时通知观察者
 * 4. 可见性管理：处理行的显示/隐藏（过滤器影响）
 * 5. 排序支持：支持行的重新排序
 * 
 * 数据流：
 * 后端变化 -> RowsChangePB/RowsVisibilityChangePB -> RowCache -> UI更新
 * 
 * 性能优化：
 * - 使用 RowList 维护有序列表和快速查找
 * - 单元格数据缓存避免重复加载
 * - 批量处理变化减少UI更新
 * 
 * 架构说明：
 * 更多信息请参考: https://docs.appflowy.io/docs/documentation/software-contributions/architecture/frontend/frontend/grid
 */

import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../cell/cell_cache.dart';
import '../cell/cell_controller.dart';

import 'row_list.dart';
import 'row_service.dart';

part 'row_cache.freezed.dart';

typedef RowUpdateCallback = void Function();

/*
 * 行字段委托
 * 
 * 为行缓存提供字段信息的访问接口。
 * 通过委托模式解耦 RowCache 和 FieldController。
 */
abstract class RowFieldsDelegate {
  UnmodifiableListView<FieldInfo> get fieldInfos;
  void onFieldsChanged(void Function(List<FieldInfo>) callback);
}

/*
 * 行生命周期
 * 
 * 定义行释放时的回调接口。
 * 确保资源正确清理，避免内存泄漏。
 */
abstract mixin class RowLifeCycle {
  void onRowDisposed();
}

/*
 * 行缓存类
 * 
 * 这是数据库视图的核心缓存组件，管理所有行和单元格数据。
 * 
 * 主要组件：
 * - _rowList：维护行的有序列表
 * - _cellMemCache：存储所有单元格数据
 * - _changedNotifier：管理变化通知
 * 
 * 初始化逻辑：
 * 1. 创建各种缓存和通知器
 * 2. 监听字段变化，当字段被删除时清理对应单元格
 * 
 * 更多信息: https://docs.appflowy.io/docs/documentation/software-contributions/architecture/frontend/frontend/grid
 */
class RowCache {
  RowCache({
    required this.viewId,
    required RowFieldsDelegate fieldsDelegate,
    required RowLifeCycle rowLifeCycle,
  })  : _cellMemCache = CellMemCache(),
        _changedNotifier = RowChangesetNotifier(),
        _rowLifeCycle = rowLifeCycle,
        _fieldDelegate = fieldsDelegate {
    // 监听字段变化。如果字段被删除，我们可以安全地从缓存中
    // 移除对应的单元格数据
    fieldsDelegate.onFieldsChanged((fieldInfos) {
      for (final fieldInfo in fieldInfos) {
        _cellMemCache.removeCellWithFieldId(fieldInfo.id);
      }

      _changedNotifier?.receive(const ChangedReason.fieldDidChange());
    });
  }

  final String viewId;
  final RowList _rowList = RowList();
  final CellMemCache _cellMemCache;
  final RowLifeCycle _rowLifeCycle;
  final RowFieldsDelegate _fieldDelegate;
  RowChangesetNotifier? _changedNotifier;
  bool _isInitialRows = false;
  final List<RowsVisibilityChangePB> _pendingVisibilityChanges = [];

  /*
   * 获取行列表
   * 
   * 返回不可修改的行信息列表，保证数据安全性。
   * 外部只能读取，不能直接修改列表。
   */
  UnmodifiableListView<RowInfo> get rowInfos {
    final visibleRows = [..._rowList.rows];
    return UnmodifiableListView(visibleRows);
  }

  /*
   * 获取行映射
   * 
   * 返回 rowId -> RowInfo 的不可修改映射。
   * 用于快速根据 ID 查找行信息。
   */
  UnmodifiableMapView<RowId, RowInfo> get rowByRowId {
    return UnmodifiableMapView(_rowList.rowInfoByRowId);
  }

  CellMemCache get cellCache => _cellMemCache;
  ChangedReason get changeReason =>
      _changedNotifier?.reason ?? const InitialListState();

  RowInfo? getRow(RowId rowId) {
    return _rowList.get(rowId);
  }

  /*
   * 设置初始行数据
   * 
   * 在打开数据库时调用，加载所有行数据。
   * 
   * 处理流程：
   * 1. 构建所有行信息并添加到列表
   * 2. 标记初始化完成
   * 3. 应用等待中的可见性变化
   * 
   * 注意：可见性变化可能在初始化之前到达，
   * 需要缓存起来等初始化完成后应用。
   */
  void setInitialRows(List<RowMetaPB> rows) {
    for (final row in rows) {
      final rowInfo = buildGridRow(row);
      _rowList.add(rowInfo);
    }
    _isInitialRows = true;
    _changedNotifier?.receive(const ChangedReason.setInitialRows());

    // 应用等待中的可见性变化
    for (final changeset in _pendingVisibilityChanges) {
      applyRowsVisibility(changeset);
    }
    _pendingVisibilityChanges.clear();
  }

  void setRowMeta(RowMetaPB rowMeta) {
    final rowInfo = _rowList.get(rowMeta.id);
    if (rowInfo != null) {
      rowInfo.updateRowMeta(rowMeta);
    }

    _changedNotifier?.receive(const ChangedReason.didFetchRow());
  }

  void dispose() {
    _rowList.dispose();
    _rowLifeCycle.onRowDisposed();
    _changedNotifier?.dispose();
    _changedNotifier = null;
    _cellMemCache.dispose();
  }

  /*
   * 应用行变化
   * 
   * 处理后端推送的行变化事件。
   * 
   * 处理顺序很重要：
   * 1. 先删除：避免 ID 冲突
   * 2. 再插入：添加新行
   * 3. 最后更新：修改现有行
   */
  void applyRowsChanged(RowsChangePB changeset) {
    _deleteRows(changeset.deletedRows);
    _insertRows(changeset.insertedRows);
    _updateRows(changeset.updatedRows);
  }

  /*
   * 应用行可见性变化
   * 
   * 处理过滤器导致的行显示/隐藏变化。
   * 
   * 时序处理：
   * - 如果初始化完成：立即应用变化
   * - 如果未初始化：缓存起来等待初始化
   * 
   * 这种设计避免了竞态条件和数据不一致。
   */
  void applyRowsVisibility(RowsVisibilityChangePB changeset) {
    if (_isInitialRows) {
      _hideRows(changeset.invisibleRows);
      _showRows(changeset.visibleRows);
      _changedNotifier?.receive(
        ChangedReason.updateRowsVisibility(changeset),
      );
    } else {
      _pendingVisibilityChanges.add(changeset);
    }
  }

  /*
   * 重排所有行
   * 
   * 根据新的 ID 列表重新排列所有行。
   * 通常用于应用排序规则后的结果。
   */
  void reorderAllRows(List<String> rowIds) {
    _rowList.reorderWithRowIds(rowIds);
    _changedNotifier?.receive(const ChangedReason.reorderRows());
  }

  /*
   * 重排单个行
   * 
   * 移动单个行到新位置。
   * 通常用于用户拖动行的场景。
   * 
   * 参数：
   * - rowId：要移动的行
   * - oldIndex：原位置
   * - newIndex：新位置
   */
  void reorderSingleRow(ReorderSingleRowPB reorderRow) {
    final rowInfo = _rowList.get(reorderRow.rowId);
    if (rowInfo != null) {
      _rowList.moveRow(
        reorderRow.rowId,
        reorderRow.oldIndex,
        reorderRow.newIndex,
      );
      _changedNotifier?.receive(
        ChangedReason.reorderSingleRow(
          reorderRow,
          rowInfo,
        ),
      );
    }
  }

  void _deleteRows(List<RowId> deletedRowIds) {
    for (final rowId in deletedRowIds) {
      final deletedRow = _rowList.remove(rowId);
      if (deletedRow != null) {
        _changedNotifier?.receive(ChangedReason.delete(deletedRow));
      }
    }
  }

  void _insertRows(List<InsertedRowPB> insertRows) {
    final InsertedIndexs insertedIndices = [];
    for (final insertedRow in insertRows) {
      if (insertedRow.hasIndex()) {
        final index = _rowList.insert(
          insertedRow.index,
          buildGridRow(insertedRow.rowMeta),
        );
        if (index != null) {
          insertedIndices.add(index);
        }
      }
    }
    _changedNotifier?.receive(ChangedReason.insert(insertedIndices));
  }

  void _updateRows(List<UpdatedRowPB> updatedRows) {
    if (updatedRows.isEmpty) return;
    final List<RowMetaPB> updatedList = [];
    for (final updatedRow in updatedRows) {
      for (final fieldId in updatedRow.fieldIds) {
        final key = CellContext(
          fieldId: fieldId,
          rowId: updatedRow.rowId,
        );
        _cellMemCache.remove(key);
      }
      if (updatedRow.hasRowMeta()) {
        updatedList.add(updatedRow.rowMeta);
      }
    }

    final updatedIndexs = _rowList.updateRows(
      rowMetas: updatedList,
      builder: (rowId) => buildGridRow(rowId),
    );

    if (updatedIndexs.isNotEmpty) {
      _changedNotifier?.receive(ChangedReason.update(updatedIndexs));
    }
  }

  void _hideRows(List<RowId> invisibleRows) {
    for (final rowId in invisibleRows) {
      final deletedRow = _rowList.remove(rowId);
      if (deletedRow != null) {
        _changedNotifier?.receive(ChangedReason.delete(deletedRow));
      }
    }
  }

  void _showRows(List<InsertedRowPB> visibleRows) {
    for (final insertedRow in visibleRows) {
      final insertedIndex =
          _rowList.insert(insertedRow.index, buildGridRow(insertedRow.rowMeta));
      if (insertedIndex != null) {
        _changedNotifier?.receive(ChangedReason.insert([insertedIndex]));
      }
    }
  }

  void onRowsChanged(void Function(ChangedReason) onRowChanged) {
    _changedNotifier?.addListener(() {
      if (_changedNotifier != null) {
        onRowChanged(_changedNotifier!.reason);
      }
    });
  }

  RowUpdateCallback addListener({
    required RowId rowId,
    void Function(List<CellContext>, ChangedReason)? onRowChanged,
  }) {
    void listenerHandler() async {
      if (onRowChanged != null) {
        final rowInfo = _rowList.get(rowId);
        if (rowInfo != null) {
          final cellDataMap = _makeCells(rowInfo.rowMeta);
          if (_changedNotifier != null) {
            onRowChanged(cellDataMap, _changedNotifier!.reason);
          }
        }
      }
    }

    _changedNotifier?.addListener(listenerHandler);
    return listenerHandler;
  }

  void removeRowListener(VoidCallback callback) {
    _changedNotifier?.removeListener(callback);
  }

  List<CellContext> loadCells(RowMetaPB rowMeta) {
    final rowInfo = _rowList.get(rowMeta.id);
    if (rowInfo == null) {
      _loadRow(rowMeta.id);
    }
    final cells = _makeCells(rowMeta);
    return cells;
  }

  Future<void> _loadRow(RowId rowId) async {
    final result = await RowBackendService.getRow(viewId: viewId, rowId: rowId);
    result.fold(
      (rowMetaPB) {
        final rowInfo = _rowList.get(rowMetaPB.id);
        final rowIndex = _rowList.indexOfRow(rowMetaPB.id);
        if (rowInfo != null && rowIndex != null) {
          rowInfo.rowMetaNotifier.value = rowMetaPB;

          final UpdatedIndexMap updatedIndexs = UpdatedIndexMap();
          updatedIndexs[rowMetaPB.id] = UpdatedIndex(
            index: rowIndex,
            rowId: rowMetaPB.id,
          );

          _changedNotifier?.receive(ChangedReason.update(updatedIndexs));
        }
      },
      (err) => Log.error(err),
    );
  }

  List<CellContext> _makeCells(RowMetaPB rowMeta) {
    return _fieldDelegate.fieldInfos
        .map(
          (fieldInfo) => CellContext(
            rowId: rowMeta.id,
            fieldId: fieldInfo.id,
          ),
        )
        .toList();
  }

  RowInfo buildGridRow(RowMetaPB rowMetaPB) {
    return RowInfo(
      fields: _fieldDelegate.fieldInfos,
      rowMeta: rowMetaPB,
    );
  }
}

class RowChangesetNotifier extends ChangeNotifier {
  RowChangesetNotifier();

  ChangedReason reason = const InitialListState();

  void receive(ChangedReason newReason) {
    reason = newReason;
    reason.map(
      insert: (_) => notifyListeners(),
      delete: (_) => notifyListeners(),
      update: (_) => notifyListeners(),
      fieldDidChange: (_) => notifyListeners(),
      initial: (_) {},
      reorderRows: (_) => notifyListeners(),
      reorderSingleRow: (_) => notifyListeners(),
      updateRowsVisibility: (_) => notifyListeners(),
      setInitialRows: (_) => notifyListeners(),
      didFetchRow: (_) => notifyListeners(),
    );
  }
}

class RowInfo extends Equatable {
  RowInfo({
    required this.fields,
    required RowMetaPB rowMeta,
  })  : rowMetaNotifier = ValueNotifier<RowMetaPB>(rowMeta),
        rowIconNotifier = ValueNotifier<String>(rowMeta.icon),
        rowDocumentNotifier = ValueNotifier<bool>(
          !(rowMeta.hasIsDocumentEmpty() ? rowMeta.isDocumentEmpty : true),
        );

  final UnmodifiableListView<FieldInfo> fields;
  final ValueNotifier<RowMetaPB> rowMetaNotifier;
  final ValueNotifier<String> rowIconNotifier;
  final ValueNotifier<bool> rowDocumentNotifier;

  String get rowId => rowMetaNotifier.value.id;

  RowMetaPB get rowMeta => rowMetaNotifier.value;

  /// Updates the RowMeta and automatically updates the related notifiers.
  void updateRowMeta(RowMetaPB newMeta) {
    rowMetaNotifier.value = newMeta;
    rowIconNotifier.value = newMeta.icon;
    rowDocumentNotifier.value = !newMeta.isDocumentEmpty;
  }

  /// Dispose of the notifiers when they are no longer needed.
  void dispose() {
    rowMetaNotifier.dispose();
    rowIconNotifier.dispose();
    rowDocumentNotifier.dispose();
  }

  @override
  List<Object> get props => [rowMeta];
}

typedef InsertedIndexs = List<InsertedIndex>;
typedef DeletedIndexs = List<DeletedIndex>;
// key: id of the row
// value: UpdatedIndex
typedef UpdatedIndexMap = LinkedHashMap<RowId, UpdatedIndex>;

@freezed
class ChangedReason with _$ChangedReason {
  const factory ChangedReason.insert(InsertedIndexs items) = _Insert;
  const factory ChangedReason.delete(DeletedIndex item) = _Delete;
  const factory ChangedReason.update(UpdatedIndexMap indexs) = _Update;
  const factory ChangedReason.fieldDidChange() = _FieldDidChange;
  const factory ChangedReason.initial() = InitialListState;
  const factory ChangedReason.didFetchRow() = _DidFetchRow;
  const factory ChangedReason.reorderRows() = _ReorderRows;
  const factory ChangedReason.reorderSingleRow(
    ReorderSingleRowPB reorderRow,
    RowInfo rowInfo,
  ) = _ReorderSingleRow;
  const factory ChangedReason.updateRowsVisibility(
    RowsVisibilityChangePB changeset,
  ) = _UpdateRowsVisibility;
  const factory ChangedReason.setInitialRows() = _SetInitialRows;
}

class InsertedIndex {
  InsertedIndex({
    required this.index,
    required this.rowId,
  });

  final int index;
  final RowId rowId;
}

class DeletedIndex {
  DeletedIndex({
    required this.index,
    required this.rowInfo,
  });

  final int index;
  final RowInfo rowInfo;
}

class UpdatedIndex {
  UpdatedIndex({
    required this.index,
    required this.rowId,
  });

  final int index;
  final RowId rowId;
}
