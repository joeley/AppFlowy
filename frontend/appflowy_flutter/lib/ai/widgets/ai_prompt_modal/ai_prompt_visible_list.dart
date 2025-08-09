import 'dart:async';

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:diffutil_dart/diffutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai_prompt_database_modal.dart';

// 列表项动画的持续时间
const Duration _listItemAnimationDuration = Duration(milliseconds: 150);

/// AI提示词可见列表组件
/// 
/// 功能说明：
/// 1. 显示当前分类或搜索结果下的所有提示词
/// 2. 支持搜索过滤功能
/// 3. 支持动画列表项的增删
/// 4. 显示自定义提示词数据库信息
/// 
/// 技术特点：
/// - 使用AnimatedList实现平滑的列表动画
/// - 使用diffutil计算列表差异，优化更新性能
/// - 悬停自动选中，提升用户体验
/// - 实时搜索过滤，响应式更新
class AiPromptVisibleList extends StatefulWidget {
  const AiPromptVisibleList({
    super.key,
  });

  @override
  State<AiPromptVisibleList> createState() => _AiPromptVisibleListState();
}

class _AiPromptVisibleListState extends State<AiPromptVisibleList> {
  // AnimatedList的key，用于控制列表项动画
  final listKey = GlobalKey<AnimatedListState>();
  // 滚动控制器
  final scrollController = ScrollController();
  // 保存旧列表，用于计算差异
  final List<AiPrompt> oldList = [];

  late AiPromptSelectorCubit cubit;
  // 搜索框是否为空，用于控制清除按钮显示
  late bool filterIsEmpty;

  @override
  void initState() {
    super.initState();
    cubit = context.read<AiPromptSelectorCubit>();
    final textController = cubit.filterTextController;
    filterIsEmpty = textController.text.isEmpty;
    // 监听搜索文本变化
    textController.addListener(handleFilterTextChanged);
    // 初始化旧列表
    final prompts = cubit.state.maybeMap(
      ready: (value) => value.visiblePrompts,
      orElse: () => <AiPrompt>[],
    );
    oldList.addAll(prompts);
  }

