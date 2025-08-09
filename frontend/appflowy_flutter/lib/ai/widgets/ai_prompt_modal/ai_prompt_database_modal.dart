import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/ai/service/ai_prompt_database_selector_cubit.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/view_item.dart';
import 'package:appflowy/workspace/presentation/widgets/dialog_v2.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:expandable/expandable.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 显示自定义提示词数据库配置对话框
/// 
/// 功能说明：
/// 1. 允许用户选择存储自定义提示词的数据库
/// 2. 支持选择数据库中的特定字段作为提示词名称和内容
/// 3. 验证所选数据库和字段的有效性
/// 
/// 参数：
/// - [context]: 构建上下文
/// - [config]: 当前的数据库配置（可选）
/// 
/// 返回值：
/// - 用户选择的新配置，取消返回null
Future<CustomPromptDatabaseConfig?> changeCustomPromptDatabaseConfig(
  BuildContext context, {
  CustomPromptDatabaseConfig? config,
}) async {
  return showDialog<CustomPromptDatabaseConfig?>(
    context: context,
    builder: (_) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: context.read<UserWorkspaceBloc>(),
          ),
          BlocProvider(
            create: (context) => AiPromptDatabaseSelectorCubit(
              configuration: config,  // 传入当前配置作为初始值
            ),
          ),
        ],
        child: const AiPromptDatabaseModal(),
      );
    },
  );
}

/// AI提示词数据库配置模态框
/// 
/// 功能架构：
/// 1. 数据库选择器：显示可用的数据库列表
/// 2. 字段映射配置：选择名称和内容字段
/// 3. 可展开面板：根据选择状态自动展开/折叠
/// 
/// 交互设计：
/// - 选择数据库后自动展开字段配置面板
/// - 无效数据库时显示错误提示
/// - 支持取消和确认操作
class AiPromptDatabaseModal extends StatefulWidget {
  const AiPromptDatabaseModal({
    super.key,
  });

  @override
  State<AiPromptDatabaseModal> createState() => _AiPromptDatabaseModalState();
}

class _AiPromptDatabaseModalState extends State<AiPromptDatabaseModal> {
  // 可展开面板控制器，初始为折叠状态
  final expandableController = ExpandableController(initialExpanded: false);

