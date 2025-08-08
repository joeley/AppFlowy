import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';

/*
 * 弹出动作列表系统
 * 
 * 核心功能：
 * 1. 提供统一的弹出菜单UI组件
 * 2. 支持多种动作类型（普通动作、嵌套弹出、自定义）
 * 3. 管理弹出层的生命周期
 * 4. 提供悬停效果和交互反馈
 * 
 * 设计模式：
 * - 策略模式：不同类型的动作有不同的渲染策略
 * - 组合模式：支持嵌套的弹出菜单
 * - 控制器模式：使用PopoverController管理弹出状态
 */

/*
 * 弹出动作列表组件
 * 
 * 通用的弹出式菜单组件，支持多种动作类型
 * 
 * 主要特性：
 * 1. 泛型支持，可以处理不同类型的动作
 * 2. 内置动画效果（缩放、滑动、淡入淡出）
 * 3. 灵活的弹出方向控制
 * 4. 支持互斥锁（PopoverMutex）避免多个弹出层冲突
 */
class PopoverActionList<T extends PopoverAction> extends StatefulWidget {
  const PopoverActionList({
    super.key,
    this.controller,
    this.popoverMutex,
    required this.actions,
    required this.buildChild,
    required this.onSelected,
    this.mutex,
    this.onClosed,
    this.onPopupBuilder,
    this.direction = PopoverDirection.rightWithTopAligned,
    this.asBarrier = false,
    this.offset = Offset.zero,
    this.animationDuration = const Duration(),
    this.slideDistance = 20,
    this.beginScaleFactor = 0.9,
    this.endScaleFactor = 1.0,
    this.beginOpacity = 0.0,
    this.endOpacity = 1.0,
    this.constraints = const BoxConstraints(
      minWidth: 120,
      maxWidth: 460,
      maxHeight: 300,
    ),
    this.showAtCursor = false,
  });

  /* 弹出层控制器，用于程序控制弹出层的显示/隐藏 */
  final PopoverController? controller;
  /* 弹出层互斥锁，用于嵌套弹出层的管理 */
  final PopoverMutex? popoverMutex;
  /* 动作列表，定义菜单中的所有选项 */
  final List<T> actions;
  /* 触发器构建函数，返回点击后显示弹出层的Widget */
  final Widget Function(PopoverController) buildChild;
  /* 选中动作的回调函数 */
  final Function(T, PopoverController) onSelected;
  /* 互斥锁，确保同时只有一个弹出层显示 */
  final PopoverMutex? mutex;
  /* 弹出层关闭时的回调 */
  final VoidCallback? onClosed;
  /* 弹出层构建时的回调 */
  final VoidCallback? onPopupBuilder;
  /* 弹出方向 */
  final PopoverDirection direction;
  /* 是否作为遮罩层（点击外部关闭） */
  final bool asBarrier;
  /* 位置偏移 */
  final Offset offset;
  /* 尺寸约束 */
  final BoxConstraints constraints;
  /* 动画时长 */
  final Duration animationDuration;
  /* 滑动距离 */
  final double slideDistance;
  /* 起始缩放因子 */
  final double beginScaleFactor;
  /* 结束缩放因子 */
  final double endScaleFactor;
  /* 起始不透明度 */
  final double beginOpacity;
  /* 结束不透明度 */
  final double endOpacity;
  /* 是否在光标位置显示 */
  final bool showAtCursor;

  @override
  State<PopoverActionList<T>> createState() => _PopoverActionListState<T>();
}

