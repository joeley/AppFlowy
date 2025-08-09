/// 视图选择器状态管理
/// 
/// 管理AI功能中的视图选择器，允许用户选择AI可访问的文档视图
/// 支持树形结构展示、多选、部分选择、搜索过滤等功能

import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/view_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'view_selector_cubit.freezed.dart';

/// 视图选中状态枚举
/// 
/// 定义视图在选择器中的选中状态
enum ViewSelectedStatus {
  // 未选中
  unselected,
  // 完全选中（包括所有子项）
  selected,
  // 部分选中（仅部分子项被选中）
  partiallySelected;

  // 判断是否未选中
  bool get isUnselected => this == unselected;
  // 判断是否完全选中
  bool get isSelected => this == selected;
  // 判断是否部分选中
  bool get isPartiallySelected => this == partiallySelected;
}

/// 视图选择器项
/// 
/// 表示选择器中的一个视图节点，包含视图信息和状态
/// 支持树形结构，可以包含子节点
class ViewSelectorItem {
  ViewSelectorItem({
    required this.view,
    required this.parentView,
    required this.children,
    required bool isExpanded,
    required ViewSelectedStatus selectedStatus,
    required bool isDisabled,
  })  : isExpandedNotifier = ValueNotifier(isExpanded),
        selectedStatusNotifier = ValueNotifier(selectedStatus),
        isDisabledNotifier = ValueNotifier(isDisabled);

  // 当前视图
  final ViewPB view;
  // 父视图（可选）
  final ViewPB? parentView;
  // 子视图列表
  final List<ViewSelectorItem> children;
  // 展开状态通知器
  final ValueNotifier<bool> isExpandedNotifier;
  // 禁用状态通知器
  final ValueNotifier<bool> isDisabledNotifier;
  // 选中状态通知器
  final ValueNotifier<ViewSelectedStatus> selectedStatusNotifier;

  // 获取展开状态
  bool get isExpanded => isExpandedNotifier.value;
  // 获取选中状态
  ViewSelectedStatus get selectedStatus => selectedStatusNotifier.value;
  // 获取禁用状态
  bool get isDisabled => isDisabledNotifier.value;

  /// 切换展开/折叠状态
  void toggleIsExpanded() {
    isExpandedNotifier.value = !isExpandedNotifier.value;
  }

  /// 深复制当前项及其所有子项
  ViewSelectorItem copy() {
    return ViewSelectorItem(
      view: view,
      parentView: parentView,
      children:
          children.map<ViewSelectorItem>((child) => child.copy()).toList(),
      isDisabled: isDisabledNotifier.value,
      isExpanded: isExpandedNotifier.value,
      selectedStatus: selectedStatusNotifier.value,
    );
  }

  /// 根据ID查找子节点
  /// 
  /// 递归遍历树结构，查找指定ID的节点
  ViewSelectorItem? findChildBySourceId(String sourceId) {
    // 检查当前节点
    if (view.id == sourceId) {
      return this;
    }
    // 递归查找子节点
    for (final child in children) {
      final childResult = child.findChildBySourceId(sourceId);
      if (childResult != null) {
        return childResult;
      }
    }
    return null;
  }

  /// 递归设置禁用状态
  /// 
  /// 使用提供的函数判断并设置每个节点的禁用状态
  void setIsDisabledRecursive(bool Function(ViewSelectorItem) newIsDisabled) {
    // 设置当前节点状态
    isDisabledNotifier.value = newIsDisabled(this);

    // 递归设置子节点
    for (final child in children) {
      child.setIsDisabledRecursive(newIsDisabled);
    }
  }

  /// 递归设置选中状态
  /// 
  /// 设置当前节点及所有子节点的选中状态
  void setIsSelectedStatusRecursive(ViewSelectedStatus selectedStatus) {
    // 设置当前节点状态
    selectedStatusNotifier.value = selectedStatus;

    // 递归设置子节点
    for (final child in children) {
      child.setIsSelectedStatusRecursive(selectedStatus);
    }
  }

  /// 释放资源
  /// 
  /// 递归释放所有子节点和通知器资源
  void dispose() {
    // 释放子节点
    for (final child in children) {
      child.dispose();
    }
    // 释放通知器
    isExpandedNotifier.dispose();
    selectedStatusNotifier.dispose();
    isDisabledNotifier.dispose();
  }
}

/// 视图选择器Cubit
/// 
/// 管理视图选择器的状态和业务逻辑
/// 支持树形结构展示、多选、搜索过滤、选择限制等功能
class ViewSelectorCubit extends Cubit<ViewSelectorState> {
  ViewSelectorCubit({
    required this.getIgnoreViewType,
    this.maxSelectedParentPageCount,
  }) : super(ViewSelectorState.initial()) {
    // 监听过滤文本变化
    filterTextController.addListener(onFilterChanged);
  }