  @override
  void dispose() {
    expandableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocListener<AiPromptDatabaseSelectorCubit,
        AiPromptDatabaseSelectorState>(
      // 监听状态变化，处理不同情况
      listener: (context, state) {
        state.maybeMap(
          // 数据库无效时显示错误对话框
          invalidDatabase: (_) {
            showSimpleAFDialog(
              context: context,
              title: LocaleKeys.ai_customPrompt_invalidDatabase.tr(),
              content: LocaleKeys.ai_customPrompt_invalidDatabaseHelp.tr(),
              primaryAction: (
                LocaleKeys.button_ok.tr(),
                (context) {},
              ),
            );
          },
          // 未选择数据库时折叠面板
          empty: (_) => expandableController.expanded = false,
          // 已选择数据库时展开面板
          selected: (_) => expandableController.expanded = true,
          orElse: () {},
        );
      },
      child: AFModal(
        // 设置模态框尺寸约束
        constraints: const BoxConstraints(
          maxWidth: 450,
          maxHeight: 400,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 模态框头部
            AFModalHeader(
              leading: Text(
                LocaleKeys.ai_customPrompt_configureDatabase.tr(),  // "配置数据库"
                style: theme.textStyle.heading4.prominent(
                  color: theme.textColorScheme.primary,
                ),
              ),
              trailing: [
                // 关闭按钮
                AFGhostButton.normal(
                  onTap: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.all(theme.spacing.xs),
                  builder: (context, isHovering, disabled) {
                    return Center(
                      child: FlowySvg(
                        FlowySvgs.toast_close_s,
                        size: Size.square(20),
                      ),
                    );
                  },
                ),
              ],
            ),
            // 模态框主体内容
            Flexible(
              child: AFModalBody(
                child: ExpandablePanel(
                  controller: expandableController,
                  // 配置可展开面板的交互行为
                  theme: ExpandableThemeData(
                    tapBodyToCollapse: false,  // 不允许点击主体折叠
                    hasIcon: false,            // 不显示展开/折叠图标
                    tapBodyToExpand: false,    // 不允许点击主体展开
                    tapHeaderToExpand: false,  // 不允许点击头部展开
                  ),
                  header: const _Header(),       // 数据库选择器头部
                  collapsed: const SizedBox.shrink(),  // 折叠时显示空组件
                  expanded: const _Expanded(),   // 展开时显示字段配置
                ),
              ),
            ),
            // 模态框底部按钮栏
            AFModalFooter(
              trailing: [
                // 取消按钮
                AFOutlinedButton.normal(
                  onTap: () => Navigator.of(context).pop(),
                  builder: (context, isHovering, disabled) {
                    return Text(
                      LocaleKeys.button_cancel.tr(),
                      style: theme.textStyle.body.standard(
                        color: theme.textColorScheme.primary,
                      ),
                    );
                  },
                ),
                // 完成按钮
                AFFilledButton.primary(
                  onTap: () {
                    // 获取当前选择的配置
                    final config = context
                        .read<AiPromptDatabaseSelectorCubit>()
                        .state
                        .maybeMap(
                          selected: (state) => state.config,
                          orElse: () => null,
                        );
                    // 返回配置并关闭对话框
                    Navigator.of(context).pop(config);
                  },
                  builder: (context, isHovering, disabled) {
                    return Text(
                      LocaleKeys.button_done.tr(),
                      style: theme.textStyle.body.enhanced(
                        color: theme.textColorScheme.onFill,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 数据库选择器头部组件
/// 
/// 功能：显示当前选中的数据库，并提供下拉选择器更换数据库
class _Header extends StatefulWidget {
  const _Header();

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  // 弹出层控制器，用于管理数据库选择器下拉菜单
  final popoverController = AFPopoverController();

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocBuilder<AiPromptDatabaseSelectorCubit,
        AiPromptDatabaseSelectorState>(
      builder: (context, state) {
        bool showNothing = false;
        String? viewName;
        state.maybeMap(
          empty: (_) {
            showNothing = false;
            viewName = null;
          },
          selected: (selectedState) {
            showNothing = false;
            viewName = selectedState.config.view.nameOrDefault;
          },
          orElse: () {
            showNothing = true;
            viewName = null;
          },
        );

        if (showNothing) {
          return SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.m,
            vertical: theme.spacing.xl,
          ),
          child: Row(
            spacing: theme.spacing.s,
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.ai_customPrompt_selectDatabase.tr(),
                  style: theme.textStyle.body.standard(
                    color: theme.textColorScheme.secondary,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ViewSelector(
                    viewSelectorCubit: BlocProvider(
                      create: (context) => ViewSelectorCubit(
                        getIgnoreViewType: getIgnoreViewType,
                      ),
                    ),
                    child: BlocSelector<SpaceBloc, SpaceState,
                        (List<ViewPB>, ViewPB?)>(
                      selector: (state) => (state.spaces, state.currentSpace),
                      builder: (context, state) {
                        return AFPopover(
                          controller: popoverController,
                          decoration: BoxDecoration(
                            color: theme.surfaceColorScheme.primary,
                            borderRadius:
                                BorderRadius.circular(theme.borderRadius.l),
                            border: Border.all(
                              color: theme.borderColorScheme.primary,
                            ),
                            boxShadow: theme.shadow.medium,
                          ),
                          padding: EdgeInsets.zero,
                          anchor: AFAnchor(
                            childAlignment: Alignment.topCenter,
                            overlayAlignment: Alignment.bottomCenter,
                            offset: Offset(0, theme.spacing.xs),
                          ),
                          popover: (context) {
                            return _PopoverContent(
                              onSelectViewItem: (item) {
                                context
                                    .read<AiPromptDatabaseSelectorCubit>()
                                    .selectDatabaseView(item.view.id);
                                popoverController.hide();
                              },
                            );
                          },
                          child: AFOutlinedButton.normal(
                            onTap: () {
                              context
                                  .read<ViewSelectorCubit>()
                                  .refreshSources(state.$1, state.$2);
                              popoverController.toggle();
                            },
                            builder: (context, isHovering, disabled) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: theme.spacing.s,
                                children: [
                                  Flexible(
                                    child: Text(
                                      viewName ??
                                          LocaleKeys
                                              .ai_customPrompt_selectDatabase
                                              .tr(),
                                      style: theme.textStyle.body.enhanced(
                                        color: theme.textColorScheme.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  FlowySvg(
                                    FlowySvgs.toolbar_arrow_down_m,
                                    color: theme.iconColorScheme.primary,
                                    size: Size(12, 20),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 判断视图项是否应该被忽略
  /// 
  /// 规则：
  /// 1. 数据库视图总是显示
  /// 2. 文档视图：如果包含数据库子视图则显示，否则隐藏
  /// 3. 其他类型视图一律隐藏
  IgnoreViewType getIgnoreViewType(ViewSelectorItem item) {
    final layout = item.view.layout;

    if (layout.isDatabaseView) {
      return IgnoreViewType.none;  // 数据库视图直接显示
    }
    if (layout.isDocumentView) {
      // 文档视图：检查是否有数据库子视图
      return hasDatabaseDescendent(item)
          ? IgnoreViewType.none
          : IgnoreViewType.hide;
    }
    return IgnoreViewType.hide;
  }

  /// 递归检查视图是否包含数据库子视图
  /// 
  /// 用于判断文档视图是否应该在选择器中显示
  bool hasDatabaseDescendent(ViewSelectorItem viewSelectorItem) {
    final layout = viewSelectorItem.view.layout;

    // 聊天视图不包含数据库
    if (layout == ViewLayoutPB.Chat) {
      return false;
    }

    // 当前就是数据库视图
    if (layout.isDatabaseView) {
      return true;
    }

    // 递归检查所有子视图
    return viewSelectorItem.children.any(
      (child) => hasDatabaseDescendent(child),
    );
  }
}

/// 展开面板组件
/// 
/// 功能：显示数据库字段映射配置
/// 允许用户选择标题、内容、示例和分类字段
class _Expanded extends StatelessWidget {
  const _Expanded();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocBuilder<AiPromptDatabaseSelectorCubit,
        AiPromptDatabaseSelectorState>(
      builder: (context, state) {
        return state.maybeMap(
          orElse: () => SizedBox.shrink(),
          selected: (selectedState) {
            return Padding(
              padding: EdgeInsets.all(theme.spacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.spacing.m,
                children: [
                  // 标题字段选择器（禁用，默认使用第一个字段）
                  FieldSelector(
                    title: LocaleKeys.ai_customPrompt_title.tr(),
                    currentFieldId: selectedState.config.titleFieldId,
                    isDisabled: true,  // 标题固定为第一个字段
                    fields: selectedState.fields,
                    onSelect: (id) {},
                  ),
                  // 内容字段选择器（必选，仅显示富文本字段）
                  FieldSelector(
                    title: LocaleKeys.ai_customPrompt_content.tr(),
                    currentFieldId: selectedState.config.contentFieldId,
                    fields: selectedState.fields
                        .where((f) => f.fieldType == FieldType.RichText)  // 过滤富文本字段
                        .toList(),
                    onSelect: (id) {
                      if (id != null) {
                        context
                            .read<AiPromptDatabaseSelectorCubit>()
                            .selectContentField(id);
                      }
                    },
                  ),
                  // 示例字段选择器（可选，仅显示富文本字段）
                  FieldSelector(
                    title: LocaleKeys.ai_customPrompt_example.tr(),
                    currentFieldId: selectedState.config.exampleFieldId,
                    isOptional: true,  // 可选字段
                    fields: selectedState.fields
                        .where((f) => f.fieldType == FieldType.RichText)
                        .toList(),
                    onSelect: (id) {
                      context
                          .read<AiPromptDatabaseSelectorCubit>()
                          .selectExampleField(id);
                    },
                  ),
                  // 分类字段选择器（可选，支持富文本和选择器字段）
                  FieldSelector(
                    title: LocaleKeys.ai_customPrompt_category.tr(),
                    currentFieldId: selectedState.config.categoryFieldId,
                    isOptional: true,
                    fields: selectedState.fields
                        .where(
                          (f) =>
                              f.fieldType == FieldType.RichText ||     // 支持富文本
                              f.fieldType == FieldType.SingleSelect || // 支持单选
                              f.fieldType == FieldType.MultiSelect,    // 支持多选
                        )
                        .toList(),
                    onSelect: (id) {
                      context
                          .read<AiPromptDatabaseSelectorCubit>()
                          .selectCategoryField(id);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 数据库选择器弹出层内容
/// 
/// 功能：
/// 1. 显示所有可用的数据库视图
/// 2. 支持搜索过滤
/// 3. 树形结构展示视图层级
class _PopoverContent extends StatefulWidget {
  const _PopoverContent({
    required this.onSelectViewItem,
  });

  final void Function(ViewSelectorItem item) onSelectViewItem;

  @override
  State<_PopoverContent> createState() => _PopoverContentState();
}

class _PopoverContentState extends State<_PopoverContent> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 在下一帧请求焦点，确保搜索框自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(
        width: 300,
        height: 400,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VSpace(
            theme.spacing.m,
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.m,
            ),
            child: AFTextField(
              focusNode: focusNode,
              size: AFTextFieldSize.m,
              hintText: LocaleKeys.search_label.tr(),
              controller:
                  context.read<ViewSelectorCubit>().filterTextController,
            ),
          ),
          VSpace(
            theme.spacing.m,
          ),
          AFDivider(),
          Expanded(
            child: BlocBuilder<ViewSelectorCubit, ViewSelectorState>(
              builder: (context, state) {
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  children: _buildVisibleSources(context, state).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Iterable<Widget> _buildVisibleSources(
    BuildContext context,
    ViewSelectorState state,
  ) {
    return state.visibleSources.map(
      (e) => ViewSelectorTreeItem(
        key: ValueKey(
          'custom_prompt_database_tree_item_${e.view.id}',
        ),
        viewSelectorItem: e,
        level: 0,
        isDescendentOfSpace: e.view.isSpace,
        isSelectedSection: false,
        showCheckbox: false,
        onSelected: (item) {
          if (item.view.isDocument || item.view.isSpace) {
            context.read<ViewSelectorCubit>().toggleIsExpanded(item, false);
            return;
          }
          widget.onSelectViewItem(item);
        },
        height: 30.0,
      ),
    );
  }
}

/// 字段包装器
/// 
/// 将FieldPB对象包装为下拉菜单项
class _FieldPBWrapper extends Equatable with AFDropDownMenuMixin {
  const _FieldPBWrapper(this.field);

  final FieldPB field;

  @override
  String get label => field.name;  // 显示字段名称

  @override
  List<Object?> get props => [field.id];  // 使用字段ID作为唯一标识
}

/// 字段选择器组件
/// 
/// 功能：
/// 1. 显示字段名称和下拉选择器
/// 2. 支持禁用、可选等配置
/// 3. 可选字段支持清除功能
/// 
/// 参数：
/// - [title]: 字段选择器标题
/// - [currentFieldId]: 当前选中的字段ID
/// - [isDisabled]: 是否禁用选择器
/// - [isOptional]: 是否为可选字段
/// - [fields]: 可供选择的字段列表
/// - [onSelect]: 选择回调函数
class FieldSelector extends StatelessWidget {
  const FieldSelector({
    super.key,
    required this.title,
    required this.currentFieldId,
    this.isDisabled = false,
    this.isOptional = false,
    this.fields = const [],
    required this.onSelect,
  });

  final String title;
  final String? currentFieldId;
  final bool isDisabled;
  final bool isOptional;
  final List<FieldPB> fields;
  final void Function(String? id)? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final selectedField = fields.firstWhereOrNull(
      (field) => field.id == currentFieldId,
    );

    return Row(
      spacing: theme.spacing.s,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textStyle.body.standard(
              color: theme.textColorScheme.secondary,
            ),
          ),
        ),
        Expanded(
          child: AFDropDownMenu<_FieldPBWrapper>(
            isDisabled: isDisabled,
            items: fields.map((field) => _FieldPBWrapper(field)).toList(),
            selectedItems: [
              if (selectedField != null) _FieldPBWrapper(selectedField),
            ],
            clearIcon: selectedField == null ||
                    !fields.contains(selectedField) ||
                    !isOptional
                ? null
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        onSelect?.call(null);
                      },
                      child: FlowySvg(
                        FlowySvgs.search_clear_m,
                        size: Size.square(16),
                        color: theme.iconColorScheme.tertiary,
                      ),
                    ),
                  ),
            onSelected: (value) {
              if (value == null) {
                return;
              }
              onSelect?.call(value.field.id);
            },
            dropdownIcon: FlowySvg(
              FlowySvgs.toolbar_arrow_down_m,
              color: theme.iconColorScheme.primary,
              size: Size(12, 20),
            ),
          ),
        ),
      ],
    );
  }
}
