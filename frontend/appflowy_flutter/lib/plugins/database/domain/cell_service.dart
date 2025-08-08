import 'dart:async';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

import '../application/cell/cell_controller.dart';

/// 单元格后端服务 - 负责处理数据库单元格的CRUD操作
/// 
/// 主要功能：
/// 1. 更新单元格数据
/// 2. 获取单元格数据
/// 3. 与后端同步单元格状态
/// 
/// 设计思想：
/// - 通过CellContext定位具体单元格（行+列）
/// - 使用Protobuf与后端通信
/// - 静态方法设计，无需实例化
class CellBackendService {
  CellBackendService();

  /// 更新单元格数据
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [cellContext]: 单元格上下文（包含行ID和列ID）
  /// - [data]: 要更新的数据
  /// 
  /// 返回：操作结果
  static Future<FlowyResult<void, FlowyError>> updateCell({
    required String viewId,
    required CellContext cellContext,
    required String data,
  }) {
    // 构建单元格变更请求
    final payload = CellChangesetPB()
      ..viewId = viewId
      ..fieldId = cellContext.fieldId // 字段ID（列）
      ..rowId = cellContext.rowId // 行ID
      ..cellChangeset = data; // 变更数据
    return DatabaseEventUpdateCell(payload).send();
  }

  /// 获取单元格数据
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// - [cellContext]: 单元格上下文
  /// 
  /// 返回：单元格数据对象
  static Future<FlowyResult<CellPB, FlowyError>> getCell({
    required String viewId,
    required CellContext cellContext,
  }) {
    // 构建单元格查询请求
    final payload = CellIdPB()
      ..viewId = viewId
      ..fieldId = cellContext.fieldId // 字段ID
      ..rowId = cellContext.rowId; // 行ID
    return DatabaseEventGetCell(payload).send();
  }
}
