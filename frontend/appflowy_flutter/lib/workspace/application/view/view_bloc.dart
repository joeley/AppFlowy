import 'dart:async';
import 'dart:convert';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/util/expand_views.dart';
import 'package:appflowy/workspace/application/favorite/favorite_listener.dart';
import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
import 'package:appflowy/workspace/application/view/view_listener.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protobuf/protobuf.dart';

part 'view_bloc.freezed.dart';

/// 视图管理BLoC - 负责管理单个视图的所有操作和状态
/// 
/// 主要功能：
/// 1. 视图基本操作（重命名、删除、复制、移动）
/// 2. 子视图管理（加载、创建、更新）
/// 3. 展开/折叠状态管理
/// 4. 收藏状态同步
/// 5. 发布/取消发布功能
/// 6. 图标和可见性管理
/// 
/// 设计思想：
/// - 通过监听器实时同步视图变化
/// - 支持递归展开/折叠子视图
/// - 将展开状态持久化到本地存储
/// - 支持视图间的快速切换和移动
class ViewBloc extends Bloc<ViewEvent, ViewState> {
  ViewBloc({
    required this.view, // 当前管理的视图
    this.shouldLoadChildViews = true, // 是否加载子视图
    this.engagedInExpanding = false, // 是否参与展开管理
  })  : viewBackendSvc = ViewBackendService(),
        listener = ViewListener(viewId: view.id),
        favoriteListener = FavoriteListener(),
        super(ViewState.init(view)) {
    _dispatch();
    // 如果参与展开管理，注册展开器
    // 用于全局展开/折叠操作
    if (engagedInExpanding) {
      expander = ViewExpander(
        () => state.isExpanded,
        () => add(const ViewEvent.setIsExpanded(true)),
      );
      getIt<ViewExpanderRegistry>().register(view.id, expander);
    }
  }

  final ViewPB view; // 当前视图
  final ViewBackendService viewBackendSvc; // 视图后端服务
  final ViewListener listener; // 视图变化监听器
  final FavoriteListener favoriteListener; // 收藏状态监听器
  final bool shouldLoadChildViews; // 是否加载子视图
  final bool engagedInExpanding; // 是否参与展开管理
  late ViewExpander expander; // 展开器实例

  @override
  Future<void> close() async {
    // 停止所有监听器
    await listener.stop();
    await favoriteListener.stop();
    // 取消注册展开器
    if (engagedInExpanding) {
      getIt<ViewExpanderRegistry>().unregister(view.id, expander);
    }
    return super.close();
  }

