/*
 * 数据库属性管理
 * 
 * 设计理念：
 * 管理数据库视图的字段属性，包括字段的显示/隐藏、顺序调整等。
 * 提供用户自定义视图显示的能力。
 * 
 * 核心功能：
 * 1. 字段可见性管理 - 隐藏不需要的列
 * 2. 字段顺序调整 - 拖动调整列顺序
 * 3. 实时同步 - 监听字段变化并更新UI
 * 
 * 使用场景：
 * - 表格视图的列管理面板
 * - 看板视图的卡片字段选择
 * - 自定义视图布局
 */

import 'dart:async';

import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/domain/field_service.dart';
import 'package:appflowy/plugins/database/domain/field_settings_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_settings_entities.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'property_bloc.freezed.dart';

/*
 * 数据库属性 BLoC
 * 
 * 职责：
 * 1. 管理数据库字段的属性设置
 * 2. 处理字段的显示/隐藏状态
 * 3. 处理字段的顺序调整
 * 4. 监听字段变化并同步更新
 */
class DatabasePropertyBloc
    extends Bloc<DatabasePropertyEvent, DatabasePropertyState> {
  DatabasePropertyBloc({
    required String viewId,
    required FieldController fieldController,
  })  : _fieldController = fieldController,
        super(
          DatabasePropertyState.initial(
            viewId,
            fieldController.fieldInfos,
          ),
        ) {
    _dispatch();
  }

  final FieldController _fieldController;  // 字段控制器
  Function(List<FieldInfo>)? _onFieldsFn;  // 字段变化监听函数

  /*
   * 释放资源
   * 
   * 清理步骤：
   * 1. 移除字段监听器
   * 2. 清空函数引用
   * 3. 调用父类的 close
   */
  @override
  Future<void> close() async {
    if (_onFieldsFn != null) {
      _fieldController.removeListener(onFieldsListener: _onFieldsFn!);
      _onFieldsFn = null;
    }
    return super.close();
  }

  void _dispatch() {
    on<DatabasePropertyEvent>(
      (event, emit) async {
        await event.when(
          initial: () {
            // 初始化时启动监听
            _startListening();
          },
          setFieldVisibility: (fieldId, visibility) async {
            // 设置字段的显示/隐藏状态
            final fieldSettingsSvc =
                FieldSettingsBackendService(viewId: state.viewId);

            // 更新字段设置
            final result = await fieldSettingsSvc.updateFieldSettings(
              fieldId: fieldId,
              fieldVisibility: visibility,
            );

            // 处理结果，如果出错则记录日志
            result.fold((l) => null, (err) => Log.error(err));
          },
          didReceiveFieldUpdate: (fields) {
            // 接收字段更新，更新状态
            emit(state.copyWith(fieldContexts: fields));
          },
          moveField: (fromIndex, toIndex) async {
            // 处理字段移动逻辑
            // 当从前面移动到后面时，目标索引需要减1
            if (fromIndex < toIndex) {
              toIndex--;
            }
            // 获取源字段和目标字段的ID
            final fromId = state.fieldContexts[fromIndex].field.id;
            final toId = state.fieldContexts[toIndex].field.id;

            // 本地先更新顺序，提高响应速度
            final fieldContexts = List<FieldInfo>.from(state.fieldContexts);
            fieldContexts.insert(toIndex, fieldContexts.removeAt(fromIndex));
            emit(state.copyWith(fieldContexts: fieldContexts));

            // 同步到后端
            final result = await FieldBackendService.moveField(
              viewId: state.viewId,
              fromFieldId: fromId,
              toFieldId: toId,
            );

            // 处理结果
            result.fold((l) => null, (r) => Log.error(r));
          },
        );
      },
    );
  }

  /*
   * 启动监听（内部方法）
   * 
   * 设置字段变化监听，当字段更新时触发事件。
   * 使用 listenWhen 确保只在 BLoC 未关闭时监听。
   */
  void _startListening() {
    // 创建监听函数，将字段变化转换为事件
    _onFieldsFn =
        (fields) => add(DatabasePropertyEvent.didReceiveFieldUpdate(fields));
    // 添加监听器到字段控制器
    _fieldController.addListener(
      onReceiveFields: _onFieldsFn,
      listenWhen: () => !isClosed,  // 只在 BLoC 未关闭时监听
    );
  }
}

/*
 * 数据库属性事件
 * 
 * 事件类型：
 * - initial：初始化事件
 * - setFieldVisibility：设置字段可见性
 * - didReceiveFieldUpdate：接收字段更新
 * - moveField：移动字段位置
 */
@freezed
class DatabasePropertyEvent with _$DatabasePropertyEvent {
  const factory DatabasePropertyEvent.initial() = _Initial;
  const factory DatabasePropertyEvent.setFieldVisibility(
    String fieldId,              // 字段ID
    FieldVisibility visibility,  // 可见性状态
  ) = _SetFieldVisibility;
  const factory DatabasePropertyEvent.didReceiveFieldUpdate(
    List<FieldInfo> fields,      // 更新后的字段列表
  ) = _DidReceiveFieldUpdate;
  const factory DatabasePropertyEvent.moveField(
    int fromIndex,               // 源位置
    int toIndex,                 // 目标位置
  ) = _MoveField;
}

/*
 * 数据库属性状态
 * 
 * 属性：
 * - viewId：视图ID
 * - fieldContexts：字段信息列表，包含所有字段的详细信息
 */
@freezed
class DatabasePropertyState with _$DatabasePropertyState {
  const factory DatabasePropertyState({
    required String viewId,                     // 视图ID
    required List<FieldInfo> fieldContexts,     // 字段信息列表
  }) = _GridPropertyState;

  /// 初始状态工厂方法
  factory DatabasePropertyState.initial(
    String viewId,
    List<FieldInfo> fieldContexts,
  ) =>
      DatabasePropertyState(
        viewId: viewId,
        fieldContexts: fieldContexts,
      );
}
