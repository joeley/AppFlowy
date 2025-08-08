/*
 * 数据库分组管理
 * 
 * 设计理念：
 * 管理数据库的分组功能，主要用于看板视图的列分组。
 * 支持按不同字段类型进行分组，如选项字段、日期字段等。
 * 
 * 核心功能：
 * 1. 分组字段选择 - 选择用于分组的字段
 * 2. 分组设置管理 - 管理分组的配置选项
 * 3. 布局设置同步 - 同步看板布局设置
 * 
 * 支持的分组类型：
 * - 单选/多选字段：按选项分组
 * - 日期字段：按日期范围分组
 * - 复选框字段：按勾选状态分组
 * 
 * 使用场景：
 * - 看板视图的列配置
 * - 分组统计和汇总
 * - 数据分类展示
 */

import 'dart:async';

import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/domain/group_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/board_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/group.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_bloc.freezed.dart';

/*
 * 数据库分组 BLoC
 * 
 * 职责：
 * 1. 管理分组配置和设置
 * 2. 处理分组字段的选择和变更
 * 3. 监听字段和布局变化
 * 4. 同步分组设置到后端
 * 
 * 生命周期：
 * 初始化时加载当前分组配置，
 * 监听字段和布局变化，
 * 关闭时清理监听器。
 */
class DatabaseGroupBloc extends Bloc<DatabaseGroupEvent, DatabaseGroupState> {
  DatabaseGroupBloc({
    required String viewId,
    required DatabaseController databaseController,
  })  : _databaseController = databaseController,
        _groupBackendSvc = GroupBackendService(viewId),
        super(
          DatabaseGroupState.initial(
            viewId,
            databaseController.fieldController.fieldInfos,
            databaseController.databaseLayoutSetting!.board,
            databaseController.fieldController.groupSettings,
          ),
        ) {
    _dispatch();
  }

  final DatabaseController _databaseController;  // 数据库控制器
  final GroupBackendService _groupBackendSvc;    // 分组后端服务
  Function(List<FieldInfo>)? _onFieldsFn;        // 字段变化监听函数
  DatabaseLayoutSettingCallbacks? _layoutSettingCallbacks;  // 布局设置回调

  /*
   * 释放资源
   * 
   * 清理步骤：
   * 1. 移除字段监听器
   * 2. 清空回调引用
   * 3. 调用父类的 close
   */
  @override
  Future<void> close() async {
    if (_onFieldsFn != null) {
      _databaseController.fieldController
          .removeListener(onFieldsListener: _onFieldsFn!);
      _onFieldsFn = null;
    }
    _layoutSettingCallbacks = null;
    return super.close();
  }

  void _dispatch() {
    on<DatabaseGroupEvent>(
      (event, emit) async {
        await event.when(
          initial: () async => _startListening(),  // 初始化时启动监听
          didReceiveFieldUpdate: (fieldInfos) {
            // 接收字段更新，同步更新分组设置
            emit(
              state.copyWith(
                fieldInfos: fieldInfos,
                groupSettings:
                    _databaseController.fieldController.groupSettings,
              ),
            );
          },
          setGroupByField: (
            String fieldId,
            FieldType fieldType, [
            List<int>? settingContent,
          ]) async {
            // 设置分组字段
            // fieldId: 要用于分组的字段ID
            // fieldType: 字段类型
            // settingContent: 可选的分组设置内容（二进制格式）
            final result = await _groupBackendSvc.groupByField(
              fieldId: fieldId,
              settingContent: settingContent ?? [],
            );
            // 处理结果，记录错误
            result.fold((l) => null, (err) => Log.error(err));
          },
          didUpdateLayoutSettings: (layoutSettings) {
            // 更新布局设置（看板特有设置）
            emit(state.copyWith(layoutSettings: layoutSettings));
          },
        );
      },
    );
  }

  /*
   * 启动监听（内部方法）
   * 
   * 设置两种监听：
   * 1. 字段变化监听 - 当字段更新时更新分组选项
   * 2. 布局设置监听 - 当看板布局设置变化时更新状态
   */
  void _startListening() {
    // 监听字段变化
    _onFieldsFn = (fieldInfos) =>
        add(DatabaseGroupEvent.didReceiveFieldUpdate(fieldInfos));
    _databaseController.fieldController.addListener(
      onReceiveFields: _onFieldsFn,
      listenWhen: () => !isClosed,  // 只在 BLoC 未关闭时监听
    );

    // 监听布局设置变化
    _layoutSettingCallbacks = DatabaseLayoutSettingCallbacks(
      onLayoutSettingsChanged: (layoutSettings) {
        // 只处理看板布局设置
        if (isClosed || !layoutSettings.hasBoard()) {
          return;
        }
        // 触发布局设置更新事件
        add(
          DatabaseGroupEvent.didUpdateLayoutSettings(layoutSettings.board),
        );
      },
    );
    // 添加监听器到数据库控制器
    _databaseController.addListener(
      onLayoutSettingsChanged: _layoutSettingCallbacks,
    );
  }
}

/*
 * 数据库分组事件
 * 
 * 事件类型：
 * - initial：初始化事件
 * - setGroupByField：设置分组字段
 * - didReceiveFieldUpdate：接收字段更新
 * - didUpdateLayoutSettings：接收布局设置更新
 */
@freezed
class DatabaseGroupEvent with _$DatabaseGroupEvent {
  const factory DatabaseGroupEvent.initial() = _Initial;
  const factory DatabaseGroupEvent.setGroupByField(
    String fieldId,                              // 分组字段ID
    FieldType fieldType,                         // 字段类型
    [@Default([]) List<int> settingContent,]    // 分组设置内容（可选）
  ) = _DatabaseGroupEvent;
  const factory DatabaseGroupEvent.didReceiveFieldUpdate(
    List<FieldInfo> fields,                      // 更新后的字段列表
  ) = _DidReceiveFieldUpdate;
  const factory DatabaseGroupEvent.didUpdateLayoutSettings(
    BoardLayoutSettingPB layoutSettings,         // 看板布局设置
  ) = _DidUpdateLayoutSettings;
}

/*
 * 数据库分组状态
 * 
 * 属性：
 * - viewId：视图ID
 * - fieldInfos：所有字段信息（用于选择分组字段）
 * - layoutSettings：看板布局设置
 * - groupSettings：分组设置列表
 */
@freezed
class DatabaseGroupState with _$DatabaseGroupState {
  const factory DatabaseGroupState({
    required String viewId,                         // 视图ID
    required List<FieldInfo> fieldInfos,            // 字段信息列表
    required BoardLayoutSettingPB layoutSettings,   // 看板布局设置
    required List<GroupSettingPB> groupSettings,    // 分组设置列表
  }) = _DatabaseGroupState;

  /// 初始状态工厂方法
  factory DatabaseGroupState.initial(
    String viewId,
    List<FieldInfo> fieldInfos,
    BoardLayoutSettingPB layoutSettings,
    List<GroupSettingPB> groupSettings,
  ) =>
      DatabaseGroupState(
        viewId: viewId,
        fieldInfos: fieldInfos,
        layoutSettings: layoutSettings,
        groupSettings: groupSettings,
      );
}
