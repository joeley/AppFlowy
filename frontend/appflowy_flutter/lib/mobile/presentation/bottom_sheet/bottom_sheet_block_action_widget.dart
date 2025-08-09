// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端通用组件
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * 块操作类型枚举
 * 
 * 定义编辑器中块级元素的可用操作
 * 这些操作是文档编辑的核心功能
 */
enum BlockActionBottomSheetType {
  delete,      // 删除当前块
  duplicate,   // 复制当前块
  insertAbove, // 在当前块上方插入新块
  insertBelow, // 在当前块下方插入新块
}

/**
 * 块操作底部弹窗组件
 * 
 * 设计思想：
 * 1. **上下文操作** - 针对选中的文档块提供快速操作菜单
 * 2. **触摸优化** - 专为移动端触摸操作设计的大按钮区域
 * 3. **功能完整** - 涵盖块编辑的基本操作：插入、复制、删除
 * 4. **视觉一致** - 使用统一的图标和颜色设计语言
 * 
 * 使用场景：
 * - 用户长按文档中的某个块（段落、标题、列表项等）
 * - 显示针对该块的操作菜单
 * - 提供快速编辑和重组文档结构的能力
 * 
 * 架构说明：
 * - 仅在移动端使用，桌面端有不同的交互方式
 * - 每个操作都会回调到父组件处理具体的编辑逻辑
 * - 支持扩展自定义操作按钮
 */
// 仅在移动端使用的组件
class BlockActionBottomSheet extends StatelessWidget {
  const BlockActionBottomSheet({
    super.key,
    required this.onAction,                   // 操作类型回调函数
    this.extendActionWidgets = const [],      // 扩展的自定义操作组件列表
  });

  /// 操作类型回调函数
  /// 当用户选择某个操作时，会调用此函数并传入对应的操作类型
  final void Function(BlockActionBottomSheetType layout) onAction;
  
  /// 扩展操作组件列表
  /// 允许在标准操作之外添加自定义的操作按钮
  /// 这些组件会插入到"复制"和"删除"操作之间
  final List<Widget> extendActionWidgets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ===== 插入操作区域 =====
        // 这些操作用于在当前块的上方或下方插入新的空白块
        
        // 在上方插入新块
        FlowyOptionTile.text(
          text: LocaleKeys.button_insertAbove.tr(),
          leftIcon: const FlowySvg(
            FlowySvgs.arrow_up_s,          // 向上箭头图标，直观表示"上方"
            size: Size.square(20),
          ),
          showTopBorder: false,              // 第一个选项不显示顶部边框
          onTap: () => onAction(BlockActionBottomSheetType.insertAbove),
        ),
        
        // 在下方插入新块
        FlowyOptionTile.text(
          showTopBorder: false,              // 不显示顶部边框，与上一个选项连接
          text: LocaleKeys.button_insertBelow.tr(),
          leftIcon: const FlowySvg(
            FlowySvgs.arrow_down_s,        // 向下箭头图标，直观表示"下方"
            size: Size.square(20),
          ),
          onTap: () => onAction(BlockActionBottomSheetType.insertBelow),
        ),
        
        // ===== 复制操作区域 =====
        // 复制当前块的内容和格式，在下方创建一个相同的块
        FlowyOptionTile.text(
          showTopBorder: false,
          text: LocaleKeys.button_duplicate.tr(),
          leftIcon: const Padding(
            padding: EdgeInsets.all(2),     // 给复制图标添加内边距，视觉平衡
            child: FlowySvg(
              FlowySvgs.copy_s,            // 复制图标
              size: Size.square(16),       // 稍小的图标尺寸
            ),
          ),
          onTap: () => onAction(BlockActionBottomSheetType.duplicate),
        ),

        // ===== 扩展操作区域 =====
        // 插入自定义的扩展操作组件
        // 这些组件由父组件提供，用于特定场景的额外功能
        ...extendActionWidgets,

        // ===== 删除操作区域 =====
        // 删除当前块，这是一个危险操作，使用错误颜色突出显示
        FlowyOptionTile.text(
          showTopBorder: false,
          text: LocaleKeys.button_delete.tr(),
          leftIcon: FlowySvg(
            FlowySvgs.trash_s,
            size: const Size.square(18),
            color: Theme.of(context).colorScheme.error, // 使用主题的错误颜色
          ),
          textColor: Theme.of(context).colorScheme.error,   // 文本也使用错误颜色
          onTap: () => onAction(BlockActionBottomSheetType.delete),
        ),
      ],
    );
  }
}
