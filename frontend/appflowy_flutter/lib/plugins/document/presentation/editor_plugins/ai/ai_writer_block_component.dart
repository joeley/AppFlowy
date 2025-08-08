/*
 * AI写作助手块组件
 * 
 * 设计理念：
 * 提供在文档中嵌入AI写作助手的功能，帮助用户生成、优化和改写文本。
 * 通过提示词输入和AI建议，实现智能写作辅助。
 * 
 * 核心功能：
 * 1. 提示词输入界面
 * 2. AI文本生成
 * 3. 建议预览和应用
 * 4. 多种写作命令支持
 * 
 * 命令类型：
 * - 继续写作
 * - 改进文本
 * - 总结内容
 * - 调整语气
 * - 翻译文本
 * 
 * 使用场景：
 * - 内容创作
 * - 文本优化
 * - 语言翻译
 * - 摘要生成
 */

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/ai_markdown_text.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import 'operations/ai_writer_cubit.dart';
import 'operations/ai_writer_entities.dart';
import 'operations/ai_writer_node_extension.dart';
import 'widgets/ai_writer_suggestion_actions.dart';
import 'widgets/ai_writer_prompt_input_more_button.dart';

/*
 * AI写作块键值常量
 * 
 * 定义AI写作块的属性键名，用于存储和识别块状态。
 */
class AiWriterBlockKeys {
  const AiWriterBlockKeys._();

  static const String type = 'ai_writer';  /* 块类型标识 */

  static const String isInitialized = 'is_initialized';  /* 初始化状态 */
  static const String selection = 'selection';  /* 选中区域 */
  static const String command = 'command';  /* AI命令类型 */

  /*
   * 建议属性
   * 
   * 示例：
   * attributes: {
   *   'ai_writer_delta_suggestion': 'original'  // 原始文本
   * }
   */
  static const String suggestion = 'ai_writer_delta_suggestion';
  static const String suggestionOriginal = 'original';  /* 原始内容 */
  static const String suggestionReplacement = 'replacement';  /* 替换内容 */
}

/*
 * 创建AI写作节点
 * 
 * 功能：
 * 构建AI写作块的节点对象。
 * 
 * 参数：
 * - selection：当前选中区域
 * - command：AI命令类型
 * 
 * 返回：配置好属性的AI写作节点
 */
Node aiWriterNode({
  required Selection? selection,
  required AiWriterCommand command,
}) {
  return Node(
    type: AiWriterBlockKeys.type,
    attributes: {
      AiWriterBlockKeys.isInitialized: false,  /* 未初始化状态 */
      AiWriterBlockKeys.selection: selection?.toJson(),  /* 保存选区 */
      AiWriterBlockKeys.command: command.index,  /* 保存命令 */
    },
  );
}

/*
 * AI写作块构建器
 * 
 * 职责：
 * 1. 构建AI写作块组件
 * 2. 验证节点有效性
 * 3. 配置操作按钮
 */
class AIWriterBlockComponentBuilder extends BlockComponentBuilder {
  AIWriterBlockComponentBuilder();

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return AiWriterBlockComponent(
      key: node.key,
      node: node,
      showActions: showActions(node),
      /* 构建操作按钮 */
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      /* 构建尾部操作 */
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  /*
   * 验证节点
   * 
   * 检查条件：
   * - 无子节点
   * - 必须有isInitialized属性
   * - 可选的selection属性
   * - 必须有command属性
   */
  @override
  BlockComponentValidate get validate => (node) =>
      node.children.isEmpty &&
      node.attributes[AiWriterBlockKeys.isInitialized] is bool &&
      node.attributes[AiWriterBlockKeys.selection] is Map? &&
      node.attributes[AiWriterBlockKeys.command] is int;
}

/*
 * AI写作块组件
 * 
 * 功能：
 * 显示AI写作助手界面，处理用户输入和AI响应。
 * 
 * 特性：
 * - 悬浮输入框
 * - 实时预览
 * - 操作按钮
 * - 移动端隐藏
 */
class AiWriterBlockComponent extends BlockComponentStatefulWidget {
  const AiWriterBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<AiWriterBlockComponent> createState() => _AIWriterBlockComponentState();
}

/*
 * AI写作块状态
 * 
 * 管理：
 * - 提示词输入
 * - 悬浮层显示
 * - 焦点控制
 * - 生命周期
 */
class _AIWriterBlockComponentState extends State<AiWriterBlockComponent> {
  final textController = AiPromptInputTextEditingController();  /* 提示词输入控制器 */
  final overlayController = OverlayPortalController();  /* 悬浮层控制器 */
  final layerLink = LayerLink();  /* 图层链接 */
  final focusNode = FocusNode();  /* 焦点节点 */

