// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入应用全局上下文
import 'package:appflowy/startup/tasks/app_widget.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入iOS风格的UI组件
import 'package:flutter/cupertino.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

// 确认对话框按钮对齐方式枚举
// 定义了两种按钮布局方式，适应不同的设计需求
enum ConfirmDialogActionAlignment {
  // 按钮垂直排列（上下布局）
  // ---------------------
  // |　确认按钮　　　|
  // |　取消按钮　　　|
  vertical,
  // 按钮水平排列（左右布局）
  // ---------------------
  // |确认按钮 | 取消按钮|
  horizontal,
}

/**
 * 显示AppFlowy移动端确认对话框
 * 
 * 设计思想：
 * 1. 统一的确认对话框组件，用于处理用户确认操作
 * 2. 支持两种按钮布局方式，适应不同的内容长度
 * 3. 高度可定制化，支持自定义标题、内容和按钮样式
 * 4. 自动关闭对话框，简化使用方式
 * 
 * 使用场景：
 * - 删除确认
 * - 保存确认
 * - 退出确认
 * - 其他需要用户二次确认的操作
 * 
 * @param onActionButtonPressed 确认按钮点击回调，执行后自动关闭对话框
 * @param onCancelButtonPressed 取消按钮点击回调，执行后自动关闭对话框
 * @return Future<T?> 对话框的返回结果
 */
Future<T?> showFlowyMobileConfirmDialog<T>(
  BuildContext context, {
  Widget? title,                            // 可选的对话框标题组件
  Widget? content,                          // 可选的对话框内容组件
  ConfirmDialogActionAlignment actionAlignment =
      ConfirmDialogActionAlignment.horizontal, // 按钮布局方式，默认水平排列
  required String actionButtonTitle,        // 必需的确认按钮标题
  required VoidCallback? onActionButtonPressed, // 必需的确认按钮点击回调
  Color? actionButtonColor,                 // 可选的确认按钮颜色
  String? cancelButtonTitle,                // 可选的取消按钮标题，默认使用国际化文本
  Color? cancelButtonColor,                 // 可选的取消按钮颜色
  VoidCallback? onCancelButtonPressed,     // 可选的取消按钮点击回调
}) async {
  return showDialog(
    context: context,
    builder: (dialogContext) {
      // 获取当前主题的前景色，用于按钮文本颜色
      final foregroundColor = Theme.of(context).colorScheme.onSurface;
      // 构建确认按钮
      final actionButton = TextButton(
        child: FlowyText(
          actionButtonTitle,
          color: actionButtonColor ?? foregroundColor,
        ),
        onPressed: () {
          // 执行用户提供的回调函数
          onActionButtonPressed?.call();
          // 注意：这里不能使用dialogContext.pop()，因为对话框上下文中没有GoRouter
          // 使用Navigator来关闭对话框
          Navigator.of(dialogContext).pop();
        },
      );
      // 构建取消按钮
      final cancelButton = TextButton(
        child: FlowyText(
          // 如果没有指定取消按钮文本，使用默认的国际化文本
          cancelButtonTitle ?? LocaleKeys.button_cancel.tr(),
          color: cancelButtonColor ?? foregroundColor,
        ),
        onPressed: () {
          // 执行用户提供的回调函数（如果有）
          onCancelButtonPressed?.call();
          // 关闭对话框
          Navigator.of(dialogContext).pop();
        },
      );

      // 根据对齐方式构建按钮布局
      final actions = switch (actionAlignment) {
        // 水平排列：按钮并排显示
        ConfirmDialogActionAlignment.horizontal => [
            actionButton,
            cancelButton,
          ],
        // 垂直排列：按钮上下堆叠，中间有分割线
        ConfirmDialogActionAlignment.vertical => [
            Column(
              children: [
                actionButton,
                const Divider(height: 1, color: Colors.grey), // 按钮之间的分割线
                cancelButton,
              ],
            ),
          ],
      };

      // 返回自适应的警告对话框
      return AlertDialog.adaptive(
        title: title,
        content: content,
        // 设置内容区域的内边距
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 4.0,
        ),
        actionsAlignment: MainAxisAlignment.center, // 按钮区域居中对齐
        actions: actions,
      );
    },
  );
}

/**
 * 显示iOS风格的确认对话框
 * 
 * 设计思想：
 * 1. 提供与系统对话框类似的视觉效果
 * 2. 使用CupertinoAlertDialog实现，保持iOS原生体验
 * 3. 完全可定制化的按钮内容和操作
 * 4. 支持全局上下文，方便在任意位置调用
 * 
 * 使用场景：
 * - 需要iOS风格的确认对话框
 * - 需要完全自定义按钮内容的情况
 * - 在没有BuildContext的地方调用
 */
Future<T?> showFlowyCupertinoConfirmDialog<T>({
  BuildContext? context,                       // 可选的上下文，不提供则使用全局上下文
  required String title,                       // 必需的对话框标题
  Widget? content,                             // 可选的对话框内容组件
  required Widget leftButton,                  // 必需的左侧按钮组件
  required Widget rightButton,                 // 必需的右侧按钮组件
  void Function(BuildContext context)? onLeftButtonPressed,  // 左侧按钮点击回调
  void Function(BuildContext context)? onRightButtonPressed, // 右侧按钮点击回调
}) {
  return showDialog(
    // 使用提供的上下文或全局上下文
    context: context ?? AppGlobals.context,
    // 设置背景遮罩颜色，低透明度的黑色
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (context) => CupertinoAlertDialog(
      // 使用FlowyText组件显示标题，保持一致的文本风格
      title: FlowyText.medium(
        title,
        fontSize: 16,        // 标准的标题字体大小
        maxLines: 10,        // 支持多行标题
        figmaLineHeight: 22.0, // 按照设计规范设置行高
      ),
      content: content,
      actions: [
        // 左侧按钮动作
        CupertinoDialogAction(
          onPressed: () {
            // 如果提供了自定义回调函数，执行它；否则直接关闭对话框
            if (onLeftButtonPressed != null) {
              onLeftButtonPressed(context);
            } else {
              Navigator.of(context).pop();
            }
          },
          child: leftButton,
        ),
        // 右侧按钮动作
        CupertinoDialogAction(
          onPressed: () {
            // 如果提供了自定义回调函数，执行它；否则直接关闭对话框
            if (onRightButtonPressed != null) {
              onRightButtonPressed(context);
            } else {
              Navigator.of(context).pop();
            }
          },
          child: rightButton,
        ),
      ],
    ),
  );
}
