import 'dart:convert';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/plugins/blank/blank.dart';
import 'package:appflowy/plugins/util.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/util/expand_views.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/presentation/home/home_stack.dart';
import 'package:appflowy/workspace/presentation/home/menu/menu_shared_state.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tabs_bloc.freezed.dart';

/// 标签页管理BLoC
/// 
/// 负责管理AppFlowy中的多标签页功能：
/// 1. 标签页的打开、关闭、切换
/// 2. 标签页的固定（Pin）功能
/// 3. 二级插件的管理（如分屏显示）
/// 4. 最近打开视图的跟踪
/// 5. 工作区切换时的标签页处理
/// 
/// 架构设计：
/// - 使用BLoC模式管理标签页状态
/// - 通过PageManager管理每个标签页的插件
/// - 与MenuSharedState协作跟踪最近打开的视图
class TabsBloc extends Bloc<TabsEvent, TabsState> {
  TabsBloc() : super(TabsState()) {
    menuSharedState = getIt<MenuSharedState>();  // 获取菜单共享状态
    _dispatch();  // 初始化事件分发
  }

  /// 菜单共享状态，用于在不同组件间共享信息
  late final MenuSharedState menuSharedState;

  /// 释放资源
  @override
  Future<void> close() {
    state.dispose();  // 释放所有PageManager
    return super.close();
  }

