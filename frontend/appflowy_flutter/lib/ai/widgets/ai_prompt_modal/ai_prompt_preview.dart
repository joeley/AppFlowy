import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/ai_markdown_text.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

/// AI提示词预览组件
/// 
/// 功能说明：
/// 1. 显示选中提示词的详细信息，包括名称、内容和示例
/// 2. 提供"使用提示词"按钮，用户可直接应用该提示词
/// 3. 支持文本选择，方便用户复制提示词内容
/// 
/// 布局设计：
/// - 顶部：标题栏，包含提示词名称和使用按钮
/// - 中部：提示词内容区，支持变量高亮显示
/// - 底部：可选的示例区域，使用Markdown渲染
class AiPromptPreview extends StatelessWidget {
  const AiPromptPreview({
    super.key,
    required this.prompt,
  });

  // 要预览的提示词对象
  final AiPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    // SelectionArea使整个预览区域的文本可选择
    return SelectionArea(
      child: Column(
        children: [
          // 顶部标题栏
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.l,
            ),
            // 禁用标题栏的选择功能，避免按钮被选中
            child: SelectionContainer.disabled(
              child: Row(
                children: [
                  // 提示词名称，占据剩余空间
                  Expanded(
                    child: Text(
                      prompt.name,
                      style: theme.textStyle.headline.standard(
                        color: theme.textColorScheme.primary,
                      ),
                    ),
                  ),
                  HSpace(theme.spacing.s),
                  // "使用提示词"按钮
                  AFFilledTextButton.primary(
                    text: LocaleKeys.ai_customPrompt_usePrompt.tr(),
                    onTap: () {
                      // 点击后返回选中的提示词对象
                      Navigator.of(context).pop(prompt);
                    },
                  ),
                ],
              ),
            ),
          ),
          VSpace(theme.spacing.xs),
          // 可滚动的内容区域
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(
                theme.spacing.l,
              ),
              children: [
                // "提示词"标题
                SelectionContainer.disabled(
                  child: Text(
                    LocaleKeys.ai_customPrompt_prompt.tr(),
                    style: theme.textStyle.heading4.standard(
                      color: theme.textColorScheme.primary,
                    ),
                  ),
                ),
                VSpace(theme.spacing.xs),
                // 提示词内容组件
                _PromptContent(
                  prompt: prompt,
                ),
                VSpace(theme.spacing.xl),
                // 条件渲染：仅在有示例时显示示例区域
                if (prompt.example.isNotEmpty) ...[
                  // "示例"标题
                  SelectionContainer.disabled(
                    child: Text(
                      LocaleKeys.ai_customPrompt_promptExample.tr(),
                      style: theme.textStyle.heading4.standard(
                        color: theme.textColorScheme.primary,
                      ),
                    ),
                  ),
                  VSpace(theme.spacing.xs),
                  // 示例内容组件
                  _PromptExample(
                    prompt: prompt,
                  ),
                  VSpace(theme.spacing.xl),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 提示词内容展示组件
/// 
/// 功能：
/// 1. 渲染提示词的具体内容
/// 2. 自动识别并高亮显示变量（用[]包裹的文本）
/// 3. 提供背景色区分内容区域
/// 
/// 技术实现：
/// - 使用正则表达式解析变量占位符
/// - 通过TextSpan实现不同样式的文本渲染
class _PromptContent extends StatelessWidget {
  const _PromptContent({
    required this.prompt,
  });

  final AiPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    // 构建带样式的文本片段
    final textSpans = _buildTextSpans(context, prompt.content);

    return Container(
      padding: EdgeInsets.all(theme.spacing.l),
      decoration: BoxDecoration(
        // 使用layer01背景色区分内容区域
        color: theme.surfaceContainerColorScheme.layer01,
        borderRadius: BorderRadius.circular(theme.borderRadius.m),
      ),
      child: Text.rich(
        TextSpan(
          style: theme.textStyle.body.standard(
            color: theme.textColorScheme.primary,
          ),
          children: textSpans,
        ),
      ),
    );
  }

  /// 构建文本片段列表
  /// 
  /// 将提示词内容分割成多个片段，对变量部分应用特殊样式
  /// [text] 原始提示词文本
  /// 返回：带样式的TextSpan列表
  List<TextSpan> _buildTextSpans(BuildContext context, String text) {
    final theme = AppFlowyTheme.of(context);
    final spans = <TextSpan>[];

    // 分割文本，识别变量占位符
    final parts = _splitPromptText(text);
    for (final part in parts) {
      // 检查是否为变量（以[]包裹）
      if (part.startsWith('[') && part.endsWith(']')) {
        // 变量使用特殊颜色高亮
        spans.add(
          TextSpan(
            text: part,
            style: TextStyle(color: theme.textColorScheme.featured),
          ),
        );
      } else {
        // 普通文本使用默认样式
        spans.add(TextSpan(text: part));
      }
    }

    return spans;
  }

  /// 分割提示词文本
  /// 
  /// 使用正则表达式识别[变量]格式的占位符
  /// 将文本分割成普通文本和变量两种类型
  /// 
  /// [text] 待分割的文本
  /// 返回：分割后的文本片段列表
  List<String> _splitPromptText(String text) {
    // 匹配[]包裹的内容，不包含嵌套的[]
    final regex = RegExp(r'(\[[^\[\]]*?\])');

    final result = <String>[];

    // splitMapJoin会遍历所有匹配和非匹配的部分
    text.splitMapJoin(
      regex,
      onMatch: (match) {
        // 添加匹配的变量部分
        result.add(match.group(0)!);
        return '';
      },
      onNonMatch: (nonMatch) {
        // 添加普通文本部分
        result.add(nonMatch);
        return '';
      },
    );

    return result;
  }
}

/// 提示词示例展示组件
/// 
/// 功能：
/// 1. 显示提示词的使用示例
/// 2. 支持Markdown格式渲染
/// 3. 提供与内容区域一致的视觉样式
/// 
/// 特点：
/// - 使用AIMarkdownText组件渲染富文本
/// - 支持代码块、列表、强调等Markdown语法
/// - 与提示词内容区域保持视觉一致性
class _PromptExample extends StatelessWidget {
  const _PromptExample({
    required this.prompt,
  });

  final AiPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Container(
      padding: EdgeInsets.all(theme.spacing.l),
      decoration: BoxDecoration(
        // 使用与内容区域相同的背景色
        color: theme.surfaceContainerColorScheme.layer01,
        borderRadius: BorderRadius.circular(theme.borderRadius.m),
      ),
      child: AIMarkdownText(
        // 使用AI专用的Markdown渲染器，支持更丰富的格式
        markdown: prompt.example,
      ),
    );
  }
}
