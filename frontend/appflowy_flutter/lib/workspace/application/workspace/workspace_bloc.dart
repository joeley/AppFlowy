import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_bloc.freezed.dart';

/*
 * 工作区管理BLoC
 * 
 * 负责管理用户的工作区列表和相关操作
 * 
 * 核心功能：
 * 1. 获取用户的所有工作区
 * 2. 创建新的工作区
 * 3. 处理工作区数据更新
 * 
 * 状态管理：
 * - 加载状态
 * - 工作区列表
 * - 操作结果（成功/失败）
 * 
 * 设计模式：
 * - BLoC模式：分离业务逻辑和UI
 * - 事件驱动：通过事件触发状态变化
 */
class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc({required this.userService}) : super(WorkspaceState.initial()) {
    _dispatch();
  }

  /* 用户后端服务，用于与后端通信 */
  final UserBackendService userService;

  /*
   * 事件分发器
   * 
   * 注册并处理所有工作区相关事件
   * 使用map方法实现类型安全的事件处理
   */
  void _dispatch() {
    on<WorkspaceEvent>(
      (event, emit) async {
        await event.map(
          /* 初始化事件：获取工作区列表 */
          initial: (e) async {
            await _fetchWorkspaces(emit);
          },
          /* 创建工作区事件 */
          createWorkspace: (e) async {
            await _createWorkspace(e.name, e.desc, emit);
          },
          /* 接收工作区数据事件 */
          workspacesReceived: (e) async {
            emit(
              e.workspacesOrFail.fold(
                /* 成功时更新工作区列表 */
                (workspaces) => state.copyWith(
                  workspaces: workspaces,
                  successOrFailure: FlowyResult.success(null),
                ),
                /* 失败时记录错误 */
                (error) => state.copyWith(
                  successOrFailure: FlowyResult.failure(error),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /*
   * 获取工作区列表
   * 
   * 从后端获取当前用户的所有工作区
   * 
   * 执行流程：
   * 1. 调用用户服务获取工作区
   * 2. 成功时更新工作区列表
   * 3. 失败时记录错误日志
   * 
   * 注意：此处workspaces被设置为空列表可能是个问题
   */
  Future<void> _fetchWorkspaces(Emitter<WorkspaceState> emit) async {
    final workspacesOrFailed = await userService.getWorkspaces();
    emit(
      workspacesOrFailed.fold(
        (workspaces) => state.copyWith(
          workspaces: [],  /* TODO: 这里应该使用workspaces变量 */
          successOrFailure: FlowyResult.success(null),
        ),
        (error) {
          Log.error(error);
          return state.copyWith(successOrFailure: FlowyResult.failure(error));
        },
      ),
    );
  }

  /*
   * 创建新工作区
   * 
   * 参数：
   * - name: 工作区名称
   * - desc: 工作区描述
   * - emit: 状态发射器
   * 
   * 执行流程：
   * 1. 调用用户服务创建工作区
   * 2. 使用ServerW类型（服务器工作区）
   * 3. 成功时更新状态
   * 4. 失败时记录错误
   * 
   * 注意：创建成功后可能需要重新获取工作区列表
   */
  Future<void> _createWorkspace(
    String name,
    String desc,
    Emitter<WorkspaceState> emit,
  ) async {
    final result =
        await userService.createUserWorkspace(name, WorkspaceTypePB.ServerW);
    emit(
      result.fold(
        (workspace) {
          return state.copyWith(successOrFailure: FlowyResult.success(null));
        },
        (error) {
          Log.error(error);
          return state.copyWith(successOrFailure: FlowyResult.failure(error));
        },
      ),
    );
  }
}

/*
 * 工作区事件定义
 * 
 * 使用freezed生成不可变的事件类
 * 每个事件代表一个用户操作或系统通知
 */
@freezed
class WorkspaceEvent with _$WorkspaceEvent {
  /* 初始化事件，加载工作区列表 */
  const factory WorkspaceEvent.initial() = Initial;
  
  /* 创建工作区事件
   * - name: 工作区名称
   * - desc: 工作区描述
   */
  const factory WorkspaceEvent.createWorkspace(String name, String desc) =
      CreateWorkspace;
  
  /* 接收工作区数据事件
   * - workspacesOrFail: 工作区列表或错误
   */
  const factory WorkspaceEvent.workspacesReceived(
    FlowyResult<List<WorkspacePB>, FlowyError> workspacesOrFail,
  ) = WorkspacesReceived;
}

/*
 * 工作区状态定义
 * 
 * 使用freezed生成不可变的状态类
 * 存储工作区管理的所有状态信息
 */
@freezed
class WorkspaceState with _$WorkspaceState {
  const factory WorkspaceState({
    /* 是否正在加载 */
    required bool isLoading,
    /* 工作区列表 */
    required List<WorkspacePB> workspaces,
    /* 操作结果，用于显示成功或错误信息 */
    required FlowyResult<void, FlowyError> successOrFailure,
  }) = _WorkspaceState;

  /* 初始状态工厂方法
   * - 不在加载中
   * - 空的工作区列表
   * - 成功状态
   */
  factory WorkspaceState.initial() => WorkspaceState(
        isLoading: false,
        workspaces: List.empty(),
        successOrFailure: FlowyResult.success(null),
      );
}
