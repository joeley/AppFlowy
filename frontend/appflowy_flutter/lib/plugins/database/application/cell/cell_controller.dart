/*
 * 单元格控制器 - 数据库单个单元格的管理核心
 * 
 * 设计理念：
 * 单元格（Cell）是数据库中的基本数据单元，位于行和列的交叉点。
 * CellController 负责管理单个单元格的数据读写和状态同步。
 * 
 * 核心特性：
 * 1. 泛型设计：T 代表数据显示类型，D 代表数据存储类型
 * 2. 缓存机制：通过 CellMemCache 减少重复加载
 * 3. 监听机制：监听后端数据变化和字段变化
 * 4. 懒加载：只在需要时加载数据
 * 
 * 数据流：
 * 用户输入 -> CellDataPersistence(持久化) -> 后端存储
 * 后端数据 -> CellDataLoader(加载器) -> UI显示
 * 
 * 类型转换示例：
 * - 数字单元格：用户输入"12" -> 显示"$12"（带货币符号）
 * - 日期单元格：时间戳 -> 格式化日期字符串
 * - 选项单元格：选项ID -> 选项名称和颜色
 * 
 * 使用场景：
 * 每个可编辑的单元格都有一个对应的 CellController 实例。
 * 控制器处理数据加载、编辑、保存和同步等所有操作。
 */

import 'dart:async';

import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/domain/cell_listener.dart';
import 'package:appflowy/plugins/database/application/field/type_option/type_option_data_parser.dart';
import 'package:appflowy/plugins/database/application/row/row_cache.dart';
import 'package:appflowy/plugins/database/application/row/row_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'cell_cache.dart';
import 'cell_data_loader.dart';
import 'cell_data_persistence.dart';

part 'cell_controller.freezed.dart';

/*
 * 单元格上下文
 * 
 * 用于唯一标识一个单元格的位置。
 * 由行ID和列（字段）ID组成，确定单元格在表格中的精确位置。
 * 
 * 使用 freezed 生成不可变对象，保证数据安全性。
 */
@freezed
class CellContext with _$CellContext {
  const factory CellContext({
    required String fieldId,  // 字段ID，标识列
    required RowId rowId,      // 行ID，标识行
  }) = _DatabaseCellContext;
}

/*
 * 单元格控制器
 * 
 * 这是单元格数据管理的核心类，负责处理单元格的所有操作。
 * 
 * 泛型参数：
 * - T：显示数据类型（如格式化后的字符串）
 * - D：存储数据类型（如原始数值）
 * 
 * 主要职责：
 * 1. 数据读取：从缓存或后端加载数据
 * 2. 数据写入：保存用户编辑的数据
 * 3. 变化监听：监听单元格和字段的变化
 * 4. 类型转换：处理显示和存储数据的转换
 * 
 * 设计亮点：
 * - 使用缓存避免重复加载
 * - 防抖动处理，避免频繁保存
 * - 灵活的监听器机制
 */
class CellController<T, D> {
  CellController({
    required this.viewId,
    required FieldController fieldController,
    required CellContext cellContext,
    required RowCache rowCache,
    required CellDataLoader<T> cellDataLoader,
    required CellDataPersistence<D> cellDataPersistence,
  })  : _fieldController = fieldController,
        _cellContext = cellContext,
        _rowCache = rowCache,
        _cellDataLoader = cellDataLoader,
        _cellDataPersistence = cellDataPersistence,
        _cellDataNotifier =
            CellDataNotifier(value: rowCache.cellCache.get(cellContext)) {
    _startListening();
  }

  final String viewId;
  final FieldController _fieldController;
  final CellContext _cellContext;
  final RowCache _rowCache;
  final CellDataLoader<T> _cellDataLoader;
  final CellDataPersistence<D> _cellDataPersistence;

  CellListener? _cellListener;
  CellDataNotifier<T?>? _cellDataNotifier;

  Timer? _loadDataOperation;
  Timer? _saveDataOperation;

  Completer? _completer;

  RowId get rowId => _cellContext.rowId;
  String get fieldId => _cellContext.fieldId;
  FieldInfo get fieldInfo => _fieldController.getField(_cellContext.fieldId)!;
  FieldType get fieldType =>
      _fieldController.getField(_cellContext.fieldId)!.fieldType;
  ValueNotifier<String>? get icon => _rowCache.getRow(rowId)?.rowIconNotifier;
  ValueNotifier<bool>? get hasDocument =>
      _rowCache.getRow(rowId)?.rowDocumentNotifier;
  CellMemCache get _cellCache => _rowCache.cellCache;

  /*
   * 类型转换方法
   * 
   * 便捷的类型转换工具，用于将当前控制器转换为不同类型参数的控制器。
   * 在处理不同类型单元格时非常有用。
   */
  CellController<A, B> as<A, B>() => this as CellController<A, B>;

