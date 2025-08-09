// 自动生成的国际化键值定义文件
import 'package:appflowy/generated/locale_keys.g.dart';
// 国际化支持库，提供多语言支持
import 'package:easy_localization/easy_localization.dart';
// AppFlowy自定义UI组件库，提供统一的视觉风格
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 移动端底部弹出框重命名组件
/// 
/// 设计思想：
/// 1. 提供简洁直观的重命名界面，包含输入框和确认按钮
/// 2. 使用StatefulWidget管理文本输入状态，提供实时交互反馈
/// 3. 支持回车键快速确认，优化用户体验
/// 4. 默认全选原名称，方便用户快速替换
/// 
/// 使用场景：
/// - 视图重命名
/// - 文件夹重命名
/// - 数据库表格重命名
/// - 任何需要在底部弹出框中进行重命名操作的场景
class MobileBottomSheetRenameWidget extends StatefulWidget {
  const MobileBottomSheetRenameWidget({
    super.key,
    required this.name,
    required this.onRename,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
  });

  /// 当前的名称，作为输入框的初始值
  final String name;
  /// 重命名回调函数，在用户确认重命名时调用
  final void Function(String name) onRename;
  /// 组件内边距，允许外部自定义布局间距
  final EdgeInsets padding;

  @override
  State<MobileBottomSheetRenameWidget> createState() =>
      _MobileBottomSheetRenameWidgetState();
}

/// 移动端底部弹出框重命名组件的状态管理类
/// 
/// 负责管理文本输入控制器的生命周期和初始化状态
class _MobileBottomSheetRenameWidgetState
    extends State<MobileBottomSheetRenameWidget> {
  /// 文本输入控制器，管理输入框的文本内容和光标位置
  late final TextEditingController controller;

  /// 组件初始化方法
  /// 
  /// 主要作用：
  /// 1. 初始化文本控制器，设置初始文本为当前名称
  /// 2. 设置文本全选状态，方便用户快速替换名称
  @override
  void initState() {
    super.initState();
    // 创建文本控制器并设置初始文本
    controller = TextEditingController(text: widget.name)
      // 设置文本全选状态，这是UX上的最佳实践
      // 用户打开重命名界面时，通常期望能快速更改整个名称
      ..selection = TextSelection(
        baseOffset: 0,                    // 开始位置
        extentOffset: widget.name.length, // 结束位置（全选）
      );
  }

  /// 组件销毁方法
  /// 
  /// 释放文本控制器资源，防止内存泄漏
  @override
  void dispose() {
    // 释放文本控制器资源
    controller.dispose();
    super.dispose();
  }

  /// 构建重命名组件的UI
  /// 
  /// 设计结构：
  /// - 左侧：可伸缩的文本输入框
  /// - 右侧：固定大小的确认按钮
  /// - 整体使用Row布局，适合移动端横屏操作
  @override
  Widget build(BuildContext context) {
    return Padding(
      // 使用外部传入的padding，提供布局灵活性
      padding: widget.padding,
      child: Row(
        // 使用最小空间，避免不必要的空白
        mainAxisSize: MainAxisSize.min,
        children: [
          // 使用Expanded让输入框占据剩余空间
          Expanded(
            child: SizedBox(
              // 固定高度，与按钮高度保持一致
              height: 42.0,
              child: FlowyTextField(
                controller: controller,
                // 使用主题的正文样式，保持视觉一致性
                textStyle: Theme.of(context).textTheme.bodyMedium,
                // 设置为文本输入类型，适合名称输入
                keyboardType: TextInputType.text,
                // 支持回车键快速确认，提升用户体验
                onSubmitted: (text) => widget.onRename(text),
              ),
            ),
          ),
          // 水平间距，分隔输入框和按钮
          const HSpace(12.0),
          // 确认按钮，使用AppFlowy的自定义按钮组件
          FlowyTextButton(
            // 使用国际化文本，支持多语言
            LocaleKeys.button_edit.tr(),
            // 严格控制按钮尺寸，保持UI一致性
            constraints: const BoxConstraints.tightFor(height: 42),
            // 按钮内边距，确保按钮文本不会贴边
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ),
            // 白色文本，与背景色形成对比
            fontColor: Colors.white,
            // 使用主题主色作为按钮背景，符合设计规范
            fillColor: Theme.of(context).primaryColor,
            onPressed: () {
              // 点击确认按钮时，调用重命名回调函数
              widget.onRename(controller.text);
            },
          ),
        ],
      ),
    );
  }
}
