// 导入AppFlowy生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入移动端通用组件
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入iOS风格的UI组件
import 'package:flutter/cupertino.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

// 选项瓦片类型枚举
// 定义了四种不同的交互类型，满足不同的用户交互需求
enum FlowyOptionTileType {
  text,      // 纯文本显示类型，通常用于展示信息或导航
  textField, // 文本输入框类型，用于用户输入文本
  checkbox,  // 复选框类型，用于单一选择确认
  toggle,    // 开关切换类型，用于布尔状态切换
}

/**
 * AppFlowy通用选项瓦片组件
 * 
 * 设计思想：
 * 1. 统一的选项列表项组件，支持多种交互类型
 * 2. 采用工厂构造函数模式，简化不同类型的创建过程
 * 3. 高度可定制化，支持图标、文本、输入框、开关等多种元素
 * 4. 遵循移动端设计规范，提供一致的用户体验
 * 
 * 功能特点：
 * - 支持四种类型：文本、输入框、复选框、开关
 * - 可自定义边框、颜色、字体等视觉样式
 * - 支持禁用状态，提供视觉反馈
 * - 左侧图标和右侧操作区域完全可定制
 * - 响应式布局，适配不同屏幕尺寸
 */
class FlowyOptionTile extends StatelessWidget {
  // 私有构造函数，防止直接实例化
  // 强制使用工厂构造函数来创建不同类型的瓦片，确保类型安全
  const FlowyOptionTile._({
    super.key,
    required this.type,
    this.showTopBorder = true,
    this.showBottomBorder = true,
    this.text,
    this.textColor,
    this.controller,
    this.leading,
    this.onTap,
    this.trailing,
    this.textFieldPadding = const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 2.0,
    ),
    this.isSelected = false,
    this.onValueChanged,
    this.textFieldHintText,
    this.onTextChanged,
    this.onTextSubmitted,
    this.autofocus,
    this.content,
    this.backgroundColor,
    this.fontFamily,
    this.height,
    this.enable = true,
  });

  // 文本类型瓦片工厂构造函数
  // 用于创建纯文本显示的选项，通常用于导航或信息展示
  factory FlowyOptionTile.text({
    String? text,
    Widget? content,
    Color? textColor,
    bool showTopBorder = true,
    bool showBottomBorder = true,
    Widget? leftIcon,
    Widget? trailing,
    VoidCallback? onTap,
    double? height,
    bool enable = true,
  }) {
    return FlowyOptionTile._(
      type: FlowyOptionTileType.text,
      text: text,
      content: content,
      textColor: textColor,
      onTap: onTap,
      showTopBorder: showTopBorder,
      showBottomBorder: showBottomBorder,
      leading: leftIcon,
      trailing: trailing,
      height: height,
      enable: enable,
    );
  }

  // 文本输入框类型瓦片工厂构造函数
  // 用于创建包含文本输入框的选项，支持用户输入与编辑
  factory FlowyOptionTile.textField({
    required TextEditingController controller,
    void Function(String value)? onTextChanged,
    void Function(String value)? onTextSubmitted,
    EdgeInsets textFieldPadding = const EdgeInsets.symmetric(
      vertical: 16.0,
    ),
    bool showTopBorder = true,
    bool showBottomBorder = true,
    Widget? leftIcon,
    Widget? trailing,
    String? textFieldHintText,
    bool autofocus = false,
    bool enable = true,
  }) {
    return FlowyOptionTile._(
      type: FlowyOptionTileType.textField,
      controller: controller,
      textFieldPadding: textFieldPadding,
      showTopBorder: showTopBorder,
      showBottomBorder: showBottomBorder,
      leading: leftIcon,
      trailing: trailing,
      textFieldHintText: textFieldHintText,
      onTextChanged: onTextChanged,
      onTextSubmitted: onTextSubmitted,
      autofocus: autofocus,
      enable: enable,
    );
  }

  // 复选框类型瓦片工厂构造函数
  // 用于创建包含复选框的选项，支持选中/未选中状态切换
  factory FlowyOptionTile.checkbox({
    Key? key,
    required String text,
    required bool isSelected,
    required VoidCallback? onTap,
    Color? textColor,
    Widget? leftIcon,
    Widget? content,
    bool showTopBorder = true,
    bool showBottomBorder = true,
    String? fontFamily,
    Color? backgroundColor,
    bool enable = true,
  }) {
    return FlowyOptionTile._(
      key: key,
      type: FlowyOptionTileType.checkbox,
      isSelected: isSelected,
      text: text,
      textColor: textColor,
      content: content,
      onTap: onTap,
      fontFamily: fontFamily,
      backgroundColor: backgroundColor,
      showTopBorder: showTopBorder,
      showBottomBorder: showBottomBorder,
      leading: leftIcon,
      enable: enable,
      trailing: isSelected
          ? const FlowySvg(
              FlowySvgs.m_blue_check_s,
              blendMode: null,
            )
          : null,
    );
  }

  // 开关类型瓦片工厂构造函数
  // 用于创建包含iOS风格开关的选项，适用于布尔状态设置
  factory FlowyOptionTile.toggle({
    required String text,
    required bool isSelected,
    required void Function(bool value) onValueChanged,
    void Function()? onTap,
    bool showTopBorder = true,
    bool showBottomBorder = true,
    Widget? leftIcon,
    bool enable = true,
  }) {
    return FlowyOptionTile._(
      type: FlowyOptionTileType.toggle,
      text: text,
      onTap: onTap ?? () => onValueChanged(!isSelected),
      onValueChanged: onValueChanged,
      showTopBorder: showTopBorder,
      showBottomBorder: showBottomBorder,
      leading: leftIcon,
      trailing: _Toggle(value: isSelected, onChanged: onValueChanged),
      enable: enable,
    );
  }

  final bool showTopBorder;                      // 是否显示顶部边框
  final bool showBottomBorder;                    // 是否显示底部边框
  final String? text;                             // 显示的文本内容
  final Color? textColor;                         // 文本颜色
  final TextEditingController? controller;       // 文本输入框控制器（仅textField类型使用）
  final EdgeInsets textFieldPadding;             // 文本输入框内边距
  final void Function()? onTap;                   // 点击事件处理函数
  final Widget? leading;                          // 左侧元素（通常是图标）
  final Widget? trailing;                         // 右侧元素（通常是操作按钮或指示器）

  // 自定义内容组件，可以完全替换默认的文本显示
  final Widget? content;

  // 选中状态，仅在checkbox和toggle类型中使用
  final bool isSelected;

  // 状态变更回调函数，仅在toggle类型中使用
  final void Function(bool value)? onValueChanged;

  // 以下字段仅在textField类型中使用
  final String? textFieldHintText;                // 输入框占位符文本
  final void Function(String value)? onTextChanged; // 文本变更回调函数
  final void Function(String value)? onTextSubmitted; // 文本提交回调函数
  final bool? autofocus;                          // 是否自动获取焦点

  final FlowyOptionTileType type;                 // 瓦片类型标识

  final Color? backgroundColor;                   // 背景颜色
  final String? fontFamily;                       // 字体家族

  final double? height;                           // 高度

  final bool enable;                              // 是否启用，禁用状态下会显示半透明和忽略交互

  @override
  Widget build(BuildContext context) {
    // 构建左侧元素
    final leadingWidget = _buildLeading();

    // 使用装饰器组件来统一处理边框和背景
    Widget child = FlowyOptionDecorateBox(
      color: backgroundColor,
      showTopBorder: showTopBorder,
      showBottomBorder: showBottomBorder,
      child: SizedBox(
        height: height,
        child: Padding(
          // 设置水平内边距，确保内容不贴边
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // 按顺序排列各个元素：左侧图标 -> 内容 -> 右侧操作
              if (leadingWidget != null) leadingWidget,
              // 如果有自定义内容，优先使用自定义内容
              if (content != null) content!,
              // 否则根据类型构建默认内容
              if (content == null) _buildText(),
              if (content == null) _buildTextField(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );

    // 为可交互类型添加点击手势识别
    // textField类型不需要整体点击，因为输入框有自己的交互逻辑
    if (type == FlowyOptionTileType.checkbox ||
        type == FlowyOptionTileType.toggle ||
        type == FlowyOptionTileType.text) {
      child = GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    // 禁用状态处理：降低透明度并忽略所有交互
    if (!enable) {
      child = Opacity(
        opacity: 0.5,          // 半透明显示
        child: IgnorePointer(   // 忽略所有指针事件（点击、滑动等）
          child: child,
        ),
      );
    }

    return child;
  }

  // 构建左侧元素，通常是图标
  Widget? _buildLeading() {
    if (leading != null) {
      // 将左侧元素居中显示
      return Center(child: leading);
    } else {
      return null;
    }
  }

  // 构建文本内容
  Widget _buildText() {
    // 如果没有文本或者是textField类型，则不显示文本
    if (text == null || type == FlowyOptionTileType.textField) {
      return const SizedBox.shrink();
    }

    // 根据是否有左侧元素调整水平边距
    final padding = EdgeInsets.symmetric(
      horizontal: leading == null ? 0.0 : 12.0, // 有左侧图标时增加间距
      vertical: 14.0,
    );

    // 使用Expanded让文本占据剩余空间
    return Expanded(
      child: Padding(
        padding: padding,
        child: FlowyText(
          text!,
          fontSize: 16,           // 标准字体大小
          color: textColor,       // 使用指定的或默认颜色
          fontFamily: fontFamily, // 使用指定的或默认字体
        ),
      ),
    );
  }

  // 构建文本输入框
  Widget _buildTextField() {
    // 如果没有控制器，则不显示输入框
    if (controller == null) {
      return const SizedBox.shrink();
    }

    // 使用Expanded让输入框占据剩余空间
    return Expanded(
      child: Container(
        // 限制输入框高度为54像素，提供足够的点击区域
        constraints: const BoxConstraints.tightFor(
          height: 54.0,
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          autofocus: autofocus ?? false,                // 是否自动获取焦点
          textInputAction: TextInputAction.done,        // 输入完成动作
          decoration: InputDecoration(
            // 去除所有边框，使输入框融入瓦片设计
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: textFieldPadding,           // 使用自定义内边距
            hintText: textFieldHintText,                // 显示占位符文本
          ),
          onChanged: onTextChanged,     // 文本变更回调
          onSubmitted: onTextSubmitted, // 文本提交回调
        ),
      ),
    );
  }
}

/**
 * 私有的iOS风格开关组件
 * 用于在FlowyOptionTile中显示开关控件
 * 采用CupertinoSwitch实现，提供iOS原生体验
 */
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,     // 开关状态
    required this.onChanged, // 状态变更回调
  });

  final bool value;
  final void Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    // CupertinoSwitch adds a 8px margin all around. The original size of the
    // switch is 38 x 22.
    return SizedBox(
      width: 46,
      height: 30,
      child: FittedBox(
        fit: BoxFit.fill,
        child: CupertinoSwitch(
          value: value,
          activeTrackColor: Theme.of(context).colorScheme.primary,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
