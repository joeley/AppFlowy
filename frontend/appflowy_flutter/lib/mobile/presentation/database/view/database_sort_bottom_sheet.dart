// 导入SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入本地化键值对
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar_actions.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/application/field/sort_entities.dart';
import 'package:appflowy/plugins/database/grid/application/sort/sort_editor_bloc.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/header/desktop_field_cell.dart';
import 'package:appflowy/util/field_type_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';

// 导入排序底部弹窗的Cubit状态管理
import 'database_sort_bottom_sheet_cubit.dart';

/// 移动端数据库排序编辑器
/// 
/// 这是AppFlowy数据库功能中用于移动端排序管理的核心组件。
/// 设计思想：
/// 1. 使用PageView实现双页面架构：概览页和详情编辑页
/// 2. 集成Cubit状态管理，统一处理排序编辑逻辑
/// 3. 支持全数据类型的排序功能，包括升序和降序
/// 4. 支持拖拽重排排序优先级，直观的交互体验
/// 
/// 主要功能：
/// - 排序条件概览列表
/// - 创建新排序条件
/// - 编辑现有排序条件
/// - 拖拽重排优先级
/// - 删除排序条件
class MobileSortEditor extends StatefulWidget {
  const MobileSortEditor({
    super.key,
  });

  @override
  State<MobileSortEditor> createState() => _MobileSortEditorState();
}