  /// 设置事件分发处理
  void _dispatch() {
    on<TabsEvent>(
      (event, emit) async {
        event.when(
          // 选择指定索引的标签页
          selectTab: (int index) {
            if (index != state.currentIndex &&
                index >= 0 &&
                index < state.pages) {
              emit(state.copyWith(currentIndex: index));
              _setLatestOpenView();  // 更新最近打开的视图
            }
          },
          moveTab: () {},
          // 关闭指定的标签页
          closeTab: (String pluginId) {
            final pm = state._pageManagers
                .firstWhereOrNull((pm) => pm.plugin.id == pluginId);
            // 固定的标签页不能关闭
            if (pm?.isPinned == true) {
              return;
            }

            emit(state.closeView(pluginId));
            _setLatestOpenView();
          },
          // 关闭当前标签页
          closeCurrentTab: () {
            // 固定的标签页不能关闭
            if (state.currentPageManager.isPinned) {
              return;
            }

            emit(state.closeView(state.currentPageManager.plugin.id));
            _setLatestOpenView();
          },
          // 打开新标签页
          openTab: (Plugin plugin, ViewPB view) {
            // 隐藏当前的二级插件
            state.currentPageManager
              ..hideSecondaryPlugin()
              ..setSecondaryPlugin(BlankPagePlugin());
            emit(state.openView(plugin));
            _setLatestOpenView(view);
          },
          // 在当前标签页打开插件
          openPlugin: (Plugin plugin, ViewPB? view, bool setLatest) {
            // 隐藏二级插件
            state.currentPageManager
              ..hideSecondaryPlugin()
              ..setSecondaryPlugin(BlankPagePlugin());
            emit(state.openPlugin(plugin: plugin, setLatest: setLatest));
            if (setLatest) {
              // 空间视图不应该被记录为最近打开
              if (view != null && view.isSpace) {
                return;
              }
              _setLatestOpenView(view);
              // 展开视图的祖先节点
              if (view != null) _expandAncestors(view);
            }
          },
          // 关闭其他所有标签页
          closeOtherTabs: (String pluginId) {
            // 保留指定的标签页和所有固定的标签页
            final pageManagers = [
              ...state._pageManagers
                  .where((pm) => pm.plugin.id == pluginId || pm.isPinned),
            ];

            int newIndex;
            if (state.currentPageManager.isPinned) {
              // 如果当前标签页已固定，保持当前索引
              newIndex = state.currentIndex;
            } else {
              final pm = state._pageManagers
                  .firstWhereOrNull((pm) => pm.plugin.id == pluginId);
              newIndex = pm != null ? pageManagers.indexOf(pm) : 0;
            }

            emit(
              state.copyWith(
                currentIndex: newIndex,
                pageManagers: pageManagers,
              ),
            );

            _setLatestOpenView();
          },
          // 切换标签页的固定状态
          togglePin: (String pluginId) {
            final pm = state._pageManagers
                .firstWhereOrNull((pm) => pm.plugin.id == pluginId);
            if (pm != null) {
              final index = state._pageManagers.indexOf(pm);

              int newIndex = state.currentIndex;
              if (pm.isPinned) {
                // 取消固定逻辑
                final indexOfFirstUnpinnedTab =
                    state._pageManagers.indexWhere((tab) => !tab.isPinned);

                // Determine the correct insertion point
                final newUnpinnedIndex = indexOfFirstUnpinnedTab != -1
                    ? indexOfFirstUnpinnedTab // Insert before the first unpinned tab
                    : state._pageManagers
                        .length; // Append at the end if no unpinned tabs exist

                state._pageManagers.removeAt(index);

                final adjustedUnpinnedIndex = newUnpinnedIndex > index
                    ? newUnpinnedIndex - 1
                    : newUnpinnedIndex;

                state._pageManagers.insert(adjustedUnpinnedIndex, pm);
                newIndex = _adjustCurrentIndex(
                  currentIndex: state.currentIndex,
                  tabIndex: index,
                  newIndex: adjustedUnpinnedIndex,
                );
              } else {
                // 固定逻辑
                // 找到最后一个固定标签页的位置
                final indexOfLastPinnedTab =
                    state._pageManagers.lastIndexWhere((tab) => tab.isPinned);
                final newPinnedIndex = indexOfLastPinnedTab + 1;

                state._pageManagers.removeAt(index);

                final adjustedPinnedIndex = newPinnedIndex > index
                    ? newPinnedIndex - 1
                    : newPinnedIndex;

                state._pageManagers.insert(adjustedPinnedIndex, pm);
                newIndex = _adjustCurrentIndex(
                  currentIndex: state.currentIndex,
                  tabIndex: index,
                  newIndex: adjustedPinnedIndex,
                );
              }

              pm.isPinned = !pm.isPinned;

              emit(
                state.copyWith(
                  currentIndex: newIndex,
                  pageManagers: [...state._pageManagers],
                ),
              );
            }
          },
          // 打开二级插件（如分屏显示）
          openSecondaryPlugin: (plugin, view) {
            state.currentPageManager
              ..setSecondaryPlugin(plugin)
              ..showSecondaryPlugin();
          },
          // 关闭二级插件
          closeSecondaryPlugin: () {
            final pageManager = state.currentPageManager;
            pageManager.hideSecondaryPlugin();
          },
          // 将二级插件展开为主插件
          expandSecondaryPlugin: () {
            final pageManager = state.currentPageManager;
            pageManager
              ..hideSecondaryPlugin()
              ..expandSecondaryPlugin();
            _setLatestOpenView();
          },
          // 切换工作区
          switchWorkspace: (workspaceId) {
            final pluginId = state.currentPageManager.plugin.id;

            // 关闭除当前和固定标签页外的所有标签页
            final pagesToClose = [
              ...state._pageManagers
                  .where((pm) => pm.plugin.id != pluginId && !pm.isPinned),
            ];

            if (pagesToClose.isNotEmpty) {
              final newstate = state;
              for (final pm in pagesToClose) {
                newstate.closeView(pm.plugin.id);
              }
              emit(newstate.copyWith(currentIndex: 0));
            }
          },
        );
      },
    );
  }

  /// 设置最近打开的视图
  /// 用于在菜单中跟踪和定位当前打开的视图
  void _setLatestOpenView([ViewPB? view]) {
    if (view != null) {
      menuSharedState.latestOpenView = view;
    } else {
      // 从当前页面管理器获取视图
      final pageManager = state.currentPageManager;
      final notifier = pageManager.plugin.notifier;
      if (notifier is ViewPluginNotifier &&
          menuSharedState.latestOpenView?.id != notifier.view.id) {
        menuSharedState.latestOpenView = notifier.view;
      }
    }
  }

