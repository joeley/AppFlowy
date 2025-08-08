import 'dart:async';

// 文档同步状态监听器
import 'package:appflowy/plugins/document/application/doc_sync_state_listener.dart';
// 启动时的依赖注入
import 'package:appflowy/startup/startup.dart';
// 用户认证服务
import 'package:appflowy/user/application/auth/auth_service.dart';
// 文档相关的Protocol Buffer定义
import 'package:appflowy_backend/protobuf/flowy-document/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-document/protobuf.dart';
// 视图相关定义
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// 用户相关定义
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
// 网络连接检测
import 'package:connectivity_plus/connectivity_plus.dart';
// BLoC状态管理
import 'package:flutter_bloc/flutter_bloc.dart';
// 代码生成注解
import 'package:freezed_annotation/freezed_annotation.dart';

part 'document_sync_bloc.freezed.dart';

/* 文档同步业务逻辑组件（BLoC）
 * 
 * 负责管理单个文档的数据同步状态和网络连接状态
 * 
 * 核心职责：
 * 1. 监听文档同步状态变化（同步中、已同步、同步失败）
 * 2. 检测和响应网络连接状态变化
 * 3. 根据工作区类型决定是否显示同步指示器
 * 4. 协调本地存储和云端同步
 * 
 * 同步机制说明：
 * - 本地优先：所有操作先在本地完成，然后同步到云端
 * - 实时同步：内容变更后立即触发同步
 * - 增量同步：只同步变更的部分，节省带宽
 * - 冲突解决：使用操作转换算法解决编辑冲突
 * - 离线支持：网络断开时继续本地编辑，连接恢复时自动同步
 * 
 * 状态管理：
 * - DocumentSyncState: 同步状态（正在同步/已同步/同步失败）
 * - isNetworkConnected: 网络连接状态
 * - shouldShowIndicator: 是否显示同步指示器
 * 
 * 工作区类型影响：
 * - LocalWorkspace: 纯本地工作区，不显示同步指示器
 * - ServerWorkspace: 云端工作区，显示同步状态
 */