  /*
   * 启动监听器
   * 
   * 设置两种监听机制：
   * 
   * 1. 单元格数据监听：
   *    监听后端的单元格数据变化。
   *    当其他客户端或协作者修改数据时，自动更新本地显示。
   *    例如：用户输入 "12" -> 显示 "$12"（添加货币符号）
   * 
   * 2. 字段变化监听：
   *    监听字段配置的变化。
   *    当字段类型、格式等改变时，重新加载数据。
   *    例如：货币符号从 $ 改为 ￥
   */
  void _startListening() {
    _cellListener = CellListener(
      rowId: _cellContext.rowId,
      fieldId: _cellContext.fieldId,
    );

    // 1. 监听用户编辑事件，必要时加载新数据
    // 例如：
    //  用户输入: 12
    //  单元格显示: $12
    _cellListener?.start(
      onCellChanged: (result) {
        result.fold(
          (_) => _loadData(),
          (err) => Log.error(err),
        );
      },
    );

    // 2. 监听字段事件，必要时加载单元格数据
    _fieldController.addSingleFieldListener(
      fieldId,
      onFieldChanged: _onFieldChangedListener,
    );
  }

  /*
   * 添加监听器
   * 
   * 允许外部组件监听单元格的变化。
   * 
   * 参数：
   * - onCellChanged：单元格数据变化回调
   * - onFieldChanged：字段配置变化回调（可选）
   * 
   * 返回值：
   * 返回一个函数指针，用于移除监听器时使用。
   * 
   * 设计思路：
   * 使用适配器模式将内部通知转换为外部回调
   */
  VoidCallback? addListener({
    required void Function(T?) onCellChanged,
    void Function(FieldInfo fieldInfo)? onFieldChanged,
  }) {
    // 适配器函数：将内部通知转换为外部回调
    void onCellChangedFn() => onCellChanged(_cellDataNotifier?.value);
    _cellDataNotifier?.addListener(onCellChangedFn);

    if (onFieldChanged != null) {
      _fieldController.addSingleFieldListener(
        fieldId,
        onFieldChanged: onFieldChanged,
      );
    }

    // 返回函数指针，便于后续移除监听器
    return onCellChangedFn;
  }

  void removeListener({
    required VoidCallback onCellChanged,
    void Function(FieldInfo fieldInfo)? onFieldChanged,
    VoidCallback? onRowMetaChanged,
  }) {
    _cellDataNotifier?.removeListener(onCellChanged);

    if (onFieldChanged != null) {
      _fieldController.removeSingleFieldListener(
        fieldId: fieldId,
        onFieldChanged: onFieldChanged,
      );
    }
  }

  void _onFieldChangedListener(FieldInfo fieldInfo) {
    // reloadOnFieldChanged should be true if you want to reload the cell
    // data when the corresponding field is changed.
    // For example:
    //   ￥12 -> $12
    if (_cellDataLoader.reloadOnFieldChange) {
      _loadData();
    }
  }

  /// Get the cell data. The cell data will be read from the cache first,
  /// and load from disk if it doesn't exist. You can set [loadIfNotExist] to
  /// false to disable this behavior.
  T? getCellData({bool loadIfNotExist = true}) {
    final T? data = _cellCache.get(_cellContext);
    if (data == null && loadIfNotExist) {
      _loadData();
    }
    return data;
  }

  /// Return the TypeOptionPB that can be parsed into corresponding class using the [parser].
  /// [PD] is the type that the parser return.
  PD getTypeOption<PD>(TypeOptionParser parser) {
    return parser.fromBuffer(fieldInfo.field.typeOptionData);
  }

  /// Saves the cell data to disk. You can set [debounce] to reduce the amount
  /// of save operations, which is useful when editing a [TextField].
  Future<void> saveCellData(
    D data, {
    bool debounce = false,
    void Function(FlowyError?)? onFinish,
  }) async {
    _loadDataOperation?.cancel();
    if (debounce) {
      _saveDataOperation?.cancel();
      _completer = Completer();
      _saveDataOperation = Timer(const Duration(milliseconds: 300), () async {
        final result = await _cellDataPersistence.save(
          viewId: viewId,
          cellContext: _cellContext,
          data: data,
        );
        onFinish?.call(result);
        _completer?.complete();
      });
    } else {
      final result = await _cellDataPersistence.save(
        viewId: viewId,
        cellContext: _cellContext,
        data: data,
      );
      onFinish?.call(result);
    }
  }

  void _loadData() {
    _saveDataOperation?.cancel();
    _loadDataOperation?.cancel();

    _loadDataOperation = Timer(const Duration(milliseconds: 10), () {
      _cellDataLoader
          .loadData(viewId: viewId, cellContext: _cellContext)
          .then((data) {
        if (data != null) {
          _cellCache.insert(_cellContext, data);
        } else {
          _cellCache.remove(_cellContext);
        }
        _cellDataNotifier?.value = data;
      });
    });
  }

  Future<void> dispose() async {
    await _cellListener?.stop();
    _cellListener = null;

    _fieldController.removeSingleFieldListener(
      fieldId: fieldId,
      onFieldChanged: _onFieldChangedListener,
    );

    _loadDataOperation?.cancel();
    await _completer?.future;
    _saveDataOperation?.cancel();
    _cellDataNotifier?.dispose();
    _cellDataNotifier = null;
  }
}

class CellDataNotifier<T> extends ChangeNotifier {
  CellDataNotifier({required T value, this.listenWhen}) : _value = value;

  T _value;
  bool Function(T? oldValue, T? newValue)? listenWhen;

  set value(T newValue) {
    if (listenWhen != null && !listenWhen!.call(_value, newValue)) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  T get value => _value;
}
