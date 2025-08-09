import 'dart:math';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/view_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../service/view_selector_cubit.dart';
import '../view_selector.dart';
import 'layout_define.dart';
import 'mention_page_menu.dart';

/// 桌面端AI提示词数据源选择按钮
/// 
/// 功能说明：
/// 1. 显示已选择的数据源数量
/// 2. 点击打开数据源选择弹出层
/// 3. 支持多选文档作为AI参考数据
/// 4. 最多选择3个父页面
/// 
/// 使用场景：
/// - AI对话中选择相关文档作为上下文
/// - 让AI基于特定文档生成回复
class PromptInputDesktopSelectSourcesButton extends StatefulWidget {
  const PromptInputDesktopSelectSourcesButton({
    super.key,
    required this.selectedSourcesNotifier,
    required this.onUpdateSelectedSources,
  });

  /// 已选择数据源ID列表的通知器
  final ValueNotifier<List<String>> selectedSourcesNotifier;
  /// 更新选中数据源的回调
  final void Function(List<String>) onUpdateSelectedSources;

  @override
  State<PromptInputDesktopSelectSourcesButton> createState() =>
      _PromptInputDesktopSelectSourcesButtonState();
}

class _PromptInputDesktopSelectSourcesButtonState
    extends State<PromptInputDesktopSelectSourcesButton> {
  /// 视图选择器状态管理器
  late final cubit = ViewSelectorCubit(
    maxSelectedParentPageCount: 3,  // 最多选择3个父页面
    getIgnoreViewType: (item) {
      final view = item.view;

      // 空间视图正常显示
      if (view.isSpace) {
        return IgnoreViewType.none;
      }
      // 聊天视图隐藏
      if (view.layout == ViewLayoutPB.Chat) {
        return IgnoreViewType.hide;
      }
      // 非文档视图禁用（如数据库、看板）
      if (view.layout != ViewLayoutPB.Document) {
        return IgnoreViewType.disable;
      }

      return IgnoreViewType.none;
    },
  );
  /// 弹出层控制器
  final popoverController = PopoverController();

  @override
  void initState() {
    super.initState();
    // 监听选中数据源变化
    widget.selectedSourcesNotifier.addListener(onSelectedSourcesChanged);
    // 初始化时同步状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSelectedSourcesChanged();
    });
  }

  @override
  void dispose() {
    widget.selectedSourcesNotifier.removeListener(onSelectedSourcesChanged);
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewSelector(
      viewSelectorCubit: BlocProvider.value(
        value: cubit,
      ),
      child: BlocBuilder<SpaceBloc, SpaceState>(
        builder: (context, state) {
          return AppFlowyPopover(
            constraints: BoxConstraints.loose(const Size(320, 380)),
            offset: const Offset(0.0, -10.0),
            direction: PopoverDirection.topWithCenterAligned,
            margin: EdgeInsets.zero,
            controller: popoverController,
            onOpen: () {
              context
                  .read<ViewSelectorCubit>()
                  .refreshSources(state.spaces, state.currentSpace);
            },
            onClose: () {
              widget.onUpdateSelectedSources(cubit.selectedSourceIds);
              context
                  .read<ViewSelectorCubit>()
                  .refreshSources(state.spaces, state.currentSpace);
            },
            popupBuilder: (_) {
              return BlocProvider.value(
                value: context.read<ViewSelectorCubit>(),
                child: const _PopoverContent(),
              );
            },
            child: _IndicatorButton(
              selectedSourcesNotifier: widget.selectedSourcesNotifier,
              onTap: () => popoverController.show(),
            ),
          );
        },
      ),
    );
  }

  /// 处理选中数据源变化
  /// 
  /// 同步外部状态到内部Cubit
  void onSelectedSourcesChanged() {
    cubit
      ..updateSelectedSources(widget.selectedSourcesNotifier.value)
      ..updateSelectedStatus();
  }
}

/// 数据源选择指示器按钮
/// 
/// 功能：
/// 1. 显示页面图标和选中数量
/// 2. 当前页面被选中时显示"当前页面"
/// 3. 悬停效果提升交互体验
class _IndicatorButton extends StatelessWidget {
  const _IndicatorButton({
    required this.selectedSourcesNotifier,
    required this.onTap,
  });