  // 获取视图忽略类型的函数（用于判断视图是否应被禁用或隐藏）
  final IgnoreViewType Function(ViewSelectorItem) getIgnoreViewType;
  // 最大可选父页面数量限制（可选）
  final int? maxSelectedParentPageCount;

  // 已选中的视图ID列表
  final List<String> selectedSourceIds = [];
  // 所有视图源树
  final List<ViewSelectorItem> sources = [];
  // 已选中的视图树
  final List<ViewSelectorItem> selectedSources = [];
  // 搜索过滤文本控制器
  final filterTextController = TextEditingController();

  /// 更新已选中的视图ID列表
  void updateSelectedSources(List<String> newSelectedSourceIds) {
    selectedSourceIds.clear();
    selectedSourceIds.addAll(newSelectedSourceIds);
  }

  /// 刷新视图源
  /// 
  /// 根据提供的空间视图列表重建整个视图树
  Future<void> refreshSources(
    List<ViewPB> spaceViews,
    ViewPB? currentSpace,
  ) async {
    // 清空过滤文本
    filterTextController.clear();

    // 并行构建所有空间的视图树
    final newSources = await Future.wait(
      spaceViews.map((view) => _recursiveBuild(view, null)),
    );

    // 设置禁用和隐藏状态
    _setIsDisabledAndHideIfNecessary(newSources);

    // 应用选择限制
    _restrictSelectionIfNecessary(newSources);

    // 展开当前空间
    if (currentSpace != null) {
      newSources
          .firstWhereOrNull((e) => e.view.id == currentSpace.id)
          ?.toggleIsExpanded();
    }

    // 构建已选中视图树
    final selected = newSources
        .map((source) => _buildSelectedSources(source))
        .flattened
        .toList();

    // 发射新状态
    emit(
      state.copyWith(
        selectedSources: selected,
        visibleSources: newSources,
      ),
    );

    // 更新和保存源数据
    sources
      ..forEach((e) => e.dispose())  // 释放旧资源
      ..clear()
      ..addAll(newSources.map((e) => e.copy()));

    selectedSources
      ..forEach((e) => e.dispose())  // 释放旧资源
      ..clear()
      ..addAll(selected.map((e) => e.copy()));
  }

  /// 递归构建视图树
  /// 
  /// 从根节点开始递归构建整个视图树结构
  /// 同时计算每个节点的选中状态
  Future<ViewSelectorItem> _recursiveBuild(
    ViewPB view,
    ViewPB? parentView,
  ) async {
    ViewSelectedStatus selectedStatus = ViewSelectedStatus.unselected;
    final isThisSourceSelected = selectedSourceIds.contains(view.id);

    // 获取子视图
    final List<ViewPB>? childrenViews;
    if (integrationMode().isTest) {
      // 测试模式直接使用本地数据
      childrenViews = view.childViews;
    } else {
      // 正常模式从后端获取
      childrenViews =
          await ViewBackendService.getChildViews(viewId: view.id).toNullable();
    }

    int selectedCount = 0;
    final children = <ViewSelectorItem>[];

    if (childrenViews != null) {
      // 递归构建子节点
      for (final childView in childrenViews) {
        final childItem = await _recursiveBuild(childView, view);
        if (childItem.selectedStatus.isSelected) {
          selectedCount++;
        }
        children.add(childItem);
      }

      // 计算当前节点的选中状态
      final areAllChildrenSelectedOrNoChildren =
          children.length == selectedCount;
      final isAnyChildNotUnselected =
          children.any((e) => !e.selectedStatus.isUnselected);

      if (isThisSourceSelected && areAllChildrenSelectedOrNoChildren) {
        // 当前节点和所有子节点都选中 = 完全选中
        selectedStatus = ViewSelectedStatus.selected;
      } else if (isThisSourceSelected || isAnyChildNotUnselected) {
        // 当前节点选中或有子节点选中 = 部分选中
        selectedStatus = ViewSelectedStatus.partiallySelected;
      }
    } else if (isThisSourceSelected) {
      // 没有子节点且当前节点选中 = 完全选中
      selectedStatus = ViewSelectedStatus.selected;
    }

    return ViewSelectorItem(
      view: view,
      parentView: parentView,
      children: children,
      isDisabled: false,
      isExpanded: false,
      selectedStatus: selectedStatus,
    );
  }

  /// 设置禁用和隐藏状态
  /// 
  /// 根据getIgnoreViewType函数的返回值判断视图是否应被禁用或隐藏
  void _setIsDisabledAndHideIfNecessary(
    List<ViewSelectorItem> sources,
  ) {
    // 移除需要隐藏的视图
    sources.retainWhere((source) {
      final ignoreViewType = getIgnoreViewType(source);
      return ignoreViewType != IgnoreViewType.hide;
    });

    // 设置禁用状态并递归处理子节点
    for (final source in sources) {
      source.isDisabledNotifier.value =
          getIgnoreViewType(source) == IgnoreViewType.disable;
      _setIsDisabledAndHideIfNecessary(source.children);
    }
  }

