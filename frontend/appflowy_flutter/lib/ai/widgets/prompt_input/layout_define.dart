/// AI提示词输入布局定义
/// 
/// 定义AI提示词输入界面的各种尺寸和间距常量
/// 分别为桌面端和移动端提供不同的布局参数

import 'package:flutter/widgets.dart';

/// 桌面端AI提示词输入布局尺寸
/// 
/// 定义桌面端平台上各个UI元素的尺寸和间距
class DesktopAIPromptSizes {
  const DesktopAIPromptSizes._();  // 私有构造函数，防止实例化

  // 附件栏内边距
  static const attachedFilesBarPadding =
      EdgeInsets.only(left: 8.0, top: 8.0, right: 8.0);
  // 附件预览高度
  static const attachedFilesPreviewHeight = 48.0;
  // 附件项间距
  static const attachedFilesPreviewSpacing = 12.0;

  // 预定义格式按钮高度
  static const predefinedFormatButtonHeight = 28.0;
  // 预定义格式图标高度
  static const predefinedFormatIconHeight = 16.0;

  // 文本输入框最小高度
  static const textFieldMinHeight = 36.0;
  // 文本输入框内容内边距（左、上、右、下）
  static const textFieldContentPadding =
      EdgeInsetsDirectional.fromSTEB(14.0, 8.0, 14.0, 8.0);

  // 操作栏按钮大小
  static const actionBarButtonSize = 28.0;
  // 操作栏图标大小
  static const actionBarIconSize = 16.0;
  // 操作栏发送按钮大小
  static const actionBarSendButtonSize = 32.0;
  // 操作栏发送按钮图标大小
  static const actionBarSendButtonIconSize = 24.0;
}

/// 移动端AI提示词输入布局尺寸
/// 
/// 定义移动端平台上各个UI元素的尺寸和间距
class MobileAIPromptSizes {
  const MobileAIPromptSizes._();  // 私有构造函数，防止实例化

  // 附件栏高度
  static const attachedFilesBarHeight = 68.0;
  // 附件栏内边距
  static const attachedFilesBarPadding =
      EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 4.0);
  // 附件预览高度
  static const attachedFilesPreviewHeight = 56.0;
  // 附件项间距
  static const attachedFilesPreviewSpacing = 8.0;

  // 预定义格式按钮高度
  static const predefinedFormatButtonHeight = 32.0;
  // 预定义格式图标高度
  static const predefinedFormatIconHeight = 20.0;

  // 文本输入框最小高度
  static const textFieldMinHeight = 32.0;
  // 文本输入框内容内边距
  static const textFieldContentPadding =
      EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);

  // 提及图标大小（@符号）
  static const mentionIconSize = 20.0;
  // 发送按钮大小
  static const sendButtonSize = 32.0;
}