  final ValueNotifier<List<String>> selectedSourcesNotifier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: DesktopAIPromptSizes.actionBarButtonSize,
        child: FlowyHover(
          style: const HoverStyle(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 4, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FlowySvg(
                  FlowySvgs.ai_page_s,
                  color: Theme.of(context).hintColor,
                ),
                const HSpace(2.0),
                ValueListenableBuilder(
                  valueListenable: selectedSourcesNotifier,
                  builder: (context, selectedSourceIds, _) {
                    // 获取当前文档ID
                    final documentId =
                        context.read<DocumentBloc?>()?.documentId;
                    // 如果只选中当前文档，显示"当前页面"，否则显示数量
                    final label = documentId != null &&
                            selectedSourceIds.length == 1 &&
                            selectedSourceIds[0] == documentId
                        ? LocaleKeys.chat_currentPage.tr()
                        : selectedSourceIds.length.toString();
                    return FlowyText(
                      label,
                      fontSize: 12,
                      figmaLineHeight: 16,
                      color: Theme.of(context).hintColor,
                    );
                  },
                ),
                const HSpace(2.0),
                FlowySvg(
                  FlowySvgs.ai_source_drop_down_s,
                  color: Theme.of(context).hintColor,
                  size: const Size.square(8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 数据源选择弹出层内容
/// 
/// 布局结构：
/// 1. 搜索框：过滤可选数据源
/// 2. 已选择列表：显示已选中的数据源
/// 3. 可选择列表：显示所有可选数据源
class _PopoverContent extends StatelessWidget {
  const _PopoverContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewSelectorCubit, ViewSelectorState>(
      builder: (context, state) {
        final theme = AppFlowyTheme.of(context);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: AFTextField(
                size: AFTextFieldSize.m,
                controller:
                    context.read<ViewSelectorCubit>().filterTextController,
                hintText: LocaleKeys.search_label.tr(),
              ),
            ),
            AFDivider(
              startIndent: theme.spacing.l,
              endIndent: theme.spacing.l,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                children: [
                  ..._buildSelectedSources(context, state),
                  if (state.selectedSources.isNotEmpty &&
                      state.visibleSources.isNotEmpty)
                    AFDivider(
                      spacing: 4.0,
                      startIndent: theme.spacing.l,
                      endIndent: theme.spacing.l,
                    ),
                  ..._buildVisibleSources(context, state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建已选择数据源列表
  /// 
  /// 显示已选中的数据源，点击可取消选择
  Iterable<Widget> _buildSelectedSources(
    BuildContext context,
    ViewSelectorState state,
  ) {
    return state.selectedSources.map(
      (e) => ViewSelectorTreeItem(
        key: ValueKey(
          'selected_select_sources_tree_item_${e.view.id}',
        ),
        viewSelectorItem: e,
        level: 0,
        isDescendentOfSpace: e.view.isSpace,
        isSelectedSection: true,  // 标记为已选择区域
        onSelected: (item) {
          // 切换选中状态
          context.read<ViewSelectorCubit>().toggleSelectedStatus(item, true);
        },
        height: 30.0,
      ),
    );
  }

  /// 构建可选择数据源列表
  /// 
  /// 显示所有可选数据源，支持搜索过滤
  Iterable<Widget> _buildVisibleSources(
    BuildContext context,
    ViewSelectorState state,
  ) {
    return state.visibleSources.map(
      (e) => ViewSelectorTreeItem(
        key: ValueKey(
          'visible_select_sources_tree_item_${e.view.id}',
        ),
        viewSelectorItem: e,
        level: 0,
        isDescendentOfSpace: e.view.isSpace,
        isSelectedSection: false,  // 标记为可选择区域
        onSelected: (item) {
          // 切换选中状态
          context.read<ViewSelectorCubit>().toggleSelectedStatus(item, false);
        },
        height: 30.0,
      ),
    );
  }
}

/// 视图选择器树形列表项
/// 
/// 功能说明：
/// 1. 显示单个视图项及其子视图
/// 2. 支持展开/折叠子视图
/// 3. 支持多选状态管理
/// 4. 支持禁用和提示
/// 
/// 设计特点：
/// - 递归渲染子视图
/// - 缩进显示层级关系
/// - 悬停显示操作按钮
class ViewSelectorTreeItem extends StatefulWidget {
  const ViewSelectorTreeItem({
    super.key,
    required this.viewSelectorItem,
    required this.level,
    required this.isDescendentOfSpace,
    required this.isSelectedSection,
    required this.onSelected,
    this.onAdd,
    required this.height,
    this.showSaveButton = false,
    this.showCheckbox = true,
  });

  /// 视图选择项数据
  final ViewSelectorItem viewSelectorItem;

  /// 嵌套层级（用于计算缩进）
  final int level;

  /// 是否为空间的子视图
  final bool isDescendentOfSpace;

  /// 是否在已选择区域
  final bool isSelectedSection;

  /// 选择回调
  final void Function(ViewSelectorItem viewSelectorItem) onSelected;

  /// 添加回调（可选）
  final void Function(ViewSelectorItem viewSelectorItem)? onAdd;

  /// 是否显示保存按钮
  final bool showSaveButton;

  /// 项目高度
  final double height;

  /// 是否显示复选框
  final bool showCheckbox;

  @override
  State<ViewSelectorTreeItem> createState() => _ViewSelectorTreeItemState();
}

class _ViewSelectorTreeItemState extends State<ViewSelectorTreeItem> {
  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: widget.height,
      child: ViewSelectorTreeItemInner(
        viewSelectorItem: widget.viewSelectorItem,
        level: widget.level,
        isDescendentOfSpace: widget.isDescendentOfSpace,
        isSelectedSection: widget.isSelectedSection,
        showCheckbox: widget.showCheckbox,
        showSaveButton: widget.showSaveButton,
        onSelected: widget.onSelected,
        onAdd: widget.onAdd,
      ),
    );

    // 禁用状态处理：添加半透明遮罩和禁用光标
    final disabledEnabledChild = widget.viewSelectorItem.isDisabled
        ? FlowyTooltip(
            // 根据视图类型显示不同提示
            message: widget.showCheckbox
                ? switch (widget.viewSelectorItem.view.layout) {
                    ViewLayoutPB.Document =>
                      LocaleKeys.chat_sourcesLimitReached.tr(),  // 达到选择上限
                    _ => LocaleKeys.chat_sourceUnsupported.tr(),  // 不支持的类型
                  }
                : "",
            child: Opacity(
              opacity: 0.5,
              child: MouseRegion(
                cursor: SystemMouseCursors.forbidden,  // 禁止光标
                child: IgnorePointer(child: child),
              ),
            ),
          )
        : child;

    return ValueListenableBuilder(
      valueListenable: widget.viewSelectorItem.isExpandedNotifier,
      builder: (context, isExpanded, child) {
        // filter the child views that should be ignored
        final childViews = widget.viewSelectorItem.children;

        if (!isExpanded || childViews.isEmpty) {
          return disabledEnabledChild;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            disabledEnabledChild,
            ...childViews.map(
              (childSource) => ViewSelectorTreeItem(
                key: ValueKey(
                  'select_sources_tree_item_${childSource.view.id}',
                ),
                viewSelectorItem: childSource,
                level: widget.level + 1,
                isDescendentOfSpace: widget.isDescendentOfSpace,
                isSelectedSection: widget.isSelectedSection,
                onSelected: widget.onSelected,
                height: widget.height,
                showCheckbox: widget.showCheckbox,
                showSaveButton: widget.showSaveButton,
                onAdd: widget.onAdd,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 视图选择器树形列表项内部组件
/// 
/// 布局结构：
/// 1. 展开/折叠按钮
/// 2. 复选框（可选）
/// 3. 视图图标
/// 4. 视图名称
/// 5. 操作按钮（悬停显示）
class ViewSelectorTreeItemInner extends StatelessWidget {
  const ViewSelectorTreeItemInner({
    super.key,
    required this.viewSelectorItem,
    required this.level,
    required this.isDescendentOfSpace,
    required this.isSelectedSection,
    required this.showCheckbox,
    required this.showSaveButton,
    this.onSelected,
    this.onAdd,
  });

  final ViewSelectorItem viewSelectorItem;
  final int level;
  final bool isDescendentOfSpace;
  final bool isSelectedSection;
  final bool showCheckbox;
  final bool showSaveButton;
  final void Function(ViewSelectorItem)? onSelected;
  final void Function(ViewSelectorItem)? onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onSelected?.call(viewSelectorItem),
      child: FlowyHover(
        style: HoverStyle(
          hoverColor: AFThemeExtension.of(context).lightGreyHover,
        ),
        builder: (context, onHover) {
          final theme = AppFlowyTheme.of(context);

          final isSaveButtonVisible =
              showSaveButton && !viewSelectorItem.view.isSpace;
          final isAddButtonVisible = onAdd != null;
          return Row(
            children: [
              const HSpace(4.0),
              HSpace(max(20.0 * level - (isDescendentOfSpace ? 2 : 0), 0)),
              // builds the >, ^ or · button
              ToggleIsExpandedButton(
                viewSelectorItem: viewSelectorItem,
                isSelectedSection: isSelectedSection,
              ),
              const HSpace(2.0),
              // checkbox
              if (!viewSelectorItem.view.isSpace && showCheckbox) ...[
                SourceSelectedStatusCheckbox(
                  viewSelectorItem: viewSelectorItem,
                ),
                const HSpace(4.0),
              ],
              // icon
              MentionViewIcon(
                view: viewSelectorItem.view,
              ),
              const HSpace(6.0),
              // title
              Expanded(
                child: Text(
                  viewSelectorItem.view.nameOrDefault,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textStyle.body.standard(
                    color: theme.textColorScheme.primary,
                  ),
                ),
              ),
              if (onHover && (isSaveButtonVisible || isAddButtonVisible)) ...[
                const HSpace(4.0),
                if (isSaveButtonVisible)
                  FlowyIconButton(
                    tooltipText: LocaleKeys.chat_addToPageButton.tr(),
                    width: 24,
                    icon: FlowySvg(
                      FlowySvgs.ai_add_to_page_s,
                      size: const Size.square(16),
                      color: Theme.of(context).hintColor,
                    ),
                    onPressed: () => onSelected?.call(viewSelectorItem),
                  ),
                if (isSaveButtonVisible && isAddButtonVisible)
                  const HSpace(4.0),
                if (isAddButtonVisible)
                  FlowyIconButton(
                    tooltipText: LocaleKeys.chat_addToNewPage.tr(),
                    width: 24,
                    icon: FlowySvg(
                      FlowySvgs.add_less_padding_s,
                      size: const Size.square(16),
                      color: Theme.of(context).hintColor,
                    ),
                    onPressed: () => onAdd?.call(viewSelectorItem),
                  ),
                const HSpace(4.0),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 展开/折叠按钮组件
/// 
/// 显示规则：
/// 1. 引用的数据库视图：显示点
/// 2. 没有子视图：显示空白
/// 3. 有子视图：显示展开/折叠箭头
class ToggleIsExpandedButton extends StatelessWidget {
  const ToggleIsExpandedButton({
    super.key,
    required this.viewSelectorItem,
    required this.isSelectedSection,
  });

  final ViewSelectorItem viewSelectorItem;
  final bool isSelectedSection;

  @override
  Widget build(BuildContext context) {
    if (isReferencedDatabaseView(
      viewSelectorItem.view,
      viewSelectorItem.parentView,
    )) {
      return const _DotIconWidget();
    }

    if (viewSelectorItem.children.isEmpty) {
      return const SizedBox.square(dimension: 16.0);
    }

    return FlowyHover(
      child: GestureDetector(
        child: ValueListenableBuilder(
          valueListenable: viewSelectorItem.isExpandedNotifier,
          builder: (context, value, _) => FlowySvg(
            value
                ? FlowySvgs.view_item_expand_s
                : FlowySvgs.view_item_unexpand_s,
            size: const Size.square(16.0),
          ),
        ),
        onTap: () => context
            .read<ViewSelectorCubit>()
            .toggleIsExpanded(viewSelectorItem, isSelectedSection),
      ),
    );
  }
}

/// 点图标组件
/// 
/// 用于标识引用的数据库视图
class _DotIconWidget extends StatelessWidget {
  const _DotIconWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).iconTheme.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 数据源选中状态复选框
/// 
/// 显示三种状态：
/// 1. 未选中：空复选框
/// 2. 已选中：勾选复选框
/// 3. 部分选中：半勾选复选框（子视图部分选中）
class SourceSelectedStatusCheckbox extends StatelessWidget {
  const SourceSelectedStatusCheckbox({
    super.key,
    required this.viewSelectorItem,
  });

  final ViewSelectorItem viewSelectorItem;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: viewSelectorItem.selectedStatusNotifier,
      builder: (context, selectedStatus, _) => FlowySvg(
        switch (selectedStatus) {
          ViewSelectedStatus.unselected => FlowySvgs.uncheck_s,
          ViewSelectedStatus.selected => FlowySvgs.check_filled_s,
          ViewSelectedStatus.partiallySelected => FlowySvgs.check_partial_s,
        },
        size: const Size.square(18.0),
        blendMode: null,
      ),
    );
  }
}