  @override
  void dispose() {
    // 清理监听器和控制器
    cubit.filterTextController.removeListener(handleFilterTextChanged);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      children: [
        // 自定义提示词数据库信息栏
        BlocConsumer<AiPromptSelectorCubit, AiPromptSelectorState>(
          // 监听状态变化，更新列表动画
          listener: (context, state) {
            state.maybeMap(
              ready: (state) {
                // 当可见提示词列表变化时，触发动画更新
                handleVisiblePromptListChanged(state.visiblePrompts);
              },
              orElse: () {},
            );
          },
          // 优化重建条件：只在特定属性变化时重建
          buildWhen: (p, c) {
            return p.maybeMap(
              ready: (pr) => c.maybeMap(
                ready: (cr) =>
                    pr.databaseConfig?.view.id != cr.databaseConfig?.view.id ||  // 数据库配置变化
                    pr.isLoadingCustomPrompts != cr.isLoadingCustomPrompts ||    // 加载状态变化
                    pr.isCustomPromptSectionSelected !=
                        cr.isCustomPromptSectionSelected,                         // 选中状态变化
                orElse: () => false,
              ),
              orElse: () => true,
            );
          },
          builder: (context, state) {
            return state.maybeMap(
              ready: (readyState) {
                if (!readyState.isCustomPromptSectionSelected) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: EdgeInsets.only(
                    left: theme.spacing.l,
                    right: theme.spacing.l,
                    bottom: theme.spacing.l,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(theme.borderRadius.m),
                    color: theme.surfaceContainerColorScheme.layer01,
                  ),
                  padding: EdgeInsets.all(theme.spacing.m),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    "${LocaleKeys.ai_customPrompt_promptDatabase.tr()}: ",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: readyState
                                        .databaseConfig?.view.nameOrDefault ??
                                    "",
                              ),
                            ],
                          ),
                          style: theme.textStyle.body.standard(
                            color: theme.textColorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 150,
                        ),
                        child: AFOutlinedButton.normal(
                          builder: (context, isHovering, disabled) {
                            return Row(
                              spacing: theme.spacing.s,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (readyState.isLoadingCustomPrompts)
                                  buildLoadingIndicator(theme),
                                Flexible(
                                  child: Text(
                                    readyState.isLoadingCustomPrompts
                                        ? LocaleKeys.ai_customPrompt_loading
                                            .tr()
                                        : LocaleKeys.button_change.tr(),
                                    maxLines: 1,
                                    style: theme.textStyle.body.enhanced(
                                      color: theme.textColorScheme.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                          onTap: () async {
                            final newConfig =
                                await changeCustomPromptDatabaseConfig(
                              context,
                              config: readyState.databaseConfig,
                            );
                            if (newConfig != null && context.mounted) {
                              context
                                  .read<AiPromptSelectorCubit>()
                                  .updateCustomPromptDatabaseConfiguration(
                                    newConfig,
                                  );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.l),
          child: buildSearchField(context),
        ),
        Expanded(
          child: TextFieldTapRegion(
            groupId: "ai_prompt_category_list",
            child: BlocBuilder<AiPromptSelectorCubit, AiPromptSelectorState>(
              builder: (context, state) {
                return state.maybeMap(
                  ready: (readyState) {
                    if (readyState.visiblePrompts.isEmpty) {
                      return buildEmptyPrompts();
                    }
                    return buildPromptList();
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 构建搜索输入框
  /// 
  /// 功能：
  /// - 自动聚焦，方便用户快速搜索
  /// - 动态显示清除按钮
  /// - 实时过滤提示词列表
  Widget buildSearchField(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final iconSize = 20.0;

    return AFTextField(
      groupId: "ai_prompt_category_list",
      hintText: "Search",
      controller: context.read<AiPromptSelectorCubit>().filterTextController,
      autoFocus: true,  // 自动聚焦，提升用户体验
      suffixIconConstraints: BoxConstraints.tightFor(
        width: iconSize + theme.spacing.m,
        height: iconSize,
      ),
      // 条件渲染清除按钮：仅在有输入时显示
      suffixIconBuilder: filterIsEmpty
          ? null
          : (context, isObscured) => TextFieldTapRegion(
                groupId: "ai_prompt_category_list",
                child: Padding(
                  padding: EdgeInsets.only(right: theme.spacing.m),
                  child: GestureDetector(
                    onTap: () => context
                        .read<AiPromptSelectorCubit>()
                        .filterTextController
                        .clear(),  // 清空搜索文本
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: FlowySvg(
                        FlowySvgs.search_clear_m,
                        color: theme.iconColorScheme.tertiary,
                        size: const Size.square(20),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  /// 构建空结果界面
  /// 
  /// 当搜索无结果或分类下无提示词时显示
  Widget buildEmptyPrompts() {
    final theme = AppFlowyTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索图标
          FlowySvg(
            FlowySvgs.m_home_search_icon_m,
            color: theme.iconColorScheme.secondary,
            size: Size.square(24),
          ),
          VSpace(theme.spacing.m),
          // 无结果提示文本
          Text(
            LocaleKeys.ai_customPrompt_noResults.tr(),
            style: theme.textStyle.body
                .standard(color: theme.textColorScheme.secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 构建提示词列表
  /// 
  /// 使用AnimatedList实现列表项的动画效果
  /// 监听状态变化，实时更新选中状态
  Widget buildPromptList() {
    final theme = AppFlowyTheme.of(context);

    return AnimatedList(
      controller: scrollController,
      padding: EdgeInsets.all(theme.spacing.l),
      key: listKey,
      initialItemCount: oldList.length,
      itemBuilder: (context, index, animation) {
        return BlocBuilder<AiPromptSelectorCubit, AiPromptSelectorState>(
          builder: (context, state) {
            return state.maybeMap(
              ready: (state) {
                final prompt = state.visiblePrompts[index];

                return Padding(
                  // 首尾项特殊处理间距
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : theme.spacing.s,
                    bottom: index == state.visiblePrompts.length - 1
                        ? 0
                        : theme.spacing.s,
                  ),
                  child: _AiPromptListItem(
                    animation: animation,
                    prompt: prompt,
                    isSelected: state.selectedPromptId == prompt.id,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  /// 构建加载指示器
  /// 
  /// 用于显示自定义提示词加载中的状态
  Widget buildLoadingIndicator(AppFlowyThemeData theme) {
    return SizedBox.square(
      dimension: 20,
      child: Padding(
        padding: EdgeInsets.all(2.5),
        child: CircularProgressIndicator(
          color: theme.iconColorScheme.tertiary,
          strokeWidth: 2.0,
        ),
      ),
    );
  }

  /// 处理可见提示词列表变化
  /// 
  /// 使用diffutil算法计算新旧列表差异，
  /// 并应用相应的动画效果（插入/删除）
  /// 
  /// [newList] 新的提示词列表
  void handleVisiblePromptListChanged(
    List<AiPrompt> newList,
  ) {
    // 计算列表差异
    final updates = calculateListDiff(oldList, newList).getUpdatesWithData();

    // 根据差异类型执行不同的动画
    for (final update in updates) {
      update.when(
        // 插入新项
        insert: (pos, data) {
          listKey.currentState?.insertItem(
            pos,
            duration: _listItemAnimationDuration,
          );
        },
        // 移除项
        remove: (pos, data) {
          listKey.currentState?.removeItem(
            pos,
            (context, animation) {
              // 创建移除动画的组件
              final isSelected =
                  context.read<AiPromptSelectorCubit>().state.maybeMap(
                        ready: (state) => state.selectedPromptId == data.id,
                        orElse: () => false,
                      );
              return _AiPromptListItem(
                animation: animation,
                prompt: data,
                isSelected: isSelected,
              );
            },
            duration: _listItemAnimationDuration,
          );
        },
        // 项内容变化（当前未处理）
        change: (pos, oldData, newData) {},
        // 项移动（当前未处理）
        move: (from, to, data) {},
      );
    }
    // 更新旧列表缓存
    oldList
      ..clear()
      ..addAll(newList);
  }

  /// 处理搜索文本变化
  /// 
  /// 更新清除按钮的显示状态
  void handleFilterTextChanged() {
    setState(() {
      filterIsEmpty = cubit.filterTextController.text.isEmpty;
    });
  }
}

/// 提示词列表项组件
/// 
/// 功能：
/// 1. 显示单个提示词的名称和内容预览
/// 2. 支持选中状态和悬停效果
/// 3. 悬停时显示"使用提示词"按钮
/// 4. 支持进入/退出动画
/// 
/// 交互设计：
/// - 悬停300ms后自动选中（提升浏览效率）
/// - 点击可立即选中
/// - 悬停时显示使用按钮，方便快速应用
class _AiPromptListItem extends StatefulWidget {
  const _AiPromptListItem({
    required this.animation,
    required this.prompt,
    required this.isSelected,
  });

  // 列表项动画控制器
  final Animation<double> animation;
  // 提示词数据
  final AiPrompt prompt;
  // 是否选中状态
  final bool isSelected;

  @override
  State<_AiPromptListItem> createState() => _AiPromptListItemState();
}

class _AiPromptListItemState extends State<_AiPromptListItem> {
  // 悬停状态
  bool isHovering = false;
  // 延迟选中的定时器
  Timer? timer;

  @override
  void dispose() {
    // 清理定时器，防止内存泄漏
    timer?.cancel();
    timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final cubit = context.read<AiPromptSelectorCubit>();

    // 创建缓动动画，使动画效果更自然
    final curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeIn,
    );

    // 定义悬停时的背景色（根据主题模式）
    final surfacePrimaryHover =
        Theme.of(context).isLightMode ? Color(0xFFF8FAFF) : Color(0xFF3C3F4E);

    // 使用淡入淡出和尺寸变化的组合动画
    return FadeTransition(
      opacity: curvedAnimation,
      child: SizeTransition(
        sizeFactor: curvedAnimation,
        child: MouseRegion(
          // 鼠标进入时：设置悬停状态，启动延迟选中定时器
          onEnter: (_) {
            setState(() {
              isHovering = true;
              // 300ms后自动选中，提升浏览效率
              timer = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  cubit.selectPrompt(widget.prompt.id);
                }
              });
            });
          },
          // 鼠标离开时：取消悬停状态和定时器
          onExit: (_) {
            setState(() {
              isHovering = false;
              timer?.cancel();
            });
          },
          child: GestureDetector(
            onTap: () {
              cubit.selectPrompt(widget.prompt.id);
            },
            child: Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(theme.spacing.m),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(theme.borderRadius.m),
                    color: Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected
                          ? isHovering
                              ? theme.borderColorScheme.themeThickHover
                              : theme.borderColorScheme.themeThick
                          : isHovering
                              ? theme.borderColorScheme.primaryHover
                              : theme.borderColorScheme.primary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.prompt.name,
                              maxLines: 1,
                              style: theme.textStyle.body.standard(
                                color: theme.textColorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.prompt.content,
                        maxLines: 2,
                        style: theme.textStyle.caption.standard(
                          color: theme.textColorScheme.secondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                if (isHovering)
                  Positioned(
                    top: theme.spacing.s,
                    right: theme.spacing.s,
                    child: DecoratedBox(
                      decoration: BoxDecoration(boxShadow: theme.shadow.small),
                      child: AFBaseButton(
                        onTap: () {
                          Navigator.of(context).pop(widget.prompt);
                        },
                        builder: (context, isHovering, disabled) {
                          return Text(
                            LocaleKeys.ai_customPrompt_usePrompt.tr(),
                            style: theme.textStyle.body.standard(
                              color: theme.textColorScheme.primary,
                            ),
                          );
                        },
                        backgroundColor: (context, isHovering, disabled) {
                          if (isHovering) {
                            return surfacePrimaryHover;
                          }
                          return theme.surfaceColorScheme.primary;
                        },
                        padding: EdgeInsets.symmetric(
                          vertical: theme.spacing.s,
                          horizontal: theme.spacing.m,
                        ),
                        borderRadius: theme.borderRadius.m,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
