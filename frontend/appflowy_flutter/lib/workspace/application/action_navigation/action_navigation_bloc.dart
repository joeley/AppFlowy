import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/action_navigation/navigation_action.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_navigation_bloc.freezed.dart';

/// 动作导航管理BLoC - 负责处理应用内导航动作
/// 
/// 主要功能：
/// 1. 处理通知点击等触发的导航动作
/// 2. 支持链式导航（多个动作依次执行）
/// 3. 自动加载视图数据
/// 4. 错误处理和提示
/// 
/// 设计思想：
/// - 通过NavigationAction封装导航信息
/// - 支持异步加载视图数据
/// - 链式动作通过nextActions列表实现
/// - 视图不存在时显示错误提示
class ActionNavigationBloc
    extends Bloc<ActionNavigationEvent, ActionNavigationState> {
  ActionNavigationBloc() : super(const ActionNavigationState.initial()) {
    on<ActionNavigationEvent>((event, emit) async {
      await event.when(
        performAction: (action, showErrorToast, nextActions) async {
          NavigationAction currentAction = action;
          // 如果是打开视图动作且没有视图数据，需要先加载
          if (currentAction.arguments?[ActionArgumentKeys.view] == null &&
              action.type == ActionType.openView) {
            // 从后端获取视图数据
            final result = await ViewBackendService.getView(action.objectId);
            final view = result.toNullable();
            if (view != null) {
              // 视图存在，将其添加到参数中
              if (currentAction.arguments == null) {
                currentAction = currentAction.copyWith(arguments: {});
              }
              currentAction.arguments?.addAll({ActionArgumentKeys.view: view});

            } else {
              // 视图不存在，记录错误
              Log.error('Open view failed: ${action.objectId}');
              if (showErrorToast) {
                // 显示错误提示
                showToastNotification(
                  message: LocaleKeys.search_pageNotExist.tr(),
                  type: ToastificationType.error,
                );
              }
            }
          }

          // 发送当前动作到状态
          emit(state.copyWith(action: currentAction, nextActions: nextActions));

          // 处理链式动作
          if (nextActions.isNotEmpty) {
            // 复制动作列表
            final newActions = [...nextActions];
            // 取出下一个动作
            final next = newActions.removeAt(0);

            // 递归执行下一个动作
            add(
              ActionNavigationEvent.performAction(
                action: next,
                nextActions: newActions,
              ),
            );
          } else {
            // 没有更多动作，清空状态
            emit(state.setNoAction());
          }
        },
      );
    });
  }
}

/// 动作导航事件定义
@freezed
class ActionNavigationEvent with _$ActionNavigationEvent {
  /// 执行导航动作
  const factory ActionNavigationEvent.performAction({
    required NavigationAction action,                     // 要执行的动作
    @Default(false) bool showErrorToast,                 // 是否显示错误提示
    @Default([]) List<NavigationAction> nextActions,     // 后续动作列表
  }) = _PerformAction;
}

/// 动作导航状态定义
class ActionNavigationState {
  /// 初始状态构造器
  const ActionNavigationState.initial()
      : action = null,
        nextActions = const [];

  const ActionNavigationState({
    required this.action,
    this.nextActions = const [],
  });

  final NavigationAction? action;                // 当前动作
  final List<NavigationAction> nextActions;      // 待执行的动作列表

  /// 复制并修改状态
  ActionNavigationState copyWith({
    NavigationAction? action,
    List<NavigationAction>? nextActions,
  }) =>
      ActionNavigationState(
        action: action ?? this.action,
        nextActions: nextActions ?? this.nextActions,
      );

  /// 清空动作
  ActionNavigationState setNoAction() =>
      const ActionNavigationState(action: null);
}