  /// 限制选择数量
  /// 
  /// 当达到最大选择数量时，禁用未选中的项
  void _restrictSelectionIfNecessary(List<ViewSelectorItem> sources) {
    if (maxSelectedParentPageCount == null) {
      return;
    }
    // 先应用基本禁用规则
    for (final source in sources) {
      source.setIsDisabledRecursive((view) {
        return getIgnoreViewType(view) == IgnoreViewType.disable;
      });
    }
    // 检查是否达到选择上限
    if (sources.where((e) => !e.selectedStatus.isUnselected).length >=
        maxSelectedParentPageCount!) {
      // 禁用所有未选中的项
      sources
          .where((e) => e.selectedStatus == ViewSelectedStatus.unselected)
          .forEach(
            (e) => e.setIsDisabledRecursive((_) => true),
          );
    }
  }

  /// 处理过滤文本变化
  /// 
  /// 根据搜索关键词过滤显示的视图
  void onFilterChanged() {
    // 释放旧的可见视图资源
    for (final source in state.visibleSources) {
      source.dispose();
    }
    if (sources.isEmpty) {
      emit(ViewSelectorState.initial());
    } else {
      // 根据搜索结果重建可见视图树
      final selected =
          selectedSources.map(_buildSearchResults).nonNulls.toList();
      final visible =
          sources.map(_buildSearchResults).nonNulls.nonNulls.toList();
      emit(
        state.copyWith(
          selectedSources: selected,
          visibleSources: visible,
        ),
      );
    }
  }

  /// 构建搜索结果
  /// 
  /// 遍历树结构，过滤出匹配搜索关键词的节点
  /// 如果节点或其子节点匹配，则保留该节点
  ViewSelectorItem? _buildSearchResults(ViewSelectorItem item) {
    // 检查当前节点是否匹配搜索关键词
    final isVisible = item.view.nameOrDefault
        .toLowerCase()
        .contains(filterTextController.text.toLowerCase());

    // 递归处理子节点
    final childrenResults = <ViewSelectorItem>[];
    for (final childSource in item.children) {
      final childResult = _buildSearchResults(childSource);
      if (childResult != null) {
        childrenResults.add(childResult);
      }
    }

    // 如果当前节点或子节点匹配，返回新节点
    return isVisible || childrenResults.isNotEmpty
        ? ViewSelectorItem(
            view: item.view,
            parentView: item.parentView,
            children: childrenResults,
            isDisabled: item.isDisabled,
            isExpanded: item.isExpanded,
            selectedStatus: item.selectedStatus,
          )
        : null;
  }

  /// 构建已选中视图树
  /// 
  /// 遍历树结构，提取出所有选中的节点及其子节点
  /// 用于显示已选中的视图列表
  Iterable<ViewSelectorItem> _buildSelectedSources(
    ViewSelectorItem item,
  ) {
    // 递归收集子节点
    final children = <ViewSelectorItem>[];
    for (final childSource in item.children) {
      children.addAll(_buildSelectedSources(childSource));
    }

    // 如果当前节点被选中，创建新节点并展开
    return selectedSourceIds.contains(item.view.id)
        ? [
            ViewSelectorItem(
              view: item.view,
              parentView: item.parentView,
              children: children,
              isDisabled: item.isDisabled,
              selectedStatus: item.selectedStatus,
              isExpanded: true,  // 选中的节点默认展开
            ),
          ]
        : children;
  }

  /// 切换选中状态
  /// 
  /// 处理节点的选中/取消选中操作
  /// 如果是父节点，会同时处理所有子节点
  void toggleSelectedStatus(ViewSelectorItem item, bool isSelectedSection) {
    // 空间节点不可选中
    if (item.view.isSpace) {
      return;
    }
    // 获取节点及其子节点的所有ID
    final allIds = _recursiveGetSourceIds(item);

    // 判断是否需要选中
    if (item.selectedStatus.isUnselected ||
        item.selectedStatus.isPartiallySelected &&
            !item.view.layout.isDocumentView) {
      // 添加到选中列表
      for (final id in allIds) {
        if (!selectedSourceIds.contains(id)) {
          selectedSourceIds.add(id);
        }
      }
    } else {
      // 从选中列表移除
      for (final id in allIds) {
        if (selectedSourceIds.contains(id)) {
          selectedSourceIds.remove(id);
        }
      }
    }

    // 如果是在选中区域操作，立即更新UI状态
    if (isSelectedSection) {
      item.setIsSelectedStatusRecursive(
        item.selectedStatus.isUnselected ||
                item.selectedStatus.isPartiallySelected
            ? ViewSelectedStatus.selected
            : ViewSelectedStatus.unselected,
      );
    }

    // 更新整体选中状态
    updateSelectedStatus();
  }