  /// 展开视图的所有祖先节点
  /// 确保在侧边栏中可以看到当前打开的视图
  Future<void> _expandAncestors(ViewPB view) async {
    final viewExpanderRegistry = getIt.get<ViewExpanderRegistry>();
    if (viewExpanderRegistry.isViewExpanded(view.parentViewId)) return;
    final value = await getIt<KeyValueStorage>().get(KVKeys.expandedViews);
    try {
      // 获取和更新展开状态
      final Map expandedViews = value == null ? {} : jsonDecode(value);
      // 获取所有祖先节点
      final List<String> ancestors =
          await ViewBackendService.getViewAncestors(view.id)
              .fold((s) => s.items.map((e) => e.id).toList(), (f) => []);
      ViewExpander? viewExpander;
      for (final id in ancestors) {
        expandedViews[id] = true;
        final expander = viewExpanderRegistry.getExpander(id);
        if (expander == null) continue;
        if (!expander.isViewExpanded && viewExpander == null) {
          viewExpander = expander;
        }
      }
      await getIt<KeyValueStorage>()
          .set(KVKeys.expandedViews, jsonEncode(expandedViews));
      viewExpander?.expand();
    } catch (e) {
      Log.error('expandAncestors error', e);
    }
  }

  /// 调整当前选中的索引
  /// 当标签页位置变化时（如固定/取消固定），需要调整当前索引
  int _adjustCurrentIndex({
    required int currentIndex,
    required int tabIndex,
    required int newIndex,
  }) {
    if (tabIndex < currentIndex && newIndex >= currentIndex) {
      return currentIndex - 1; // 标签页向前移动，当前索引退后
    } else if (tabIndex > currentIndex && newIndex <= currentIndex) {
      return currentIndex + 1; // 标签页向后移动，当前索引前进
    } else if (tabIndex == currentIndex) {
      return newIndex; // 当前标签页移动，更新到新位置
    }

    return currentIndex;
  }

  /// 为指定视图添加打开标签页事件
  void openTab(ViewPB view) =>
      add(TabsEvent.openTab(plugin: view.plugin(), view: view));

  /// 为指定视图添加打开插件事件
  /// 可以传递额外的参数给插件
  void openPlugin(
    ViewPB view, {
    Map<String, dynamic> arguments = const {},
  }) {
    add(
      TabsEvent.openPlugin(
        plugin: view.plugin(arguments: arguments),
        view: view,
      ),
    );
  }
}

/// 标签页事件定义
/// 使用freezed生成不可变的事件类
@freezed
class TabsEvent with _$TabsEvent {
  const factory TabsEvent.moveTab() = _MoveTab;  // 移动标签页

  const factory TabsEvent.closeTab(String pluginId) = _CloseTab;  // 关闭指定标签页

  const factory TabsEvent.closeOtherTabs(String pluginId) = _CloseOtherTabs;  // 关闭其他标签页

  const factory TabsEvent.closeCurrentTab() = _CloseCurrentTab;  // 关闭当前标签页

  const factory TabsEvent.selectTab(int index) = _SelectTab;  // 选择标签页

  const factory TabsEvent.togglePin(String pluginId) = _TogglePin;  // 切换固定状态

  const factory TabsEvent.openTab({  // 打开新标签页
    required Plugin plugin,
    required ViewPB view,
  }) = _OpenTab;

  const factory TabsEvent.openPlugin({  // 在当前标签页打开插件
    required Plugin plugin,
    ViewPB? view,
    @Default(true) bool setLatest,  // 是否设置为最近打开
  }) = _OpenPlugin;

  const factory TabsEvent.openSecondaryPlugin({  // 打开二级插件
    required Plugin plugin,
    ViewPB? view,
  }) = _OpenSecondaryPlugin;