class _PopoverActionListState<T extends PopoverAction>
    extends State<PopoverActionList<T>> {
  /* 弹出层控制器，优先使用外部传入的，否则创建新的 */
  late PopoverController popoverController =
      widget.controller ?? PopoverController();

  @override
  void dispose() {
    /* 如果是内部创建的控制器，需要关闭它 */
    if (widget.controller == null) {
      popoverController.close();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PopoverActionList<T> oldWidget) {
    /* 当外部控制器变化时，更新本地引用 */
    if (widget.controller != oldWidget.controller) {
      popoverController.close();
      popoverController = widget.controller ?? PopoverController();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.buildChild(popoverController);
    return AppFlowyPopover(
      asBarrier: widget.asBarrier,
      animationDuration: widget.animationDuration,
      slideDistance: widget.slideDistance,
      beginScaleFactor: widget.beginScaleFactor,
      endScaleFactor: widget.endScaleFactor,
      beginOpacity: widget.beginOpacity,
      endOpacity: widget.endOpacity,
      controller: popoverController,
      constraints: widget.constraints,
      direction: widget.direction,
      mutex: widget.mutex,
      offset: widget.offset,
      triggerActions: PopoverTriggerFlags.none,
      onClose: widget.onClosed,
      showAtCursor: widget.showAtCursor,
      popupBuilder: (_) {
        widget.onPopupBuilder?.call();
        /* 根据动作类型构建不同的Widget
         * ActionCell: 普通可点击的动作项
         * PopoverActionCell: 可嵌套弹出的动作项
         * CustomActionCell: 自定义渲染的动作项
         */
        final List<Widget> children = widget.actions.map((action) {
          if (action is ActionCell) {
            return ActionCellWidget<T>(
              action: action,
              itemHeight: ActionListSizes.itemHeight,
              onSelected: (action) {
                widget.onSelected(action, popoverController);
              },
            );
          } else if (action is PopoverActionCell) {
            return PopoverActionCellWidget<T>(
              popoverMutex: widget.popoverMutex,
              popoverController: popoverController,
              action: action,
              itemHeight: ActionListSizes.itemHeight,
            );
          } else {
            final custom = action as CustomActionCell;
            return custom.buildWithContext(
              context,
              popoverController,
              widget.popoverMutex,
            );
          }
        }).toList();

        return IntrinsicHeight(
          child: IntrinsicWidth(
            child: Column(children: children),
          ),
        );
      },
      child: child,
    );
  }
}

/*
 * 普通动作单元格抽象类
 * 
 * 定义可点击的菜单项
 * 支持左右图标和文字颜色自定义
 */
abstract class ActionCell extends PopoverAction {
  /* 左侧图标 */
  Widget? leftIcon(Color iconColor) => null;
  /* 右侧图标 */
  Widget? rightIcon(Color iconColor) => null;
  /* 显示名称 */
  String get name;
  /* 文字颜色（可选） */
  Color? textColor(BuildContext context) {
    return null;
  }
}

/* 嵌套弹出层构建器类型 */
typedef PopoverActionCellBuilder = Widget Function(
  BuildContext context,
  PopoverController parentController,  /* 父级弹出层控制器 */
  PopoverController controller,       /* 当前弹出层控制器 */
);

/*
 * 嵌套弹出动作单元格抽象类
 * 
 * 支持点击后显示另一个弹出层
 * 用于多级菜单或复杂交互
 */
abstract class PopoverActionCell extends PopoverAction {
  Widget? leftIcon(Color iconColor) => null;
  Widget? rightIcon(Color iconColor) => null;
  String get name;

  /* 嵌套弹出层的构建器 */
  PopoverActionCellBuilder get builder;
}

/*
 * 自定义动作单元格抽象类
 * 
 * 允许完全自定义菜单项的渲染
 * 用于特殊布局或复杂交互需求
 */
abstract class CustomActionCell extends PopoverAction {
  /* 构建自定义Widget */
  Widget buildWithContext(
    BuildContext context,
    PopoverController controller,
    PopoverMutex? mutex,
  );
}

/* 弹出动作基类，所有动作类型的根接口 */
abstract class PopoverAction {}

/*
 * 动作列表尺寸常量
 * 
 * 统一管理菜单项的尺寸和间距
 */
class ActionListSizes {
  static double itemHPadding = 10;  /* 项目水平内边距 */
  static double itemHeight = 20;     /* 项目高度 */
  static double vPadding = 6;        /* 垂直内边距 */
  static double hPadding = 10;       /* 水平内边距 */
}

/*
 * 普通动作单元格Widget
 * 
 * 渲染可点击的菜单项
 * 支持悬停效果和图标显示
 */
class ActionCellWidget<T extends PopoverAction> extends StatelessWidget {
  const ActionCellWidget({
    super.key,
    required this.action,
    required this.onSelected,
    required this.itemHeight,
  });

  final T action;
  final Function(T) onSelected;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final actionCell = action as ActionCell;
    final leftIcon =
        actionCell.leftIcon(Theme.of(context).colorScheme.onSurface);

    final rightIcon =
        actionCell.rightIcon(Theme.of(context).colorScheme.onSurface);

    return HoverButton(
      itemHeight: itemHeight,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      name: actionCell.name,
      textColor: actionCell.textColor(context),
      onTap: () => onSelected(action),
    );
  }
}

/*
 * 嵌套弹出动作单元格Widget
 * 
 * 点击后显示另一个弹出层
 * 用于实现二级菜单或更复杂的交互
 */
class PopoverActionCellWidget<T extends PopoverAction> extends StatefulWidget {
  const PopoverActionCellWidget({
    super.key,
    this.popoverMutex,
    required this.popoverController,
    required this.action,
    required this.itemHeight,
  });

  final PopoverMutex? popoverMutex;
  final T action;
  final double itemHeight;
  /* 父级弹出层的控制器 */
  final PopoverController popoverController;

  @override
  State<PopoverActionCellWidget> createState() =>
      _PopoverActionCellWidgetState();
}

class _PopoverActionCellWidgetState<T extends PopoverAction>
    extends State<PopoverActionCellWidget<T>> {
  final popoverController = PopoverController();
  @override
  Widget build(BuildContext context) {
    final actionCell = widget.action as PopoverActionCell;
    final leftIcon =
        actionCell.leftIcon(Theme.of(context).colorScheme.onSurface);
    final rightIcon =
        actionCell.rightIcon(Theme.of(context).colorScheme.onSurface);
    return AppFlowyPopover(
      mutex: widget.popoverMutex,
      controller: popoverController,
      asBarrier: true,
      popupBuilder: (context) => actionCell.builder(
        context,
        widget.popoverController,
        popoverController,
      ),
      child: HoverButton(
        itemHeight: widget.itemHeight,
        leftIcon: leftIcon,
        rightIcon: rightIcon,
        name: actionCell.name,
        onTap: () => popoverController.show(),
      ),
    );
  }
}

/*
 * 悬停按钮组件
 * 
 * 统一的菜单项样式
 * 提供悬停高亮效果
 * 
 * 布局结构：
 * [左图标] [间距] [文字] [间距] [右图标]
 */
class HoverButton extends StatelessWidget {
  const HoverButton({
    super.key,
    required this.onTap,
    required this.itemHeight,
    this.leftIcon,
    required this.name,
    this.rightIcon,
    this.textColor,
  });

  final VoidCallback onTap;
  final double itemHeight;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final String name;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return FlowyHover(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: itemHeight,
          child: Row(
            children: [
              if (leftIcon != null) ...[
                leftIcon!,
                HSpace(ActionListSizes.itemHPadding),
              ],
              Expanded(
                child: FlowyText.regular(
                  name,
                  overflow: TextOverflow.visible,
                  lineHeight: 1.15,
                  color: textColor,
                ),
              ),
              if (rightIcon != null) ...[
                HSpace(ActionListSizes.itemHPadding),
                rightIcon!,
              ],
            ],
          ),
        ).padding(
          horizontal: ActionListSizes.hPadding,
          vertical: ActionListSizes.vPadding,
        ),
      ),
    );
  }
}