  /// 递归获取所有视图ID
  /// 
  /// 返回节点及其所有子节点的ID列表
  /// 仅包含文档类型的视图
  List<String> _recursiveGetSourceIds(ViewSelectorItem item) {
    return [
      // 仅文档视图可被选中
      if (item.view.layout.isDocumentView) item.view.id,
      // 递归获取子节点ID
      for (final childSource in item.children)
        ..._recursiveGetSourceIds(childSource),
    ];
  }

  /// 更新选中状态
  /// 
  /// 重新计算所有节点的选中状态并更新UI
  void updateSelectedStatus() {
    if (sources.isEmpty) {
      return;
    }
    // 递归更新所有节点的选中状态
    for (final source in sources) {
      _recursiveUpdateSelectedStatus(source);
    }
    // 应用选择限制
    _restrictSelectionIfNecessary(sources);
    // 释放旧的可见视图
    for (final visibleSource in state.visibleSources) {
      visibleSource.dispose();
    }
    // 重建可见视图树
    final visible = sources.map(_buildSearchResults).nonNulls.toList();

    emit(
      state.copyWith(
        visibleSources: visible,
      ),
    );
  }

  /// 递归更新选中状态
  /// 
  /// 从叶节点开始向上计算每个节点的选中状态
  ViewSelectedStatus _recursiveUpdateSelectedStatus(ViewSelectorItem item) {
    ViewSelectedStatus selectedStatus = ViewSelectedStatus.unselected;

    // 统计子节点选中数量
    int selectedCount = 0;
    for (final childSource in item.children) {
      final childStatus = _recursiveUpdateSelectedStatus(childSource);
      if (childStatus.isSelected) {
        selectedCount++;
      }
    }

    // 检查当前节点是否被选中
    final isThisSourceSelected = selectedSourceIds.contains(item.view.id);
    // 判断所有子节点是否都被选中
    final areAllChildrenSelectedOrNoChildren =
        item.children.length == selectedCount;
    // 判断是否有子节点非未选中状态
    final isAnyChildNotUnselected =
        item.children.any((e) => !e.selectedStatus.isUnselected);

    // 计算当前节点状态
    if (isThisSourceSelected && areAllChildrenSelectedOrNoChildren) {
      // 当前节点和所有子节点都选中 = 完全选中
      selectedStatus = ViewSelectedStatus.selected;
    } else if (isThisSourceSelected || isAnyChildNotUnselected) {
      // 当前节点选中或有子节点选中 = 部分选中
      selectedStatus = ViewSelectedStatus.partiallySelected;
    }

    // 更新节点状态
    item.selectedStatusNotifier.value = selectedStatus;
    return selectedStatus;
  }

  /// 切换展开/折叠状态
  /// 
  /// 同步更新视图树中对应节点的展开状态
  void toggleIsExpanded(ViewSelectorItem item, bool isSelectedSection) {
    // 切换当前节点状态
    item.toggleIsExpanded();
    if (isSelectedSection) {
      // 在选中区域操作，同步更新所有选中树
      for (final selectedSource in selectedSources) {
        selectedSource.findChildBySourceId(item.view.id)?.toggleIsExpanded();
      }
    } else {
      // 在主区域操作，同步更新源树
      for (final source in sources) {
        final child = source.findChildBySourceId(item.view.id);
        if (child != null) {
          child.toggleIsExpanded();
          break;
        }
      }
    }
  }

  /// 释放资源
  /// 
  /// 清理所有视图树和控制器资源
  @override
  Future<void> close() {
    // 释放所有视图树资源
    for (final child in sources) {
      child.dispose();
    }
    for (final child in selectedSources) {
      child.dispose();
    }
    for (final child in state.selectedSources) {
      child.dispose();
    }
    for (final child in state.visibleSources) {
      child.dispose();
    }
    // 释放控制器
    filterTextController.dispose();
    return super.close();
  }
}

/// 视图选择器状态
/// 
/// 使用freezed生成不可变状态类
@freezed
class ViewSelectorState with _$ViewSelectorState {
  const factory ViewSelectorState({
    // 可见的视图源树（经过搜索过滤）
    required List<ViewSelectorItem> visibleSources,
    // 已选中的视图树
    required List<ViewSelectorItem> selectedSources,
  }) = _ViewSelectorState;

  /// 初始状态工厂方法
  factory ViewSelectorState.initial() => const ViewSelectorState(
        visibleSources: [],
        selectedSources: [],
      );
}
