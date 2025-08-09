// 移动端应用栏组件
// 提供统一的移动端导航栏样式和交互行为，包含不同类型的前导按钮和自定义样式
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar_actions.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 移动端应用栏前导按钮类型枚举
/// 定义了不同场景下应用栏左侧按钮的类型和样式
enum FlowyAppBarLeadingType {
  /// 返回按钮 - 用于页面导航返回上一级
  back,
  /// 关闭按钮 - 用于弹窗或模态页面的关闭
  close,
  /// 取消按钮 - 用于取消操作，通常带有文字
  cancel;

  /// 根据类型获取对应的Widget组件
  /// [onTap] 点击回调函数
  Widget getWidget(VoidCallback? onTap) {
    switch (this) {
      case FlowyAppBarLeadingType.back:
        // 沉浸式返回按钮，适配移动端的导航体验
        return AppBarImmersiveBackButton(onTap: onTap);
      case FlowyAppBarLeadingType.close:
        // 关闭按钮，通常用于模态页面
        return AppBarCloseButton(onTap: onTap);
      case FlowyAppBarLeadingType.cancel:
        // 取消按钮，通常显示文字而非图标
        return AppBarCancelButton(onTap: onTap);
    }
  }

  /// 获取按钮的宽度
  /// 不同类型的按钮需要不同的宽度来适配内容
  double? get width {
    switch (this) {
      case FlowyAppBarLeadingType.back:
        // 图标按钮的标准宽度
        return 40.0;
      case FlowyAppBarLeadingType.close:
        // 图标按钮的标准宽度
        return 40.0;
      case FlowyAppBarLeadingType.cancel:
        // 文字按钮需要更大的宽度来容纳文字
        return 120;
    }
  }
}

/// AppFlowy移动端统一应用栏组件
/// 
/// 这是AppFlowy移动端的标准应用栏实现，继承自Flutter的AppBar
/// 提供了统一的样式、高度、字体等设计规范
/// 
/// 主要特性：
/// - 统一的44.0高度适配移动端
/// - 标准化的前导按钮类型
/// - 可选的底部分割线
/// - 支持自定义标题和操作按钮
class FlowyAppBar extends AppBar {
  /// 构造函数
  /// 
  /// [title] 自定义标题Widget
  /// [titleText] 标题文字，如果提供了title则优先使用title
  /// [leadingType] 前导按钮类型，默认为返回按钮
  /// [leadingWidth] 前导按钮宽度，为空时使用类型对应的默认宽度
  /// [leading] 自定义前导按钮Widget
  /// [onTapLeading] 前导按钮点击回调
  /// [showDivider] 是否显示底部分割线，默认为true
  FlowyAppBar({
    super.key,
    super.actions,
    Widget? title,
    String? titleText,
    FlowyAppBarLeadingType leadingType = FlowyAppBarLeadingType.back,
    double? leadingWidth,
    Widget? leading,
    super.centerTitle,
    VoidCallback? onTapLeading,
    bool showDivider = true,
    super.backgroundColor,
  }) : super(
          // 标题处理：优先使用自定义title Widget，否则使用titleText创建标准样式的文字标题
          title: title ??
              FlowyText(
                titleText ?? '',
                fontSize: 15.0,
                fontWeight: FontWeight.w500,
              ),
          // 标题间距设为0，让标题紧贴前导按钮
          titleSpacing: 0,
          // 取消阴影，保持扁平化设计
          elevation: 0,
          // 前导按钮：优先使用自定义leading，否则根据类型生成
          leading: leading ?? leadingType.getWidget(onTapLeading),
          // 前导按钮宽度：优先使用自定义宽度，否则使用类型对应的默认宽度
          leadingWidth: leadingWidth ?? leadingType.width,
          // 统一的移动端工具栏高度44.0
          toolbarHeight: 44.0,
          // 底部分割线：根据showDivider参数决定是否显示
          bottom: showDivider
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(0.5),
                  child: Divider(
                    height: 0.5,
                  ),
                )
              : null,
        );
}