  /// 事件分发器 - 处理所有视图相关事件
  void _dispatch() {
    on<ViewEvent>(
      (event, emit) async {
        await event.map(
          // 初始化事件：启动监听器并加载子视图
          initial: (e) async {
            // 启动视图监听器
            listener.start(
              // 视图更新回调
              onViewUpdated: (result) {
                add(ViewEvent.viewDidUpdate(FlowyResult.success(result)));
              },
              // 子视图更新回调
              onViewChildViewsUpdated: (result) async {
                final view = await _updateChildViews(result);
                if (!isClosed && view != null) {
                  add(ViewEvent.viewUpdateChildView(view));
                }
              },
            );
            // 启动收藏监听器
            favoriteListener.start(
              favoritesUpdated: (result, isFavorite) {
                result.fold(
                  (result) {
                    // 检查当前视图是否在收藏列表中
                    final current = result.items
                        .firstWhereOrNull((v) => v.id == state.view.id);
                    if (current != null) {
                      add(
                        ViewEvent.viewDidUpdate(
                          FlowyResult.success(current),
                        ),
                      );
                    }
                  },
                  (error) {},
                );
              },
            );
            // 获取并设置展开状态
            final isExpanded = await _getViewIsExpanded(view);
            emit(state.copyWith(isExpanded: isExpanded, view: view));
            // 根据配置决定是否加载子视图
            if (shouldLoadChildViews) {
              await _loadChildViews(emit);
            }
          },
          // 设置编辑状态
          setIsEditing: (e) {
            emit(state.copyWith(isEditing: e.isEditing));
          },
          // 设置展开/折叠状态
          setIsExpanded: (e) async {
            if (e.isExpanded && !state.isExpanded) {
              // 展开时加载子视图
              await _loadViewsWhenExpanded(emit, true);
            } else {
              emit(state.copyWith(isExpanded: e.isExpanded));
            }
            // 持久化展开状态
            await _setViewIsExpanded(view, e.isExpanded);
          },
          viewDidUpdate: (e) async {
            final result = await ViewBackendService.getView(view.id);
            final view_ = result.fold((l) => l, (r) => null);
            e.result.fold(
              (view) async {
                // ignore child view changes because it only contains one level
                // children data.
                if (_isSameViewIgnoreChildren(view, state.view)) {
                  // do nothing.
                }
                emit(
                  state.copyWith(
                    view: view_ ?? view,
                    successOrFailure: FlowyResult.success(null),
                  ),
                );
              },
              (error) => emit(
                state.copyWith(successOrFailure: FlowyResult.failure(error)),
              ),
            );
          },
          // 重命名视图
          rename: (e) async {
            final result = await ViewBackendService.updateView(
              viewId: view.id,
              name: e.newName,
            );
            emit(
              result.fold(
                (l) {
                  final view = state.view;
                  view.freeze();
                  final newView = view.rebuild(
                    (b) => b.name = e.newName,
                  );
                  Log.info('rename view: ${newView.id} to ${newView.name}');
                  return state.copyWith(
                    successOrFailure: FlowyResult.success(null),
                    view: newView,
                  );
                },
                (error) {
                  Log.error('rename view failed: $error');
                  return state.copyWith(
                    successOrFailure: FlowyResult.failure(error),
                  );
                },
              ),
            );
          },
          // 删除视图
          delete: (e) async {
            // 先取消发布该页面及其所有子页面
            await _unpublishPage(view);

            final result = await ViewBackendService.deleteView(viewId: view.id);

            emit(
              result.fold(
                (l) {
                  return state.copyWith(
                    successOrFailure: FlowyResult.success(null),
                    isDeleted: true,
                  );
                },
                (error) => state.copyWith(
                  successOrFailure: FlowyResult.failure(error),
                ),
              ),
            );
            // 从最近访问列表中移除
            await getIt<CachedRecentService>().updateRecentViews(
              [view.id],
              false,
            );
          },
          // 复制视图
          duplicate: (e) async {
            final result = await ViewBackendService.duplicate(
              view: view,
              openAfterDuplicate: true, // 复制后打开
              syncAfterDuplicate: true, // 复制后同步
              includeChildren: true, // 包含子视图
              suffix: ' (${LocaleKeys.menuAppHeader_pageNameSuffix.tr()})', // 添加后缀
            );
            emit(
              result.fold(
                (l) =>
                    state.copyWith(successOrFailure: FlowyResult.success(null)),
                (error) => state.copyWith(
                  successOrFailure: FlowyResult.failure(error),
                ),
              ),
            );
          },
          // 移动视图到新位置
          move: (value) async {
            final result = await ViewBackendService.moveViewV2(
              viewId: value.from.id,
              newParentId: value.newParentId, // 新父视图
              prevViewId: value.prevId, // 前一个视图（用于排序）
              fromSection: value.fromSection, // 源分区
              toSection: value.toSection, // 目标分区
            );
            emit(
              result.fold(
                (l) {
                  return state.copyWith(
                    successOrFailure: FlowyResult.success(null),
                  );
                },
                (error) => state.copyWith(
                  successOrFailure: FlowyResult.failure(error),
                ),
              ),
            );
          },
          // 创建子视图
          createView: (e) async {
            final result = await ViewBackendService.createView(
              parentViewId: view.id,
              name: e.name,
              layoutType: e.layoutType, // 布局类型（文档、表格、看板等）
              ext: {},
              openAfterCreate: e.openAfterCreated,
              section: e.section,
            );
            emit(
              result.fold(
                (view) => state.copyWith(
                  lastCreatedView: view,
                  successOrFailure: FlowyResult.success(null),
                ),
                (error) => state.copyWith(
                  successOrFailure: FlowyResult.failure(error),
                ),
              ),
            );
          },
          viewUpdateChildView: (e) async {
            emit(
              state.copyWith(
                view: e.result,
              ),
            );
          },
          updateViewVisibility: (value) async {
            final view = value.view;
            await ViewBackendService.updateViewsVisibility(
              [view],
              value.isPublic,
            );
          },
          updateIcon: (value) async {
            await ViewBackendService.updateViewIcon(
              view: view,
              viewIcon: view.icon.toEmojiIconData(),
            );
          },
          // 折叠所有子页面
          collapseAllPages: (value) async {
            // 递归折叠所有子视图
            for (final childView in view.childViews) {
              await _setViewIsExpanded(childView, false);
            }
            // 折叠当前视图
            add(const ViewEvent.setIsExpanded(false));
          },
          // 取消发布页面
          unpublish: (value) async {
            if (value.sync) {
              // 同步取消发布
              await _unpublishPage(view);
            } else {
              // 异步取消发布（不等待完成）
              unawaited(_unpublishPage(view));
            }
          },
        );
      },
    );
  }