  late final editorState = context.read<EditorState>();  /* 编辑器状态 */

  @override
  void initState() {
    super.initState();

    /* 在下一帧显示悬浮层和注册节点 */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      overlayController.show();
      context.read<AiWriterCubit>().register(widget.node);
    });
  }

  @override
  void dispose() {
    /* 清理资源 */
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /* 移动端不显示AI写作块 */
    if (UniversalPlatform.isMobile) {
      return const SizedBox.shrink();
    }

    final documentId = context.read<DocumentBloc?>()?.documentId;

    return BlocProvider(
      create: (_) => AIPromptInputBloc(
        predefinedFormat: null,
        objectId: documentId ?? editorState.document.root.id,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return OverlayPortal(
            controller: overlayController,
            overlayChildBuilder: (context) {
              return Center(
                child: CompositedTransformFollower(
                  link: layerLink,
                  showWhenUnlinked: false,
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 40.0,
                      bottom: 16.0,
                    ),
                    width: constraints.maxWidth,
                    child: Focus(
                      focusNode: focusNode,
                      child: OverlayContent(
                        editorState: editorState,
                        node: widget.node,
                        textController: textController,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: CompositedTransformTarget(
              link: layerLink,
              child: BlocBuilder<AiWriterCubit, AiWriterState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 1.0,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class OverlayContent extends StatefulWidget {
  const OverlayContent({
    super.key,
    required this.editorState,
    required this.node,
    required this.textController,
  });

  final EditorState editorState;
  final Node node;
  final AiPromptInputTextEditingController textController;

  @override
  State<OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<OverlayContent> {
  final showCommandsToggle = ValueNotifier(false);

  @override
  void dispose() {
    showCommandsToggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiWriterCubit, AiWriterState>(
      builder: (context, state) {
        if (state is IdleAiWriterState ||
            state is DocumentContentEmptyAiWriterState) {
          return const SizedBox.shrink();
        }

        final command = (state as RegisteredAiWriter).command;

        final selection = widget.node.aiWriterSelection;
        final hasSelection = selection != null && !selection.isCollapsed;

        final markdownText = switch (state) {
          final ReadyAiWriterState ready => ready.markdownText,
          final GeneratingAiWriterState generating => generating.markdownText,
          _ => '',
        };

        final showSuggestedActions =
            state is ReadyAiWriterState && !state.isFirstRun;
        final isInitialReadyState =
            state is ReadyAiWriterState && state.isFirstRun;
        final showSuggestedActionsPopup =
            showSuggestedActions && markdownText.isEmpty ||
                (markdownText.isNotEmpty && command != AiWriterCommand.explain);
        final showSuggestedActionsWithin = showSuggestedActions &&
            markdownText.isNotEmpty &&
            command == AiWriterCommand.explain;

        final borderColor = Theme.of(context).isLightMode
            ? Color(0x1F1F2329)
            : Color(0xFF505469);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSuggestedActionsPopup) ...[
              Container(
                padding: EdgeInsets.all(4.0),
                decoration: _getModalDecoration(
                  context,
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  borderColor: borderColor,
                ),
                child: SuggestionActionBar(
                  currentCommand: command,
                  hasSelection: hasSelection,
                  onTap: (action) {
                    _onSelectSuggestionAction(context, action);
                  },
                ),
              ),
              const VSpace(4.0 + 1.0),
            ],
            Container(
              decoration: _getModalDecoration(
                context,
                color: null,
                borderColor: borderColor,
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
              constraints: BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (markdownText.isNotEmpty) ...[
                    Flexible(
                      child: DecoratedBox(
                        decoration: _secondaryContentDecoration(context),
                        child: SecondaryContentArea(
                          markdownText: markdownText,
                          onSelectSuggestionAction: (action) {
                            _onSelectSuggestionAction(context, action);
                          },
                          command: command,
                          showSuggestionActions: showSuggestedActionsWithin,
                          hasSelection: hasSelection,
                        ),
                      ),
                    ),
                    Divider(height: 1.0),
                  ],
                  DecoratedBox(
                    decoration: markdownText.isNotEmpty
                        ? _mainContentDecoration(context)
                        : _getSingleChildDeocoration(context),
                    child: MainContentArea(
                      textController: widget.textController,
                      isDocumentEmpty: _isDocumentEmpty(),
                      isInitialReadyState: isInitialReadyState,
                      showCommandsToggle: showCommandsToggle,
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder(
              valueListenable: showCommandsToggle,
              builder: (context, value, child) {
                if (!value || !isInitialReadyState) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: MoreAiWriterCommands(
                    hasSelection: hasSelection,
                    editorState: widget.editorState,
                    onSelectCommand: (command) {
                      final bloc = context.read<AIPromptInputBloc>();
                      final promptId = bloc.promptId;
                      final state = bloc.state;
                      final showPredefinedFormats = state.showPredefinedFormats;
                      final predefinedFormat = state.predefinedFormat;
                      final text = widget.textController.text;

                      context.read<AiWriterCubit>().runCommand(
                            command,
                            text,
                            showPredefinedFormats ? predefinedFormat : null,
                            promptId,
                          );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  BoxDecoration _getModalDecoration(
    BuildContext context, {
    required Color? color,
    required Color borderColor,
    required BorderRadius borderRadius,
  }) {
    return BoxDecoration(
      color: color,
      border: Border.all(
        color: borderColor,
        strokeAlign: BorderSide.strokeAlignOutside,
      ),
      borderRadius: borderRadius,
      boxShadow: Theme.of(context).isLightMode
          ? ShadowConstants.lightSmall
          : ShadowConstants.darkSmall,
    );
  }

  BoxDecoration _getSingleChildDeocoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
    );
  }

  BoxDecoration _secondaryContentDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
    );
  }

  BoxDecoration _mainContentDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
    );
  }

  void _onSelectSuggestionAction(
    BuildContext context,
    SuggestionAction action,
  ) {
    final predefinedFormat =
        context.read<AIPromptInputBloc>().state.predefinedFormat;
    context.read<AiWriterCubit>().runResponseAction(
          action,
          predefinedFormat,
        );
  }

  bool _isDocumentEmpty() {
    if (widget.editorState.isEmptyForContinueWriting()) {
      final documentContext = widget.editorState.document.root.context;
      if (documentContext == null) {
        return true;
      }
      final view = documentContext.read<ViewBloc>().state.view;
      if (view.name.isEmpty) {
        return true;
      }
    }
    return false;
  }
}

class SecondaryContentArea extends StatelessWidget {
  const SecondaryContentArea({
    super.key,
    required this.command,
    required this.markdownText,
    required this.showSuggestionActions,
    required this.hasSelection,
    required this.onSelectSuggestionAction,
  });

  final AiWriterCommand command;
  final String markdownText;
  final bool showSuggestionActions;
  final bool hasSelection;
  final void Function(SuggestionAction) onSelectSuggestionAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSpace(8.0),
          Container(
            height: 24.0,
            padding: EdgeInsets.symmetric(horizontal: 14.0),
            alignment: AlignmentDirectional.centerStart,
            child: FlowyText(
              command.i18n,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666D76),
            ),
          ),
          const VSpace(4.0),
          Flexible(
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 14.0),
              child: AIMarkdownText(
                markdown: markdownText,
              ),
            ),
          ),
          if (showSuggestionActions) ...[
            const VSpace(4.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SuggestionActionBar(
                currentCommand: command,
                hasSelection: hasSelection,
                onTap: onSelectSuggestionAction,
              ),
            ),
          ],
          const VSpace(8.0),
        ],
      ),
    );
  }
}

class MainContentArea extends StatelessWidget {
  const MainContentArea({
    super.key,
    required this.textController,
    required this.isInitialReadyState,
    required this.isDocumentEmpty,
    required this.showCommandsToggle,
  });

  final AiPromptInputTextEditingController textController;
  final bool isInitialReadyState;
  final bool isDocumentEmpty;
  final ValueNotifier<bool> showCommandsToggle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiWriterCubit, AiWriterState>(
      builder: (context, state) {
        final cubit = context.read<AiWriterCubit>();

        if (state is ReadyAiWriterState) {
          return DesktopPromptInput(
            isStreaming: false,
            hideDecoration: true,
            hideFormats: [
              AiWriterCommand.fixSpellingAndGrammar,
              AiWriterCommand.improveWriting,
              AiWriterCommand.makeLonger,
              AiWriterCommand.makeShorter,
            ].contains(state.command),
            textController: textController,
            onSubmitted: (message, format, _, promptId) {
              cubit.runCommand(state.command, message, format, promptId);
            },
            onStopStreaming: () => cubit.stopStream(),
            selectedSourcesNotifier: cubit.selectedSourcesNotifier,
            onUpdateSelectedSources: (sources) {
              cubit.selectedSourcesNotifier.value = [
                ...sources,
              ];
            },
            extraBottomActionButton: isInitialReadyState
                ? ValueListenableBuilder(
                    valueListenable: showCommandsToggle,
                    builder: (context, value, _) {
                      return AiWriterPromptMoreButton(
                        isEnabled: !isDocumentEmpty,
                        isSelected: value,
                        onTap: () => showCommandsToggle.value = !value,
                      );
                    },
                  )
                : null,
          );
        }
        if (state is GeneratingAiWriterState) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const HSpace(6.0),
                Expanded(
                  child: AILoadingIndicator(
                    text: state.command == AiWriterCommand.explain
                        ? LocaleKeys.ai_analyzing.tr()
                        : LocaleKeys.ai_editing.tr(),
                  ),
                ),
                const HSpace(8.0),
                PromptInputSendButton(
                  state: SendButtonState.streaming,
                  onSendPressed: () {},
                  onStopStreaming: () => cubit.stopStream(),
                ),
              ],
            ),
          );
        }
        if (state is ErrorAiWriterState) {
          return Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                const FlowySvg(
                  FlowySvgs.toast_error_filled_s,
                  blendMode: null,
                ),
                const HSpace(8.0),
                Expanded(
                  child: FlowyText(
                    state.error.message,
                    maxLines: null,
                  ),
                ),
                const HSpace(8.0),
                FlowyIconButton(
                  width: 32,
                  hoverColor: Colors.transparent,
                  icon: FlowySvg(
                    FlowySvgs.toast_close_s,
                    size: Size.square(20),
                  ),
                  onPressed: () => cubit.exit(),
                ),
              ],
            ),
          );
        }
        if (state is LocalAIStreamingAiWriterState) {
          final text = switch (state.state) {
            LocalAIStreamingState.notReady =>
              LocaleKeys.settings_aiPage_keys_localAINotReadyRetryLater.tr(),
            LocalAIStreamingState.disabled =>
              LocaleKeys.settings_aiPage_keys_localAIDisabled.tr(),
          };
          return Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                const HSpace(8.0),
                Opacity(
                  opacity: 0.5,
                  child: FlowyText(text),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
