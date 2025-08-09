import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 底部弹窗关闭按钮组件
/// 
/// 这是一个通用的底部弹窗关闭按钮，提供统一的关闭交互体验。
/// 设计思想：
/// 1. 使用SVG图标保证在不同屏幕密度下的显示效果
/// 2. 支持自定义关闭回调，默认为关闭当前页面
/// 3. 统一的外观和交互行为，确保用户体验一致性
/// 
/// 使用场景：移动端底部弹窗的标准关闭按钮
class BottomSheetCloseButton extends StatelessWidget {
  const BottomSheetCloseButton({
    super.key,
    this.onTap,
  });

  /// 点击关闭按钮时的回调函数
  /// 如果为null，则默认执行Navigator.pop(context)关闭当前页面
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 使用自定义回调或默认的页面关闭逻辑
      onTap: onTap ?? () => Navigator.pop(context),
      child: const Padding(
        // 设置水平内边距，确保按钮有足够的触摸区域
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          // 固定按钮尺寸，保证视觉一致性
          width: 18,
          height: 18,
          child: FlowySvg(
            // 使用移动端专用的关闭图标
            FlowySvgs.m_bottom_sheet_close_m,
          ),
        ),
      ),
    );
  }
}

/// 底部弹窗完成按钮组件
/// 
/// 这是一个通用的底部弹窗完成按钮，用于确认操作或完成编辑。
/// 设计思想：
/// 1. 使用文本按钮而非图标，更好地传达"完成"的语义
/// 2. 支持国际化，适配不同语言环境
/// 3. 使用主题色高亮显示，引导用户完成操作
/// 4. 右对齐布局，符合移动端设计规范
/// 
/// 使用场景：底部弹窗中需要确认操作的场景
class BottomSheetDoneButton extends StatelessWidget {
  const BottomSheetDoneButton({
    super.key,
    this.onDone,
  });

  /// 点击完成按钮时的回调函数
  /// 如果为null，则默认执行Navigator.pop(context)关闭当前页面
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 使用自定义回调或默认的页面关闭逻辑
      onTap: onDone ?? () => Navigator.pop(context),
      child: Padding(
        // 设置内边距，确保按钮有足够的触摸区域
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
        child: FlowyText(
          // 使用国际化文本，支持多语言
          LocaleKeys.button_done.tr(),
          // 使用主题的主色调，突出按钮的重要性
          color: Theme.of(context).colorScheme.primary,
          // 中等字重，平衡可读性和视觉权重
          fontWeight: FontWeight.w500,
          // 右对齐，符合移动端布局习惯
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

/// 底部弹窗移除按钮组件
/// 
/// 专门用于执行移除/删除操作的按钮组件。
/// 设计思想：
/// 1. 明确的语义，专门用于删除类操作
/// 2. 视觉上与完成按钮保持一致，但语义不同
/// 3. 必须提供回调函数，确保删除操作的明确性
/// 4. 使用主题色保持视觉一致性
/// 
/// 使用场景：需要移除或删除某项内容的底部弹窗
class BottomSheetRemoveButton extends StatelessWidget {
  const BottomSheetRemoveButton({
    super.key,
    required this.onRemove,
  });

  /// 点击移除按钮时的回调函数
  /// 必须提供，确保移除操作有明确的处理逻辑
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 直接调用移除回调，不提供默认行为
      onTap: onRemove,
      child: Padding(
        // 与其他按钮保持一致的内边距
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
        child: FlowyText(
          // 使用国际化的"移除"文本
          LocaleKeys.button_remove.tr(),
          // 使用主题主色调，保持视觉一致性
          color: Theme.of(context).colorScheme.primary,
          // 中等字重，保持可读性
          fontWeight: FontWeight.w500,
          // 右对齐，符合移动端布局习惯
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

/// 底部弹窗返回按钮组件
/// 
/// 提供返回上一步操作的按钮，通常用于多步骤流程中。
/// 设计思想：
/// 1. 使用返回箭头图标，直观表达返回操作
/// 2. 与关闭按钮区分，关闭是退出，返回是回到上一步
/// 3. 支持自定义回调，默认为关闭当前页面
/// 4. 保持与关闭按钮相同的尺寸和布局
/// 
/// 使用场景：多步骤表单或向导式界面的返回操作
class BottomSheetBackButton extends StatelessWidget {
  const BottomSheetBackButton({
    super.key,
    this.onTap,
  });

  /// 点击返回按钮时的回调函数
  /// 如果为null，则默认执行Navigator.pop(context)关闭当前页面
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 使用自定义回调或默认的页面关闭逻辑
      onTap: onTap ?? () => Navigator.pop(context),
      child: const Padding(
        // 设置水平内边距，确保按钮有足够的触摸区域
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          // 与关闭按钮保持相同的尺寸，确保视觉一致性
          width: 18,
          height: 18,
          child: FlowySvg(
            // 使用移动端专用的返回图标
            FlowySvgs.m_bottom_sheet_back_s,
          ),
        ),
      ),
    );
  }
}
