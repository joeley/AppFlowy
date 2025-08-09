import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// AI提示词分类列表组件
/// 
/// 功能说明：
/// 1. 显示AI提示词的分类列表，包括精选、自定义和各种预设分类
/// 2. 支持分类选择和切换，用户可以快速浏览不同类型的提示词
/// 3. 分类包括：精选(Featured)、自定义(Custom)和系统预设分类
/// 
/// 架构设计：
/// - 使用Column布局，包含精选区、自定义区和分类列表三个部分
/// - 通过AiPromptSelectorCubit管理选中状态
/// - 分类列表使用ListView实现滚动
class AiPromptCategoryList extends StatefulWidget {
  const AiPromptCategoryList({
    super.key,
  });

  @override
  State<AiPromptCategoryList> createState() => _AiPromptCategoryListState();
}

class _AiPromptCategoryListState extends State<AiPromptCategoryList> {
  // 搜索状态标记（当前未使用，可能为后续功能预留）
  bool isSearching = false;
  
  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    // TextFieldTapRegion用于处理文本字段的点击区域
    // 保证点击列表项时不会误触发其他文本输入
    return TextFieldTapRegion(
      groupId: "ai_prompt_category_list",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 精选提示词区域
          Padding(
            padding: EdgeInsets.only(
              right: theme.spacing.l,
            ),
            child: AiPromptFeaturedSection(),
          ),
          // 自定义提示词区域
          Padding(
            padding: EdgeInsets.only(
              right: theme.spacing.l,
            ),
            child: AiPromptCustomPromptSection(),
          ),
          // 分隔线，视觉上区分精选/自定义与分类列表
          Padding(
            padding: EdgeInsets.only(
              top: theme.spacing.s,
              right: theme.spacing.l,
            ),
            child: AFDivider(),
          ),
          // 可滚动的分类列表
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                top: theme.spacing.s,
                right: theme.spacing.l,
              ),
              children: [
                // 第一项为"全部"分类，category为null
                _buildCategoryItem(context, null),
                // 其余分类按字母顺序排列
                ...sortedCategories.map(
                  (category) => _buildCategoryItem(
                    context,
                    category,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取排序后的分类列表
  /// 
  /// 实现逻辑：
  /// 1. 复制所有分类枚举值
  /// 2. 按照国际化名称字母顺序排序
  /// 3. 将"其他"分类移到最后（用户体验优化）
  static Iterable<AiPromptCategory> get sortedCategories {
    final categories = [...AiPromptCategory.values];
    categories
      ..sort((a, b) => a.i18n.compareTo(b.i18n))  // 按国际化名称排序
      ..remove(AiPromptCategory.other)             // 移除"其他"分类
      ..add(AiPromptCategory.other);               // 将"其他"添加到末尾

    return categories;
  }

  /// 构建单个分类项
  /// 
  /// [category] null表示"全部"分类，非null为具体分类
  /// 点击后通过AiPromptSelectorCubit更新选中状态
  Widget _buildCategoryItem(
    BuildContext context,
    AiPromptCategory? category,
  ) {
    return AiPromptCategoryItem(
      category: category,
      onSelect: () {
        // 通过BLoC更新选中的分类
        context.read<AiPromptSelectorCubit>().selectCategory(category);
      },
    );
  }
}

/// 精选提示词区域组件
/// 
/// 功能：显示"精选"按钮，用户点击后可查看精选的AI提示词
/// 特点：
/// - 支持选中状态高亮显示
/// - 悬停时显示hover效果
/// - 通过AiPromptSelectorCubit管理选中状态
class AiPromptFeaturedSection extends StatelessWidget {
  const AiPromptFeaturedSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    // 监听当前是否选中精选区域
    final isSelected = context.watch<AiPromptSelectorCubit>().state.maybeMap(
          ready: (state) => state.isFeaturedSectionSelected,
          orElse: () => false,
        );

    return AFBaseButton(
      onTap: () {
        // 未选中时才触发选中事件，避免重复选中
        if (!isSelected) {
          context.read<AiPromptSelectorCubit>().selectFeaturedSection();
        }
      },
      builder: (context, isHovering, disabled) {
        return Text(
          LocaleKeys.ai_customPrompt_featured.tr(),  // 显示国际化的"精选"文本
          style: AppFlowyTheme.of(context).textStyle.body.standard(
                color: theme.textColorScheme.primary,
              ),
          overflow: TextOverflow.ellipsis,
        );
      },
      borderRadius: theme.borderRadius.m,
      padding: EdgeInsets.symmetric(
        vertical: theme.spacing.s,
        horizontal: theme.spacing.m,
      ),
      // 边框始终透明
      borderColor: (context, isHovering, disabled, isFocused) =>
          Colors.transparent,
      // 动态背景色：选中时显示主题选中色，悬停时显示悬停色
      backgroundColor: (context, isHovering, disabled) {
        if (isSelected) {
          return theme.fillColorScheme.themeSelect;
        }
        if (isHovering) {
          return theme.fillColorScheme.contentHover;
        }
        return Colors.transparent;
      },
    );
  }
}

/// 自定义提示词区域组件
/// 
/// 功能：显示"自定义"按钮，用户点击后可查看和管理自定义提示词
/// 特点：
/// - 使用BlocBuilder监听状态变化
/// - 只在ready状态下显示，其他状态返回空组件
/// - 支持选中和悬停状态的视觉反馈
class AiPromptCustomPromptSection extends StatelessWidget {
  const AiPromptCustomPromptSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    // 使用BlocBuilder监听AiPromptSelectorCubit的状态变化
    return BlocBuilder<AiPromptSelectorCubit, AiPromptSelectorState>(
      builder: (context, state) {
        return state.maybeMap(
          ready: (readyState) {
            // 检查自定义区域是否被选中
            final isSelected = readyState.isCustomPromptSectionSelected;

            return AFBaseButton(
              onTap: () {
                // 未选中时才触发选中事件
                if (!isSelected) {
                  context.read<AiPromptSelectorCubit>().selectCustomSection();
                }
              },
              builder: (context, isHovering, disabled) {
                return Text(
                  LocaleKeys.ai_customPrompt_custom.tr(),  // 显示国际化的"自定义"文本
                  style: AppFlowyTheme.of(context).textStyle.body.standard(
                        color: theme.textColorScheme.primary,
                      ),
                  overflow: TextOverflow.ellipsis,
                );
              },
              borderRadius: theme.borderRadius.m,
              padding: EdgeInsets.symmetric(
                vertical: theme.spacing.s,
                horizontal: theme.spacing.m,
              ),
              // 边框始终透明
              borderColor: (context, isHovering, disabled, isFocused) =>
                  Colors.transparent,
              // 动态背景色管理
              backgroundColor: (context, isHovering, disabled) {
                if (isSelected) {
                  return theme.fillColorScheme.themeSelect;  // 选中状态
                }
                if (isHovering) {
                  return theme.fillColorScheme.contentHover;  // 悬停状态
                }
                return Colors.transparent;  // 默认透明
              },
            );
          },
          // 非ready状态时返回空组件
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// 单个分类项组件
/// 
/// 功能：显示提示词分类列表中的单个分类项
/// 
/// 参数说明：
/// - [category]: 分类枚举值，null表示"全部"分类
/// - [onSelect]: 点击回调函数
/// 
/// 设计思路：
/// - 使用BlocBuilder监听选中状态
/// - 通过比较当前category与状态中的selectedCategory判断是否选中
/// - 只有在非精选、非自定义区域选中时，分类项才可能被选中
class AiPromptCategoryItem extends StatelessWidget {
  const AiPromptCategoryItem({
    super.key,
    required this.category,
    required this.onSelect,
  });

  // 分类枚举，null表示"全部"分类
  final AiPromptCategory? category;
  // 选中回调
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiPromptSelectorCubit, AiPromptSelectorState>(
      builder: (context, state) {
        final theme = AppFlowyTheme.of(context);
        // 判断当前分类项是否被选中
        // 选中条件：
        // 1. 精选区域未选中
        // 2. 自定义区域未选中
        // 3. 当前分类与状态中的选中分类一致
        final isSelected = state.maybeMap(
          ready: (state) {
            return !state.isFeaturedSectionSelected &&      // 精选未选中
                !state.isCustomPromptSectionSelected &&     // 自定义未选中
                state.selectedCategory == category;         // 分类匹配
          },
          orElse: () => false,
        );

        return AFBaseButton(
          onTap: onSelect,
          builder: (context, isHovering, disabled) {
            return Text(
              // category为null时显示"全部"，否则显示分类的国际化名称
              category?.i18n ?? LocaleKeys.ai_customPrompt_all.tr(),
              style: AppFlowyTheme.of(context).textStyle.body.standard(
                    color: theme.textColorScheme.primary,
                  ),
              overflow: TextOverflow.ellipsis,
            );
          },
          borderRadius: theme.borderRadius.m,
          padding: EdgeInsets.symmetric(
            vertical: theme.spacing.s,
            horizontal: theme.spacing.m,
          ),
          // 边框始终透明
          borderColor: (context, isHovering, disabled, isFocused) =>
              Colors.transparent,
          // 动态背景色：选中、悬停、默认三种状态
          backgroundColor: (context, isHovering, disabled) {
            if (isSelected) {
              return theme.fillColorScheme.themeSelect;     // 选中高亮
            }
            if (isHovering) {
              return theme.fillColorScheme.contentHover;    // 悬停效果
            }
            return Colors.transparent;                      // 默认透明
          },
        );
      },
    );
  }
}