  const factory TabsEvent.closeSecondaryPlugin() = _CloseSecondaryPlugin;  // 关闭二级插件

  const factory TabsEvent.expandSecondaryPlugin() = _ExpandSecondaryPlugin;  // 展开二级插件

  const factory TabsEvent.switchWorkspace(String workspaceId) =  // 切换工作区
      _SwitchWorkspace;
}

/// 标签页状态
/// 管理所有打开的标签页和当前选中的标签页
class TabsState {
  TabsState({
    this.currentIndex = 0,  // 当前选中的标签页索引
    List<PageManager>? pageManagers,  // 页面管理器列表
  }) : _pageManagers = pageManagers ?? [PageManager()];

  final int currentIndex;  // 当前选中的索引
  final List<PageManager> _pageManagers;  // 页面管理器列表

  /// 获取标签页总数
  int get pages => _pageManagers.length;

  /// 获取当前页面管理器
  PageManager get currentPageManager => _pageManagers[currentIndex];

  /// 获取所有页面管理器
  List<PageManager> get pageManagers => _pageManagers;

  /// 检查是否所有标签页都已固定
  bool get isAllPinned => _pageManagers.every((pm) => pm.isPinned);

  /// 打开新标签页
  /// 
  /// 如果插件已经在某个标签页中打开，
  /// 则选择那个标签页而不是创建新的
  TabsState openView(Plugin plugin) {
    final selectExistingPlugin = _selectPluginIfOpen(plugin.id);

    if (selectExistingPlugin == null) {
      _pageManagers.add(PageManager()..setPlugin(plugin, true));

      return copyWith(
        currentIndex: pages - 1,
        pageManagers: [..._pageManagers],
      );
    }

    return selectExistingPlugin;
  }

  /// 关闭指定的标签页
  TabsState closeView(String pluginId) {
    // 避免关闭唯一的标签页
    if (_pageManagers.length == 1) {
      return this;
    }

    _pageManagers.removeWhere((pm) => pm.plugin.id == pluginId);

    /// If currentIndex is greater than the amount of allowed indices
    /// And the current selected tab isn't the first (index 0)
    ///   as currentIndex cannot be -1
    /// Then decrease currentIndex by 1
    final newIndex = currentIndex > pages - 1 && currentIndex > 0
        ? currentIndex - 1
        : currentIndex;

    return copyWith(
      currentIndex: newIndex,
      pageManagers: [..._pageManagers],
    );
  }

  /// 在当前选中的标签页中打开插件
  /// 
  /// 由于文档的工作方式，每个插件只能在一个标签页中活动
  /// 如果插件已经在某个标签页中打开，
  /// 那个标签页将被选中
  TabsState openPlugin({required Plugin plugin, bool setLatest = true}) {
    final selectExistingPlugin = _selectPluginIfOpen(plugin.id);

    if (selectExistingPlugin == null) {
      final pageManagers = [..._pageManagers];
      pageManagers[currentIndex].setPlugin(plugin, setLatest);

      return copyWith(pageManagers: pageManagers);
    }

    return selectExistingPlugin;
  }

  /// 检查插件是否已经在某个打开的标签页中
  /// 
  /// 如果找到匹配，返回更新后的TabState
  /// 如果没有匹配，返回null
  TabsState? _selectPluginIfOpen(String id) {
    final index = _pageManagers.indexWhere((pm) => pm.plugin.id == id);

    if (index == -1) {
      return null;
    }

    if (index == currentIndex) {
      return this;
    }

    return copyWith(currentIndex: index);
  }

  TabsState copyWith({
    int? currentIndex,
    List<PageManager>? pageManagers,
  }) =>
      TabsState(
        currentIndex: currentIndex ?? this.currentIndex,
        pageManagers: pageManagers ?? _pageManagers,
      );

  /// 释放资源
  /// 释放所有页面管理器
  void dispose() {
    for (final manager in pageManagers) {
      manager.dispose();
    }
  }
}
