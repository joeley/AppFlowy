/*
 * 行控制器 - 数据库行管理的核心
 * 
 * 设计理念：
 * 行（Row）代表数据库中的一条记录，包含多个单元格数据。
 * RowController 负责管理单个行的生命周期和数据同步。
 * 
 * 核心功能：
 * 1. 行数据加载：从后端加载行的元数据和单元格数据
 * 2. 变化监听：监听行的修改、删除等事件
 * 3. 单元格管理：协调行内所有单元格的数据访问
 * 4. 分组支持：处理行在不同分组中的归属
 * 
 * 生命周期：
 * 创建 -> initialize() 初始化 -> 监听事件 -> dispose() 释放
 * 
 * 性能优化：
 * - 懒加载：只在行可见时才初始化
 * - 缓存机制：通过 RowCache 减少重复加载
 * - 批量处理：合并多个单元格的变化通知
 */

import 'dart:async';

import 'package:appflowy/plugins/database/application/row/row_service.dart';
import 'package:appflowy/plugins/database/domain/row_listener.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:flutter/material.dart';

import '../cell/cell_cache.dart';
import '../cell/cell_controller.dart';
import 'row_cache.dart';

/*
 * 行变化回调
 * 
 * 参数：
 * - List<CellContext>：发生变化的单元格列表
 * - ChangedReason：变化原因（初始化、更新、删除等）
 */
typedef OnRowChanged = void Function(List<CellContext>, ChangedReason);

/*
 * 行控制器
 * 
 * 管理单个数据库行的所有操作和状态。
 * 
 * 职责：
 * 1. 维护行的元数据（ID、创建时间等）
 * 2. 管理行内所有单元格的数据
 * 3. 监听行的变化并通知观察者
 * 4. 处理行的生命周期事件
 * 
 * 注意事项：
 * - 必须调用 initialize() 才能完全启用功能
 * - 使用完毕后必须调用 dispose() 释放资源
 */
class RowController {
  RowController({
    required RowMetaPB rowMeta,   // 行元数据
    required this.viewId,          // 视图ID
    required RowCache rowCache,    // 行缓存
    this.groupId,                  // 分组ID（可选）
  })  : _rowMeta = rowMeta,
        _rowCache = rowCache,
        _rowBackendSvc = RowBackendService(viewId: viewId),
        _rowListener = RowListener(rowMeta.id);

  RowMetaPB _rowMeta;
  final String? groupId;
  VoidCallback? _onRowMetaChanged;
  final String viewId;
  final List<VoidCallback> _onRowChangedListeners = [];
  final RowCache _rowCache;
  final RowListener _rowListener;
  final RowBackendService _rowBackendSvc;
  bool _isDisposed = false;

  String get rowId => _rowMeta.id;
  RowMetaPB get rowMeta => _rowMeta;
  CellMemCache get cellCache => _rowCache.cellCache;

  /*
   * 加载行内所有单元格
   * 
   * 从缓存中获取该行所有单元格的上下文信息。
   * 返回的 CellContext 列表可用于创建 CellController。
   */
  List<CellContext> loadCells() => _rowCache.loadCells(rowMeta);

  /*
   * 初始化行控制器
   * 
   * 重要说明：
   * 这个方法必须被调用才能启用跨设备同步功能。
   * 
   * 最佳实践：
   * - 不要在创建 RowController 后立即调用
   * - 只在行变得可见时才调用
   * - 这样可以减少不必要的同步操作，提高性能
   * 
   * 初始化流程：
   * 1. 向后端注册行
   * 2. 获取最新的行元数据
   * 3. 启动监听器监听变化
   */
  Future<void> initialize() async {
    await _rowBackendSvc.initRow(rowMeta.id);
    unawaited(
      _rowBackendSvc.getRowMeta(rowId).then(
        (result) {
          if (_isDisposed) {
            return;
          }

          result.fold(
            (rowMeta) {
              _rowMeta = rowMeta;
              _rowCache.setRowMeta(rowMeta);
              _onRowMetaChanged?.call();
            },
            (error) => debugPrint(error.toString()),
          );
        },
      ),
    );

    _rowListener.start(
      onRowFetched: (DidFetchRowPB row) {
        _rowCache.setRowMeta(row.meta);
      },
      onMetaChanged: (newRowMeta) {
        if (_isDisposed) {
          return;
        }
        _rowMeta = newRowMeta;
        _rowCache.setRowMeta(newRowMeta);
        _onRowMetaChanged?.call();
      },
    );
  }

  /*
   * 添加监听器
   * 
   * 支持两种监听：
   * 1. onRowChanged：监听行内单元格数据的变化
   * 2. onMetaChanged：监听行元数据的变化（如图标、文档等）
   * 
   * 设计细节：
   * - 保存监听器引用，便于后续移除
   * - 检查 _isDisposed 防止在释放后还执行回调
   */
  void addListener({
    OnRowChanged? onRowChanged,
    VoidCallback? onMetaChanged,
  }) {
    final fn = _rowCache.addListener(
      rowId: rowMeta.id,
      onRowChanged: (context, reasons) {
        if (_isDisposed) {
          return;
        }
        onRowChanged?.call(context, reasons);
      },
    );

    // 将监听器添加到列表，便于后续移除
    _onRowChangedListeners.add(fn);
    _onRowMetaChanged = onMetaChanged;
  }

  /*
   * 释放资源
   * 
   * 清理步骤：
   * 1. 设置已释放标记，防止后续操作
   * 2. 停止后端监听器
   * 3. 移除所有注册的回调
   * 
   * 注意：必须在不再使用时调用，避免内存泄漏
   */
  Future<void> dispose() async {
    _isDisposed = true;
    await _rowListener.stop();
    for (final fn in _onRowChangedListeners) {
      _rowCache.removeRowListener(fn);
    }
  }
}
