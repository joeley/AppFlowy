/*
 * 数据库同步状态管理
 * 
 * 设计理念：
 * 管理数据库与服务器的同步状态，包括网络连接和数据同步进度。
 * 提供视觉反馈，让用户了解数据是否已同步到云端。
 * 
 * 核心功能：
 * 1. 监听网络连接状态
 * 2. 监听数据库同步状态
 * 3. 判断是否需要显示同步指示器
 * 
 * 同步状态说明：
 * - Syncing：正在同步数据
 * - Synced：数据已同步
 * - SyncFailed：同步失败
 * 
 * 显示条件：
 * 只有在服务器模式下才显示同步指示器，
 * 本地模式不需要同步。
 */

import 'dart:async';

import 'package:appflowy/plugins/database/application/sync/database_sync_state_listener.dart';
import 'package:appflowy/plugins/database/domain/database_view_service.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/database_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'database_sync_bloc.freezed.dart';

/*
 * 数据库同步 BLoC
 * 
 * 职责：
 * 1. 管理数据库的同步状态
 * 2. 监听网络连接变化
 * 3. 提供 UI 所需的同步状态信息
 * 
 * 生命周期：
 * 初始化 -> 监听状态 -> 更新UI -> 释放资源
 */
class DatabaseSyncBloc extends Bloc<DatabaseSyncEvent, DatabaseSyncBlocState> {
  DatabaseSyncBloc({
    required this.view,
  }) : super(DatabaseSyncBlocState.initial()) {
    on<DatabaseSyncEvent>(
      (event, emit) async {
        await event.when(
          initial: () async {
            // 初始化事件处理
            // 获取用户信息，判断是否为服务器模式
            final userProfile = await getIt<AuthService>().getUser().then(
                  (value) => value.fold((s) => s, (f) => null),
                );
            // 获取数据库ID（注意：不是视图ID）
            final databaseId = await DatabaseViewBackendService(viewId: view.id)
                .getDatabaseId()
                .then((value) => value.fold((s) => s, (f) => null));
            // 判断是否需要显示同步指示器
            // 条件：1. 服务器模式 2. 有有效的数据库ID
            emit(
              state.copyWith(
                shouldShowIndicator:
                    userProfile?.workspaceType == WorkspaceTypePB.ServerW &&
                        databaseId != null,
              ),
            );
            // 如果有数据库ID，启动同步状态监听器
            if (databaseId != null) {
              _syncStateListener =
                  DatabaseSyncStateListener(databaseId: databaseId)
                    ..start(
                      didReceiveSyncState: (syncState) {
                        // 记录同步状态变化
                        Log.info(
                          'database sync state changed, from ${state.syncState} to $syncState',
                        );
                        // 触发同步状态变化事件
                        add(DatabaseSyncEvent.syncStateChanged(syncState));
                      },
                    );
            }

            // 检查网络连接状态
            final isNetworkConnected = await _connectivity
                .checkConnectivity()
                .then((value) => value != ConnectivityResult.none);
            emit(state.copyWith(isNetworkConnected: isNetworkConnected));

            // 监听网络状态变化
            connectivityStream =
                _connectivity.onConnectivityChanged.listen((result) {
              // 网络状态变化时触发事件
              add(DatabaseSyncEvent.networkStateChanged(result));
            });
          },
          syncStateChanged: (syncState) {
            // 更新同步状态
            emit(state.copyWith(syncState: syncState.value));
          },
          networkStateChanged: (result) {
            // 更新网络连接状态
            emit(
              state.copyWith(
                isNetworkConnected: result != ConnectivityResult.none,
              ),
            );
          },
        );
      },
    );
  }

  final ViewPB view;  // 视图对象
  final _connectivity = Connectivity();  // 网络连接检测器

  StreamSubscription? connectivityStream;  // 网络状态监听流
  DatabaseSyncStateListener? _syncStateListener;  // 数据库同步状态监听器

  /*
   * 释放资源
   * 
   * 清理步骤：
   * 1. 取消网络状态监听
   * 2. 停止同步状态监听
   * 3. 调用父类的 close 方法
   */
  @override
  Future<void> close() async {
    await connectivityStream?.cancel();  // 取消网络监听
    await _syncStateListener?.stop();    // 停止同步监听
    return super.close();
  }
}

/*
 * 数据库同步事件
 * 
 * 事件类型：
 * - initial：初始化事件
 * - syncStateChanged：同步状态变化
 * - networkStateChanged：网络状态变化
 */
@freezed
class DatabaseSyncEvent with _$DatabaseSyncEvent {
  const factory DatabaseSyncEvent.initial() = Initial;
  const factory DatabaseSyncEvent.syncStateChanged(
    DatabaseSyncStatePB syncState,  // 新的同步状态
  ) = syncStateChanged;
  const factory DatabaseSyncEvent.networkStateChanged(
    ConnectivityResult result,  // 网络连接结果
  ) = NetworkStateChanged;
}

/*
 * 数据库同步状态
 * 
 * 属性：
 * - syncState：同步状态（同步中/已同步/同步失败）
 * - isNetworkConnected：网络连接状态
 * - shouldShowIndicator：是否显示同步指示器
 */
@freezed
class DatabaseSyncBlocState with _$DatabaseSyncBlocState {
  const factory DatabaseSyncBlocState({
    required DatabaseSyncState syncState,      // 同步状态
    @Default(true) bool isNetworkConnected,    // 网络连接状态，默认已连接
    @Default(false) bool shouldShowIndicator,  // 是否显示指示器，默认不显示
  }) = _DatabaseSyncState;

  /// 初始状态工厂方法
  factory DatabaseSyncBlocState.initial() => const DatabaseSyncBlocState(
        syncState: DatabaseSyncState.Syncing,  // 初始状态为同步中
      );
}
