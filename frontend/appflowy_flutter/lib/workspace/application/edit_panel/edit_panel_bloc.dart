import 'package:appflowy/workspace/application/edit_panel/edit_context.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'edit_panel_bloc.freezed.dart';

/// 编辑面板管理BLoC - 负责管理编辑面板的显示状态
/// 
/// 主要功能：
/// 1. 控制编辑面板的打开/关闭
/// 2. 管理当前编辑上下文
/// 3. 传递编辑内容到面板
/// 
/// 设计思想：
/// - 通过EditPanelContext抽象支持多种编辑场景
/// - 全局单例管理，避免多个编辑面板同时存在
/// - 支持动态切换编辑内容
class EditPanelBloc extends Bloc<EditPanelEvent, EditPanelState> {
  EditPanelBloc() : super(EditPanelState.initial()) {
    on<EditPanelEvent>((event, emit) async {
      await event.map(
        // 开始编辑：打开面板并设置编辑上下文
        startEdit: (e) async {
          emit(state.copyWith(isEditing: true, editContext: e.context));
        },
        // 结束编辑：关闭面板并清空上下文
        endEdit: (value) async {
          emit(state.copyWith(isEditing: false, editContext: null));
        },
      );
    });
  }
}

/// 编辑面板事件定义
@freezed
class EditPanelEvent with _$EditPanelEvent {
  /// 开始编辑事件 - 携带编辑上下文
  const factory EditPanelEvent.startEdit(EditPanelContext context) = _StartEdit;

  /// 结束编辑事件 - 关闭编辑面板
  const factory EditPanelEvent.endEdit(EditPanelContext context) = _EndEdit;
}

/// 编辑面板状态定义
@freezed
class EditPanelState with _$EditPanelState {
  const factory EditPanelState({
    required bool isEditing, // 是否正在编辑
    required EditPanelContext? editContext, // 当前编辑上下文
  }) = _EditPanelState;

  /// 创建初始状态
  factory EditPanelState.initial() => const EditPanelState(
        isEditing: false,
        editContext: null,
      );
}