  /// 展开时加载子视图
  /// 
  /// 参数：
  /// - [emit]: 状态发射器
  /// - [isExpanded]: 是否展开
  Future<void> _loadViewsWhenExpanded(
    Emitter<ViewState> emit,
    bool isExpanded,
  ) async {
    if (!isExpanded) {
      emit(
        state.copyWith(
          view: view,
          isExpanded: false,
          isLoading: false,
        ),
      );
      return;
    }

    final viewsOrFailed =
        await ViewBackendService.getChildViews(viewId: state.view.id);

    viewsOrFailed.fold(
      (childViews) {
        state.view.freeze();
        final viewWithChildViews = state.view.rebuild((b) {
          b.childViews.clear();
          b.childViews.addAll(childViews);
        });
        emit(
          state.copyWith(
            view: viewWithChildViews,
            isExpanded: true,
            isLoading: false,
          ),
        );
      },
      (error) => emit(
        state.copyWith(
          successOrFailure: FlowyResult.failure(error),
          isExpanded: true,
          isLoading: false,
        ),
      ),
    );
  }

  /// 加载子视图
  /// 从后端获取子视图并更新状态
  Future<void> _loadChildViews(
    Emitter<ViewState> emit,
  ) async {
    final viewsOrFailed =
        await ViewBackendService.getChildViews(viewId: state.view.id);

    viewsOrFailed.fold(
      (childViews) {
        state.view.freeze();
        final viewWithChildViews = state.view.rebuild((b) {
          b.childViews.clear();
          b.childViews.addAll(childViews);
        });
        emit(
          state.copyWith(
            view: viewWithChildViews,
          ),
        );
      },
      (error) => emit(
        state.copyWith(
          successOrFailure: FlowyResult.failure(error),
        ),
      ),
    );
  }

  /// 设置视图展开状态并持久化
  /// 
  /// 使用本地存储保存展开状态，以便下次打开时恢复
  Future<void> _setViewIsExpanded(ViewPB view, bool isExpanded) async {
    // 从本地存储获取展开状态映射
    final result = await getIt<KeyValueStorage>().get(KVKeys.expandedViews);
    final Map map;
    if (result != null) {
      map = jsonDecode(result);
    } else {
      map = {};
    }
    // 更新展开状态
    if (isExpanded) {
      map[view.id] = true;
    } else {
      map.remove(view.id);
    }
    // 保存到本地存储
    await getIt<KeyValueStorage>().set(KVKeys.expandedViews, jsonEncode(map));
  }

  /// 获取视图的展开状态
  /// 从本地存储读取之前保存的展开状态
  Future<bool> _getViewIsExpanded(ViewPB view) {
    return getIt<KeyValueStorage>().get(KVKeys.expandedViews).then((result) {
      if (result == null) {
        return false;
      }
      final map = jsonDecode(result);
      return map[view.id] ?? false;
    });
  }

  /// 更新子视图
  /// 
  /// 根据更新信息处理子视图的创建、删除和重排序
  /// 
  /// 返回：更新后的视图，如果没有变化返回null
  Future<ViewPB?> _updateChildViews(
    ChildViewUpdatePB update,
  ) async {
    if (update.createChildViews.isNotEmpty) {
      // 如果有新创建的子视图，刷新整个列表
      // 因为没有插入位置信息，需要重新获取完整列表
      assert(update.parentViewId == this.view.id);
      final view = await ViewBackendService.getView(
        update.parentViewId,
      );
      return view.fold((l) => l, (r) => null);
    }

    // 处理删除的子视图
    final view = state.view;
    view.freeze();
    final childViews = [...view.childViews];
    if (update.deleteChildViews.isNotEmpty) {
      // 移除被删除的子视图
      childViews.removeWhere((v) => update.deleteChildViews.contains(v.id));
      return view.rebuild((p0) {
        p0.childViews.clear();
        p0.childViews.addAll(childViews);
      });
    }

    if (update.updateChildViews.isNotEmpty && update.parentViewId.isNotEmpty) {
      final view = await ViewBackendService.getView(update.parentViewId);
      final childViews = view.fold((l) => l.childViews, (r) => []);
      bool isSameOrder = true;
      if (childViews.length == update.updateChildViews.length) {
        for (var i = 0; i < childViews.length; i++) {
          if (childViews[i].id != update.updateChildViews[i].id) {
            isSameOrder = false;
            break;
          }
        }
      } else {
        isSameOrder = false;
      }
      if (!isSameOrder) {
        return view.fold((l) => l, (r) => null);
      }
    }

    return null;
  }

