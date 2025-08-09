import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/widgets.dart';

/// 特殊字符替换定义
/// 
/// 设计说明：
/// 使用Unicode私有区域字符替换方括号，避免与正常文本冲突
/// 这样可以在文本中标记特殊内容（如变量、占位符）而不影响显示
final openingBracketReplacement = String.fromCharCode(0xFFFE);
final closingBracketReplacement = String.fromCharCode(0xFFFD);

/// AI提示词输入文本控制器
/// 
/// 功能说明：
/// 1. 特殊字符处理：方括号替换和还原
/// 2. 提示词内容设置
/// 3. 富文本渲染：高亮显示方括号内容
/// 
/// 设计特点：
/// - 使用特殊字符避免与Markdown等格式冲突
/// - 自定义文本样式渲染
/// - 支持变量占位符高亮显示
class AiPromptInputTextEditingController extends TextEditingController {
  AiPromptInputTextEditingController();

  /// 替换文本中的方括号为特殊字符
  /// 
  /// 功能说明：
  /// 将普通方括号替换为私有区域字符，避免解析冲突
  /// 用于提示词模板中的变量标记
  /// 
  /// 参数：
  /// - [text]: 原始文本
  /// 
  /// 返回：替换后的文本
  static String replace(String text) {
    return text
        .replaceAll('[', openingBracketReplacement)
        .replaceAll(']', closingBracketReplacement);
  }

  /// 还原特殊字符为方括号
  /// 
  /// 功能说明：
  /// 将私有区域字符还原为普通方括号
  /// 用于最终提交时恢复原始格式
  /// 
  /// 参数：
  /// - [text]: 包含特殊字符的文本
  /// 
  /// 返回：还原后的文本
  static String restore(String text) {
    return text
        .replaceAll(openingBracketReplacement, '[')
        .replaceAll(closingBracketReplacement, ']');
  }

  /// 使用提示词模板填充输入框
  /// 
  /// 功能说明：
  /// 设置输入框内容为提示词模板
  /// 光标自动定位到末尾，方便继续编辑
  /// 
  /// 参数：
  /// - [content]: 提示词模板内容
  void usePrompt(String content) {
    value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(
        offset: content.length,
      ),
    );
  }

  /// 构建富文本展示
  /// 
  /// 重写父类方法，实现自定义文本渲染
  /// 为方括号内容添加高亮样式
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(
      style: style,
      children: <InlineSpan>[...getTextSpans(context)],
    );
  }

  /// 生成带样式的文本片段
  /// 
  /// 功能说明：
  /// 1. 使用正则表达式匹配特殊字符包围的内容
  /// 2. 为匹配内容添加高亮样式（特色文本颜色+背景）
  /// 3. 普通文本保持默认样式
  /// 
  /// 设计特点：
  /// - 使用splitMapJoin高效处理文本分割
  /// - 特色内容使用featured主题色突出显示
  /// - 背景色使用半透明效果，不影响文本可读性
  Iterable<TextSpan> getTextSpans(BuildContext context) {
    final open = openingBracketReplacement;
    final close = closingBracketReplacement;
    // 匹配被特殊字符包围的内容
    final regex = RegExp('($open[^$open$close]*?$close)');
    final theme = AppFlowyTheme.of(context);

    final result = <TextSpan>[];

    text.splitMapJoin(
      regex,
      onMatch: (match) {
        final string = match.group(0)!;
        // 为匹配内容添加高亮样式
        result.add(
          TextSpan(
            text: restore(string),  // 还原方括号用于显示
            style: theme.textStyle.body.standard().copyWith(
                  color: theme.textColorScheme.featured,  // 特色文本颜色
                  backgroundColor:
                      theme.fillColorScheme.featuredThick.withAlpha(51),  // 半透明背景
                ),
          ),
        );
        return '';
      },
      onNonMatch: (nonMatch) {
        // 普通文本保持默认样式
        result.add(
          TextSpan(
            text: restore(nonMatch),
          ),
        );
        return '';
      },
    );

    return result;
  }
}
