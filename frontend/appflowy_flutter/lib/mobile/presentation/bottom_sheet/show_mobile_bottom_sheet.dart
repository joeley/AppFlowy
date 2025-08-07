import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_buttons.dart';
import 'package:appflowy/plugins/base/drag_handler.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/*
 * 移动端底部弹窗组件
 * 
 * 提供统一的底部弹窗样式和行为
 * 支持多种配置选项，适应不同的使用场景
 * 
 * 设计思想：
 * 1. **组合模式**：通过参数组合不同的UI元素
 * 2. **响应式设计**：自动适配键盘和安全区域
 * 3. **Material Design**：遵循Material设计规范
 */

/*
 * BuildContext扩展 - 底部间距计算
 * 
 * 计算底部弹窗需要的底部间距
 * 考虑键盘高度、安全区域等因素
 */
extension BottomSheetPaddingExtension on BuildContext {
  /*
   * 计算底部弹窗的底部间距
   * 
   * @param ignoreViewPadding 是否忽略视图内边距
   * @return 计算后的底部间距值
   */
  double bottomSheetPadding({
    bool ignoreViewPadding = true,
  }) {
    /* 获取视图内边距（如刘海屏、圆角等） */
    final viewPadding = MediaQuery.viewPaddingOf(this);
    /* 获取视图插入区域（主要是键盘高度） */
    final viewInsets = MediaQuery.viewInsetsOf(this);
    double bottom = 0.0;
    
    /* 根据参数决定是否包含视图内边距 */
    if (!ignoreViewPadding) {
      bottom += viewPadding.bottom;
    }
    
    /* 为没有底部安全区的设备添加额外间距
     * 确保内容不会太贴近屏幕底部 */
    bottom += viewPadding.bottom == 0 ? 28.0 : 16.0;
    
    /* 添加键盘高度 */
    bottom += viewInsets.bottom;
    return bottom;
  }
}

/*
 * 显示移动端底部弹窗
 * 
 * 统一的底部弹窗入口函数，提供丰富的配置选项
 * 支持拖动、滚动、自定义头部等功能
 * 
 * @param context 上下文
 * @param builder 内容构建器
 * @param useSafeArea 是否使用安全区域
 * @param isDragEnabled 是否可拖动关闭
 * @param showDragHandle 是否显示拖动手柄
 * @param showHeader 是否显示头部
 * @param showBackButton 是否显示返回按钮（仅在showHeader为true时有效）
 * @param showCloseButton 是否显示关闭按钮
 * @param showRemoveButton 是否显示删除按钮
 * @param onRemove 删除回调
 * @param title 标题文本（仅在showHeader为true时有效）
 * @param isScrollControlled 是否控制滚动高度
 * @param showDivider 是否显示分割线
 * @param useRootNavigator 是否使用根导航器
 * @param shape 弹窗形状
 * @param padding 内容内边距（头部区域内边距固定）
 * @param backgroundColor 背景颜色
 * @param constraints 约束条件
 * @param barrierColor 遮罩颜色
 * @param elevation 阴影高度
 * @param showDoneButton 是否显示完成按钮
 * @param onDone 完成回调
 * @param enableDraggableScrollable 是否启用可拖动滚动
 * @param enableScrollable 是否启用滚动
 * @param scrollableWidgetBuilder 自定义滚动组件构建器
 * @param minChildSize 最小子组件大小（仅在enableDraggableScrollable为true时使用）
 * @param maxChildSize 最大子组件大小
 * @param initialChildSize 初始子组件大小
 * @param bottomSheetPadding 底部额外间距
 * @param enablePadding 是否启用内边距
 * @param dragHandleBuilder 自定义拖动手柄构建器
 */