  /// 取消发布页面及其所有子页面
  /// 
  /// 递归取消发布所有已发布的子页面
  Future<void> _unpublishPage(ViewPB views) async {
    final (_, publishedPages) = await ViewBackendService.containPublishedPage(
      view,
    );

    await Future.wait(
      publishedPages.map((view) async {
        Log.info('unpublishing page: ${view.id}, ${view.name}');
        await ViewBackendService.unpublish(view);
      }),
    );
  }

  /// 判断两个视图是否相同（忽略子视图）
  /// 用于避免不必要的更新
  bool _isSameViewIgnoreChildren(ViewPB from, ViewPB to) {
    return _hash(from) == _hash(to);
  }

  /// 计算视图的哈希值
  /// 用于快速比较视图是否变化
  int _hash(ViewPB view) => Object.hash(
        view.id,
        view.name,
        view.createTime,
        view.icon,
        view.parentViewId,
        view.layout,
      );
}

/// 视图事件定义
@freezed
class ViewEvent with _$ViewEvent {
  const factory ViewEvent.initial() = Initial; // 初始化

  const factory ViewEvent.setIsEditing(bool isEditing) = SetEditing; // 设置编辑状态

  const factory ViewEvent.setIsExpanded(bool isExpanded) = SetIsExpanded; // 设置展开状态

  const factory ViewEvent.rename(String newName) = Rename; // 重命名

  const factory ViewEvent.delete() = Delete; // 删除

  const factory ViewEvent.duplicate() = Duplicate; // 复制

  // 移动视图
  const factory ViewEvent.move(
    ViewPB from, // 源视图
    String newParentId, // 新父视图ID
    String? prevId, // 前一个视图ID（用于排序）
    ViewSectionPB? fromSection, // 源分区
    ViewSectionPB? toSection, // 目标分区
  ) = Move;

  // 创建视图
  const factory ViewEvent.createView(
    String name, // 视图名称
    ViewLayoutPB layoutType, { // 布局类型
    /// 创建后是否打开
    @Default(true) bool openAfterCreated,
    ViewSectionPB? section, // 分区
  }) = CreateView;

  const factory ViewEvent.viewDidUpdate(
    FlowyResult<ViewPB, FlowyError> result,
  ) = ViewDidUpdate;

  const factory ViewEvent.viewUpdateChildView(ViewPB result) =
      ViewUpdateChildView;

  const factory ViewEvent.updateViewVisibility(
    ViewPB view,
    bool isPublic,
  ) = UpdateViewVisibility;

  const factory ViewEvent.updateIcon(String? icon) = UpdateIcon;

  const factory ViewEvent.collapseAllPages() = CollapseAllPages;

  // 取消发布事件
  // 会取消发布该页面及其所有子页面
  const factory ViewEvent.unpublish({required bool sync}) = Unpublish; // sync: 是否同步执行
}

/// 视图状态定义
@freezed
class ViewState with _$ViewState {
  const factory ViewState({
    required ViewPB view, // 当前视图
    required bool isEditing, // 是否在编辑状态
    required bool isExpanded, // 是否展开
    required FlowyResult<void, FlowyError> successOrFailure, // 操作结果
    @Default(false) bool isDeleted, // 是否已删除
    @Default(true) bool isLoading, // 是否加载中
    @Default(null) ViewPB? lastCreatedView, // 最后创建的视图
  }) = _ViewState;

  /// 创建初始状态
  factory ViewState.init(ViewPB view) => ViewState(
        view: view,
        isExpanded: false,
        isEditing: false,
        successOrFailure: FlowyResult.success(null),
      );
}
