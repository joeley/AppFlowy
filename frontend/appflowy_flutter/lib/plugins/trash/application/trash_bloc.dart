import 'package:appflowy/plugins/trash/application/trash_listener.dart';
import 'package:appflowy/plugins/trash/application/trash_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/trash.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trash_bloc.freezed.dart';

/*
 * 垃圾桶业务逻辑控制器
 * 
 * 核心职责：
 * 1. 管理垃圾桶数据的状态
 * 2. 处理用户操作（恢复、删除）
 * 3. 监听垃圾桶变化并实时更新
 * 
 * 设计模式：
 * - BLoC模式管理状态
 * - 观察者模式监听变化
 * - 服务层分离业务逻辑
 */
class TrashBloc extends Bloc<TrashEvent, TrashState> {
  TrashBloc()
      : _service = TrashService(),
        _listener = TrashListener(),
        super(TrashState.init()) {
    _dispatch();
  }

  /* 垃圾桶服务：处理CRUD操作 */
  final TrashService _service;
  /* 垃圾桶监听器：实时监听变化 */
  final TrashListener _listener;

  /*
   * 事件分发器
   * 
   * 处理所有垃圾桶相关事件：
   * - initial: 初始化加载垃圾桶数据
   * - didReceiveTrash: 接收到垃圾桶更新
   * - putback: 恢复单个项目
   * - delete: 永久删除单个项目
   * - deleteAll: 永久删除所有项目
   * - restoreAll: 恢复所有项目
   * 
   * 流程特点：
   * - 所有操作都是异步的
   * - 统一的错误处理
   * - 状态实时更新
   */
  void _dispatch() {
    on<TrashEvent>((event, emit) async {
      await event.map(
        /* 初始化：启动监听器并加载数据 */
        initial: (e) async {
          _listener.start(trashUpdated: _listenTrashUpdated);
          final result = await _service.readTrash();

          emit(
            result.fold(
              (object) => state.copyWith(
                objects: object.items,
                successOrFailure: FlowyResult.success(null),
              ),
              (error) =>
                  state.copyWith(successOrFailure: FlowyResult.failure(error)),
            ),
          );
        },
        /* 接收垃圾桶更新：直接更新列表 */
        didReceiveTrash: (e) async {
          emit(state.copyWith(objects: e.trash));
        },
        /* 恢复单项：恢复到原位置 */
        putback: (e) async {
          final result = await TrashService.putback(e.trashId);
          await _handleResult(result, emit);
        },
        /* 永久删除单项 */
        delete: (e) async {
          final result = await _service.deleteViews([e.trash.id]);
          await _handleResult(result, emit);
        },
        /* 永久删除所有项目 */
        deleteAll: (e) async {
          final result = await _service.deleteAll();
          await _handleResult(result, emit);
        },
        /* 恢复所有项目 */
        restoreAll: (e) async {
          final result = await _service.restoreAll();
          await _handleResult(result, emit);
        },
      );
    });
  }

  /*
   * 统一处理操作结果
   * 
   * 功能：
   * - 成功：更新状态为成功
   * - 失败：保存错误信息
   * 
   * 用途：
   * - 减少重复代码
   * - 统一错误处理逻辑
   */
  Future<void> _handleResult(
    FlowyResult<dynamic, FlowyError> result,
    Emitter<TrashState> emit,
  ) async {
    emit(
      result.fold(
        (l) => state.copyWith(successOrFailure: FlowyResult.success(null)),
        (error) => state.copyWith(successOrFailure: FlowyResult.failure(error)),
      ),
    );
  }

  /*
   * 垃圾桶更新监听回调
   * 
   * 触发时机：
   * - 其他地方删除文档
   * - 其他客户端恢复/删除
   * - 后台同步更新
   * 
   * 处理方式：
   * - 成功：触发didReceiveTrash事件
   * - 失败：记录错误日志
   */
  void _listenTrashUpdated(
    FlowyResult<List<TrashPB>, FlowyError> trashOrFailed,
  ) {
    trashOrFailed.fold(
      (trash) {
        add(TrashEvent.didReceiveTrash(trash));
      },
      (error) {
        Log.error(error);
      },
    );
  }

  /*
   * 清理资源
   * 
   * BLoC销毁时：
   * - 关闭监听器，避免内存泄漏
   * - 调用父类的close方法
   */
  @override
  Future<void> close() async {
    await _listener.close();
    return super.close();
  }
}

/*
 * 垃圾桶事件定义
 * 
 * 使用freezed生成不可变的事件类
 * 
 * 事件类型：
 * - initial: 初始化加载
 * - didReceiveTrash: 接收到垃圾桶更新
 * - putback: 恢复单个项目
 * - delete: 永久删除单个项目
 * - restoreAll: 恢复所有项目
 * - deleteAll: 永久删除所有项目
 */
@freezed
class TrashEvent with _$TrashEvent {
  const factory TrashEvent.initial() = Initial;
  const factory TrashEvent.didReceiveTrash(List<TrashPB> trash) = ReceiveTrash;
  const factory TrashEvent.putback(String trashId) = Putback;
  const factory TrashEvent.delete(TrashPB trash) = Delete;
  const factory TrashEvent.restoreAll() = RestoreAll;
  const factory TrashEvent.deleteAll() = DeleteAll;
}

/*
 * 垃圾桶状态定义
 * 
 * 状态组成：
 * - objects: 垃圾桶中的所有项目列表
 * - successOrFailure: 操作结果状态
 * 
 * 初始状态：
 * - 空列表
 * - 成功状态
 * 
 * 设计优势：
 * - 不可变对象保证状态一致性
 * - Result类型统一处理成功/失败
 */
@freezed
class TrashState with _$TrashState {
  const factory TrashState({
    required List<TrashPB> objects,
    required FlowyResult<void, FlowyError> successOrFailure,
  }) = _TrashState;

  factory TrashState.init() => TrashState(
        objects: [],
        successOrFailure: FlowyResult.success(null),
      );
}