Future<T?> showMobileBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useSafeArea = true,
  bool isDragEnabled = true,
  bool showDragHandle = false,
  bool showHeader = false,
  bool showBackButton = false,
  bool showCloseButton = false,
  bool showRemoveButton = false,
  VoidCallback? onRemove,
  String title = '',
  bool isScrollControlled = true,
  bool showDivider = true,
  bool useRootNavigator = false,
  ShapeBorder? shape,
  EdgeInsets padding = EdgeInsets.zero,
  Color? backgroundColor,
  BoxConstraints? constraints,
  Color? barrierColor,
  double? elevation,
  bool showDoneButton = false,
  void Function(BuildContext context)? onDone,
  bool enableDraggableScrollable = false,
  bool enableScrollable = false,
  Widget Function(BuildContext, ScrollController)? scrollableWidgetBuilder,
  double minChildSize = 0.5,
  double maxChildSize = 0.8,
  double initialChildSize = 0.51,
  double bottomSheetPadding = 0,
  bool enablePadding = true,
  WidgetBuilder? dragHandleBuilder,
}) async {
  /* 参数合法性检查
   * 确保头部相关参数的逻辑一致性 */
  assert(
    showHeader ||
        title.isEmpty && !showCloseButton && !showBackButton && !showDoneButton,
  );
  /* 返回和关闭按钮不能同时显示 */
  assert(!(showCloseButton && showBackButton));

  /* 设置默认圆角形状 */
  shape ??= const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(16),
    ),
  );

  /* 根据主题设置默认背景色 */
  backgroundColor ??= Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFF7F8FB)  /* 浅色主题背景 */
      : const Color(0xFF23262B);  /* 深色主题背景 */
  
  /* 半透明黑色遮罩 */
  barrierColor ??= Colors.black.withValues(alpha: 0.3);

  /* 调用Flutter原生的底部弹窗
   * 在此基础上进行自定义封装 */
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,  /* 控制高度是否可变 */
    enableDrag: isDragEnabled,               /* 是否可拖动关闭 */
    useSafeArea: true,                      /* 使用安全区域 */
    clipBehavior: Clip.antiAlias,           /* 抗锯齿裁剪 */
    constraints: constraints,
    barrierColor: barrierColor,
    elevation: elevation,
    backgroundColor: backgroundColor,
    shape: shape,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      final List<Widget> children = [];

      /* 构建主要内容 */
      final Widget child = builder(context);

      /* 优化：如果没有额外元素，直接返回内容
       * 避免不必要的Column包装 */
      if (!showDragHandle && !showHeader && !showDivider) {
        return child;
      }

      /* ===== 头部区域构建 ===== */
      
      /* 添加拖动手柄 */
      if (showDragHandle) {
        children.add(
          dragHandleBuilder?.call(context) ?? const DragHandle(),
        );
      }

      /* 添加标题栏 */
      if (showHeader) {
        children.add(
          BottomSheetHeader(
            showCloseButton: showCloseButton,
            showBackButton: showBackButton,
            showDoneButton: showDoneButton,
            showRemoveButton: showRemoveButton,
            title: title,
            onRemove: onRemove,
            onDone: onDone,
          ),
        );

        /* 添加分割线 */
        if (showDivider) {
          children.add(
            const Divider(height: 0.5, thickness: 0.5),
          );
        }
      }
      /* ===== 头部区域结束 ===== */

      /* 可拖动滚动模式
       * 适用于内容较多，需要用户可以调整高度的场景 */
      if (enableDraggableScrollable) {
        /* 计算键盘占屏幕的比例 */
        final keyboardSize =
            context.bottomSheetPadding() / MediaQuery.of(context).size.height;
        
        return DraggableScrollableSheet(
          expand: false,           /* 不自动扩展到最大 */
          snap: true,             /* 启用吸附效果 */
          /* 根据键盘高度调整各个尺寸参数 */
          initialChildSize: (initialChildSize + keyboardSize).clamp(0, 1),
          minChildSize: (minChildSize + keyboardSize).clamp(0, 1.0),
          maxChildSize: (maxChildSize + keyboardSize).clamp(0, 1.0),
          builder: (context, scrollController) {
            return Column(
              children: [
                ...children,
                scrollableWidgetBuilder?.call(
                      context,
                      scrollController,
                    ) ??
                    Expanded(
                      child: Scrollbar(
                        controller: scrollController,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: child,
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      } else if (enableScrollable) {
        /* 简单滚动模式
         * 内容固定高度，可以滚动查看 */
        return Column(
          mainAxisSize: MainAxisSize.min,  /* 最小化高度 */
          children: [
            ...children,
            Flexible(
              child: SingleChildScrollView(
                child: child,
              ),
            ),
            VSpace(bottomSheetPadding),  /* 底部间距 */
          ],
        );
      }

      /* ===== 内容区域构建 ===== */
      if (enablePadding) {
        /* 添加内容内边距和额外的底部间距
         * 底部间距会根据键盘高度自动调整 */
        children.add(
          Padding(
            padding:
                padding + EdgeInsets.only(bottom: context.bottomSheetPadding()),
            child: child,
          ),
        );
      } else {
        /* 不添加内边距，直接使用内容 */
        children.add(child);
      }
      /* ===== 内容区域结束 ===== */

      /* 优化：如果只有一个子组件，直接返回 */
      if (children.length == 1) {
        return children.first;
      }

      /* 组合所有子组件
       * 根据useSafeArea参数决定是否包装SafeArea */
      return useSafeArea
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            );
    },
  );
}

/*
 * 底部弹窗头部组件
 * 
 * 提供统一的头部样式，包含标题和操作按钮
 * 支持返回、关闭、删除、完成等操作
 */
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    super.key,
    required this.showBackButton,
    required this.showCloseButton,
    required this.showRemoveButton,
    required this.title,
    required this.showDoneButton,
    this.onRemove,
    this.onDone,
    this.onBack,
    this.onClose,
  });

  final String title;  /* 标题文本 */

  /* 按钮显示控制 */
  final bool showBackButton;   /* 返回按钮 */
  final bool showCloseButton;  /* 关闭按钮 */
  final bool showRemoveButton; /* 删除按钮 */
  final bool showDoneButton;   /* 完成按钮 */

  /* 按钮回调函数 */
  final VoidCallback? onRemove;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final void Function(BuildContext context)? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: SizedBox(
        height: 44.0,  /* 固定头部高度，保持一致性 */
        child: Stack(
          /* 使用Stack布局，方便定位各个按钮 */
          children: [
            /* 左侧按钮区域 */
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: BottomSheetBackButton(
                  onTap: onBack,
                ),
              ),
            if (showCloseButton)
              Align(
                alignment: Alignment.centerLeft,
                child: BottomSheetCloseButton(
                  onTap: onClose,
                ),
              ),
            if (showRemoveButton)
              Align(
                alignment: Alignment.centerLeft,
                child: BottomSheetRemoveButton(
                  onRemove: () => onRemove?.call(),
                ),
              ),
            /* 中间标题区域 */
            Align(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 250),  /* 限制标题最大宽度 */
                child: Text(
                  title,
                  style: theme.textStyle.heading4.prominent(
                    color: theme.textColorScheme.primary,
                  ),
                ),
              ),
            ),
            /* 右侧完成按钮 */
            if (showDoneButton)
              Align(
                alignment: Alignment.centerRight,
                child: BottomSheetDoneButton(
                  onDone: () {
                    /* 如果有自定义回调则执行，否则直接关闭弹窗 */
                    if (onDone != null) {
                      onDone?.call(context);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