class DocumentSyncBloc extends Bloc<DocumentSyncEvent, DocumentSyncBlocState> {
  /* 文档同步BLoC构造函数
   * 
   * 初始化文档同步管理组件
   * 
   * 参数：
   * - view: 需要管理同步状态的视图对象
   * 
   * 初始化过程：
   * 1. 创建文档同步状态监听器
   * 2. 设置初始状态
   * 3. 注册事件处理器
   */
  DocumentSyncBloc({
    required this.view,
  })  : _syncStateListener = DocumentSyncStateListener(id: view.id),
        super(DocumentSyncBlocState.initial()) {
    /* 事件处理器注册
     * 
     * 处理三种类型的事件：
     * 1. initial: 初始化事件
     * 2. syncStateChanged: 同步状态变化事件  
     * 3. networkStateChanged: 网络状态变化事件
     */
    on<DocumentSyncEvent>(
      (event, emit) async {
        await event.when(
          /* 初始化处理
           * 
           * 执行以下初始化操作：
           * 1. 获取用户配置，判断工作区类型
           * 2. 启动同步状态监听器
           * 3. 检测初始网络连接状态
           * 4. 订阅网络状态变化
           */
          initial: () async {
            // 获取用户配置信息
            final userProfile = await getIt<AuthService>().getUser().then(
                  (result) => result.fold(
                    (l) => l,  // 成功获取用户信息
                    (r) => null,  // 获取失败
                  ),
                );
            
            // 根据工作区类型决定是否显示同步指示器
            // 只有云端工作区才显示同步状态
            emit(
              state.copyWith(
                shouldShowIndicator:
                    userProfile?.workspaceType == WorkspaceTypePB.ServerW,
              ),
            );
            
            // 启动同步状态监听器
            // 监听来自Rust后端的同步状态更新
            _syncStateListener.start(
              didReceiveSyncState: (syncState) {
                add(DocumentSyncEvent.syncStateChanged(syncState));
              },
            );

            // 检测初始网络连接状态
            final isNetworkConnected = await _connectivity
                .checkConnectivity()
                .then((value) => value != ConnectivityResult.none);
            emit(state.copyWith(isNetworkConnected: isNetworkConnected));

            // 订阅网络状态变化
            // 当网络连接状态改变时自动更新状态
            connectivityStream =
                _connectivity.onConnectivityChanged.listen((result) {
              add(DocumentSyncEvent.networkStateChanged(result));
            });
          },
          
          /* 同步状态变化处理
           * 
           * 当接收到新的同步状态时更新BLoC状态
           */
          syncStateChanged: (syncState) {
            emit(state.copyWith(syncState: syncState.value));
          },
          
          /* 网络状态变化处理
           * 
           * 根据网络连接结果更新连接状态
           * none表示无网络连接，其他值表示有连接
           */
          networkStateChanged: (result) {
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

  // 当前管理的视图对象
  final ViewPB view;
  
  // 文档同步状态监听器，监听来自Rust后端的同步状态更新
  final DocumentSyncStateListener _syncStateListener;
  
  // 网络连接检测工具
  final _connectivity = Connectivity();

  // 网络状态变化订阅，用于监听网络连接状态
  StreamSubscription? connectivityStream;

  /* 清理资源
   * 
   * BLoC销毁时调用，确保所有订阅和监听器都被正确清理
   * 
   * 清理步骤：
   * 1. 取消网络状态监听订阅
   * 2. 停止文档同步状态监听器
   * 3. 调用父类的清理方法
   * 
   * 重要性：
   * - 防止内存泄漏
   * - 避免资源占用
   * - 确保监听器不会在组件销毁后继续运行
   */
  @override
  Future<void> close() async {
    await connectivityStream?.cancel();
    await _syncStateListener.stop();
    return super.close();
  }
}

/* 文档同步事件定义
 * 
 * 使用Freezed生成不可变的事件类
 * 
 * 事件类型：
 * - initial: 初始化事件，触发BLoC的初始设置
 * - syncStateChanged: 同步状态变化事件，携带新的同步状态
 * - networkStateChanged: 网络状态变化事件，携带连接状态
 */
@freezed
class DocumentSyncEvent with _$DocumentSyncEvent {
  // 初始化事件，BLoC创建后第一个处理的事件
  const factory DocumentSyncEvent.initial() = Initial;
  
  // 同步状态变化事件，当文档同步状态改变时触发
  const factory DocumentSyncEvent.syncStateChanged(
    DocumentSyncStatePB syncState,
  ) = syncStateChanged;
  
  // 网络状态变化事件，当设备网络连接状态改变时触发
  const factory DocumentSyncEvent.networkStateChanged(
    ConnectivityResult result,
  ) = NetworkStateChanged;
}

/* 文档同步BLoC状态定义
 * 
 * 使用Freezed生成不可变的状态类
 * 
 * 状态属性：
 * - syncState: 文档同步状态（同步中/已同步/同步失败等）
 * - isNetworkConnected: 网络连接状态，默认为true
 * - shouldShowIndicator: 是否显示同步指示器，默认为false
 * 
 * 状态组合说明：
 * - 本地工作区：shouldShowIndicator=false，不显示任何同步UI
 * - 云端工作区有网络：显示实际的同步状态
 * - 云端工作区无网络：显示离线状态
 */
@freezed
class DocumentSyncBlocState with _$DocumentSyncBlocState {
  const factory DocumentSyncBlocState({
    // 文档同步状态
    required DocumentSyncState syncState,
    // 网络连接状态，默认认为已连接
    @Default(true) bool isNetworkConnected,
    // 是否显示同步指示器，只有云端工作区才显示
    @Default(false) bool shouldShowIndicator,
  }) = _DocumentSyncState;

  /* 初始状态工厂方法
   * 
   * 创建BLoC的初始状态
   * 默认同步状态为"正在同步"，其他属性使用默认值
   */
  factory DocumentSyncBlocState.initial() => const DocumentSyncBlocState(
        syncState: DocumentSyncState.Syncing,
      );
}