/// 移动端排序编辑器的状态管理类
class _MobileSortEditorState extends State<MobileSortEditor> {
  /// PageView控制器，管理概览和详情页面的切换
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MobileSortEditorCubit(
        pageController: _pageController,
      ),
      child: Column(
        children: [
          const _Header(),
          SizedBox(
            height: 400, //314,
            child: PageView.builder(
              controller: _pageController,
              itemCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return index == 0
                    ? Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom,
                        ),
                        child: const _Overview(),
                      )
                    : const _SortDetail();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 排序编辑器的头部导航栏组件
/// 负责显示标题、返回按钮和保存按钮
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MobileSortEditorCubit, MobileSortEditorState>(
      builder: (context, state) {
        return SizedBox(
          height: 44.0,
          child: Stack(
            children: [
              if (state.showBackButton)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppBarBackButton(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    onTap: () => context
                        .read<MobileSortEditorCubit>()
                        .returnToOverview(),
                  ),
                ),
              Align(
                child: FlowyText.medium(
                  LocaleKeys.grid_settings_sort.tr(),
                  fontSize: 16.0,
                ),
              ),
              if (state.isCreatingNewSort)
                Align(
                  alignment: Alignment.centerRight,
                  child: AppBarSaveButton(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    enable: state.newSortFieldId != null,
                    onTap: () {
                      _tryCreateSort(context, state);
                      context.read<MobileSortEditorCubit>().returnToOverview();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _tryCreateSort(BuildContext context, MobileSortEditorState state) {
    if (state.newSortFieldId != null && state.newSortCondition != null) {
      context.read<SortEditorBloc>().add(
            SortEditorEvent.createSort(
              fieldId: state.newSortFieldId!,
              condition: state.newSortCondition!,
            ),
          );
    }
  }
}

/// 排序概览页面组件
/// 显示所有现有的排序条件和添加新排序的按钮
class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SortEditorBloc, SortEditorState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: state.sorts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FlowySvg(
                            FlowySvgs.sort_descending_s,
                            size: const Size.square(60),
                            color: Theme.of(context).hintColor,
                          ),
                          FlowyText(
                            LocaleKeys.grid_sort_empty.tr(),
                            color: Theme.of(context).hintColor,
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: (oldIndex, newIndex) => context
                          .read<SortEditorBloc>()
                          .add(SortEditorEvent.reorderSort(oldIndex, newIndex)),
                      itemCount: state.sorts.length,
                      itemBuilder: (context, index) => _SortItem(
                        key: ValueKey("sort_item_$index"),
                        sort: state.sorts[index],
                      ),
                    ),
            ),
            Container(
              height: 44,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(
                    width: 0.5,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                borderRadius: Corners.s10Border,
              ),
              child: InkWell(
                onTap: () {
                  final firstField = context
                      .read<SortEditorBloc>()
                      .state
                      .creatableFields
                      .firstOrNull;
                  if (firstField == null) {
                    Fluttertoast.showToast(
                      msg: LocaleKeys.grid_sort_cannotFindCreatableField.tr(),
                      gravity: ToastGravity.BOTTOM,
                    );
                  } else {
                    context.read<MobileSortEditorCubit>().startCreatingSort();
                  }
                },
                borderRadius: Corners.s10Border,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FlowySvg(
                        FlowySvgs.add_s,
                        size: Size.square(16),
                      ),
                      const HSpace(6.0),
                      FlowyText(
                        LocaleKeys.grid_sort_addSort.tr(),
                        fontSize: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 排序条件卡片组件
/// 展示单个排序条件的详细信息和操作按钮
class _SortItem extends StatelessWidget {
  const _SortItem({super.key, required this.sort});

  /// 数据库排序条件对象
  final DatabaseSort sort;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).hoverColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context
                .read<MobileSortEditorCubit>()
                .startEditingSort(sort.sortId),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: FlowyText.medium(
                      LocaleKeys.grid_sort_by.tr(),
                      fontSize: 15,
                    ),
                  ),
                  const VSpace(10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.fromBorderSide(
                              BorderSide(
                                width: 0.5,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            borderRadius: Corners.s10Border,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: Row(
                              children: [
                                Expanded(
                                  child: BlocSelector<SortEditorBloc,
                                      SortEditorState, FieldInfo?>(
                                    selector: (state) =>
                                        state.allFields.firstWhereOrNull(
                                      (field) => field.id == sort.fieldId,
                                    ),
                                    builder: (context, field) {
                                      return FlowyText(
                                        field?.name ?? "",
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ),
                                const HSpace(6.0),
                                FlowySvg(
                                  FlowySvgs.icon_right_small_ccm_outlined_s,
                                  size: const Size.square(14),
                                  color: Theme.of(context).hintColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const HSpace(6),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.fromBorderSide(
                              BorderSide(
                                width: 0.5,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            borderRadius: Corners.s10Border,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          padding: const EdgeInsetsDirectional.only(
                            start: 12,
                            end: 10,
                          ),
                          child: Center(
                            child: Row(
                              children: [
                                Expanded(
                                  child: FlowyText(
                                    sort.condition.name,
                                  ),
                                ),
                                const HSpace(6.0),
                                FlowySvg(
                                  FlowySvgs.icon_right_small_ccm_outlined_s,
                                  size: const Size.square(14),
                                  color: Theme.of(context).hintColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 6,
            child: InkWell(
              onTap: () => context
                  .read<SortEditorBloc>()
                  .add(SortEditorEvent.deleteSort(sort.sortId)),
              // steal from the container LongClickReorderWidget thing
              onLongPress: () {},
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 34,
                child: Center(
                  child: FlowySvg(
                    FlowySvgs.trash_m,
                    size: const Size.square(18),
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 排序详情编辑页面组件
/// 根据当前状态显示创建新排序或编辑现有排序的界面
class _SortDetail extends StatelessWidget {
  const _SortDetail();

  @override
  Widget build(BuildContext context) {
    final isCreatingNewSort =
        context.read<MobileSortEditorCubit>().state.isCreatingNewSort;

    return isCreatingNewSort
        ? const _SortDetailContent()
        : BlocSelector<SortEditorBloc, SortEditorState, DatabaseSort>(
            selector: (state) => state.sorts.firstWhere(
              (sort) =>
                  sort.sortId ==
                  context.read<MobileSortEditorCubit>().state.editingSortId,
            ),
            builder: (context, sort) {
              return _SortDetailContent(sort: sort);
            },
          );
  }
}

/// 排序详情内容组件
/// 包含排序条件选择、字段选择和排序方向选择
class _SortDetailContent extends StatelessWidget {
  const _SortDetailContent({
    this.sort,
  });

  /// 可选的数据库排序条件，为空时表示创建新排序
  final DatabaseSort? sort;

  /// 判断是否为创建新排序模式
  bool get isCreatingNewSort => sort == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VSpace(4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DefaultTabController(
            length: 2,
            initialIndex: isCreatingNewSort
                ? 0
                : sort!.condition == SortConditionPB.Ascending
                    ? 0
                    : 1,
            child: Container(
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).hoverColor,
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.label,
                labelPadding: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                indicatorWeight: 0,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surface,
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                onTap: (index) {
                  final newCondition = index == 0
                      ? SortConditionPB.Ascending
                      : SortConditionPB.Descending;
                  _changeCondition(context, newCondition);
                },
                tabs: [
                  Tab(
                    height: 34,
                    child: Center(
                      child: FlowyText(
                        LocaleKeys.grid_sort_ascending.tr(),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Tab(
                    height: 34,
                    child: Center(
                      child: FlowyText(
                        LocaleKeys.grid_sort_descending.tr(),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const VSpace(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: FlowyText(
            LocaleKeys.grid_settings_sortBy.tr().toUpperCase(),
            fontSize: 13,
            color: Theme.of(context).hintColor,
          ),
        ),
        const VSpace(4.0),
        const Divider(
          height: 0.5,
          thickness: 0.5,
        ),
        Expanded(
          child: BlocBuilder<SortEditorBloc, SortEditorState>(
            builder: (context, state) {
              final fields = state.allFields
                  .where((field) => field.fieldType.canCreateSort)
                  .toList();
              return ListView.builder(
                itemCount: fields.length,
                itemBuilder: (context, index) {
                  final fieldInfo = fields[index];
                  final isSelected = isCreatingNewSort
                      ? context
                              .watch<MobileSortEditorCubit>()
                              .state
                              .newSortFieldId ==
                          fieldInfo.id
                      : sort!.fieldId == fieldInfo.id;

                  final canSort =
                      fieldInfo.fieldType.canCreateSort && !fieldInfo.hasSort;
                  final beingEdited =
                      !isCreatingNewSort && sort!.fieldId == fieldInfo.id;
                  final enabled = canSort || beingEdited;

                  return FlowyOptionTile.checkbox(
                    text: fieldInfo.field.name,
                    leftIcon: FieldIcon(
                      fieldInfo: fieldInfo,
                    ),
                    isSelected: isSelected,
                    textColor: enabled ? null : Theme.of(context).disabledColor,
                    showTopBorder: false,
                    onTap: () {
                      if (isSelected) {
                        return;
                      }
                      if (enabled) {
                        _changeFieldId(context, fieldInfo.id);
                      } else {
                        Fluttertoast.showToast(
                          msg: LocaleKeys.grid_sort_fieldInUse.tr(),
                          gravity: ToastGravity.BOTTOM,
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _changeCondition(BuildContext context, SortConditionPB newCondition) {
    if (isCreatingNewSort) {
      context.read<MobileSortEditorCubit>().changeSortCondition(newCondition);
    } else {
      context.read<SortEditorBloc>().add(
            SortEditorEvent.editSort(
              sortId: sort!.sortId,
              condition: newCondition,
            ),
          );
    }
  }

  void _changeFieldId(BuildContext context, String newFieldId) {
    if (isCreatingNewSort) {
      context.read<MobileSortEditorCubit>().changeFieldId(newFieldId);
    } else {
      context.read<SortEditorBloc>().add(
            SortEditorEvent.editSort(
              sortId: sort!.sortId,
              fieldId: newFieldId,
            ),
          );
    }
  }
}
