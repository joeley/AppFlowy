import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_input_control_cubit.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:extended_text_library/extended_text_library.dart';
import 'package:flutter/material.dart';

/// 提示词输入文本片段构建器
/// 
/// 功能说明：
/// 1. 识别并处理@提及的页面
/// 2. 将页面ID转换为页面名称显示
/// 3. 应用特殊样式高亮显示
/// 
/// 设计特点：
/// - 继承自SpecialTextSpanBuilder处理特殊文本
/// - 使用@符号作为触发标识
/// - 支持自定义样式
class PromptInputTextSpanBuilder extends SpecialTextSpanBuilder {
  PromptInputTextSpanBuilder({
    required this.inputControlCubit,
    this.mentionedPageTextStyle,
  });

  /// 输入控制状态管理器
  final ChatInputControlCubit inputControlCubit;
  /// 提及页面的文本样式
  final TextStyle? mentionedPageTextStyle;

  /// 创建特殊文本处理器
  /// 
  /// 功能：
  /// 1. 检测@符号开始的文本
  /// 2. 创建MentionedPageText处理器
  /// 3. 计算正确的起始位置
  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    int? index,
  }) {
    if (flag == '') {
      return null;
    }

    // 检测到@符号，创建提及页面文本处理器
    if (isStart(flag, MentionedPageText.flag)) {
      return MentionedPageText(
        inputControlCubit,
        mentionedPageTextStyle ?? textStyle,
        onTap,
        // 计算实际起始位置（减去标志长度）
        start: index! - (MentionedPageText.flag.length - 1),
      );
    }

    return null;
  }
}

/// 提及页面文本处理器
/// 
/// 功能说明：
/// 1. 处理@开头的特殊文本
/// 2. 将页面ID替换为页面名称
/// 3. 应用特殊样式
/// 
/// 工作流程：
/// - 识别@符号开始
/// - 读取页面ID直到结束
/// - 查找对应页面名称
/// - 生成带样式的文本片段
class MentionedPageText extends SpecialText {
  MentionedPageText(
    this.inputControlCubit,
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap, {
    this.start,
  }) : super(flag, '', textStyle, onTap: onTap);

  /// 提及标志符
  static const String flag = '@';

  /// 文本起始位置
  final int? start;
  /// 输入控制状态管理器
  final ChatInputControlCubit inputControlCubit;

  /// 判断是否到达文本结束
  /// 
  /// 当遇到已选择的视图ID时结束
  @override
  bool isEnd(String value) => inputControlCubit.selectedViewIds.contains(value);

  /// 完成文本处理，生成最终显示的文本片段
  /// 
  /// 功能：
  /// 1. 提取页面ID（去掉@符号）
  /// 2. 查找对应的页面名称
  /// 3. 处理空名称情况
  /// 4. 生成特殊文本片段
  @override
  InlineSpan finishText() {
    final String actualText = toString();

    // 根据ID查找页面名称
    final viewName = inputControlCubit.allViews
            .firstWhereOrNull((view) => view.id == actualText.substring(1))
            ?.name ??
        "";
    // 处理空名称
    final nonEmptyName = viewName.isEmpty
        ? LocaleKeys.document_title_placeholder.tr()
        : viewName;

    // 返回带样式的文本片段
    return SpecialTextSpan(
      text: "@$nonEmptyName",      // 显示文本：@页面名称
      actualText: actualText,      // 实际文本：@页面ID
      start: start!,               // 起始位置
      style: textStyle,            // 应用样式
    );
  }
}
