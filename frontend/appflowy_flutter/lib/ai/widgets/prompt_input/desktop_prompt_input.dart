import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_input_control_cubit.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_user_cubit.dart';
import 'package:appflowy/plugins/ai_chat/presentation/layout_define.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'browse_prompts_button.dart';

/// 提示词输入提交回调类型定义
/// 
/// 参数说明：
/// - [input]: 用户输入的文本内容
/// - [predefinedFormat]: 预定义格式（如表格、列表等）
/// - [metadata]: 元数据（包含附件、提及页面等）
/// - [promptId]: 选中的提示词ID
typedef OnPromptInputSubmitted = void Function(
  String input,
  PredefinedFormat? predefinedFormat,
  Map<String, dynamic> metadata,
  String? promptId,
);

/// 桌面端AI提示词输入组件
/// 
/// 功能架构：
/// 1. 多行文本输入框，支持@提及页面
/// 2. 文件附件上传（PDF、TXT、MD）
/// 3. 预定义格式选择（表格、列表等）
/// 4. 数据源选择（选择要搜索的页面）
/// 5. AI模型选择
/// 6. 提示词模板浏览和选择
/// 
/// 设计特点：
/// - 复杂的状态管理（流式输出、输入状态、格式选择）
/// - 键盘快捷键支持（Enter发送、Esc取消等）
/// - 响应式布局，自适应内容高度
/// - 丰富的交互反馈（悬停、聚焦、禁用状态）
class DesktopPromptInput extends StatefulWidget {
  const DesktopPromptInput({
    super.key,
    required this.isStreaming,
    required this.textController,
    required this.onStopStreaming,
    required this.onSubmitted,
    required this.selectedSourcesNotifier,
    required this.onUpdateSelectedSources,
    this.hideDecoration = false,
    this.hideFormats = false,
    this.extraBottomActionButton,
  });

  /// AI是否正在生成回复（流式输出状态）
  final bool isStreaming;
  /// 文本输入控制器，支持特殊格式处理
  final AiPromptInputTextEditingController textController;
  /// 停止流式生成的回调
  final void Function() onStopStreaming;
  /// 提交输入的回调函数
  final OnPromptInputSubmitted onSubmitted;
  /// 选中数据源的通知器
  final ValueNotifier<List<String>> selectedSourcesNotifier;
  /// 更新选中数据源的回调
  final void Function(List<String>) onUpdateSelectedSources;
  /// 是否隐藏边框装饰
  final bool hideDecoration;
  /// 是否隐藏格式选择按钮
  final bool hideFormats;
  /// 额外的底部操作按钮
  final Widget? extraBottomActionButton;

  @override
  State<DesktopPromptInput> createState() => _DesktopPromptInputState();
}

class _DesktopPromptInputState extends State<DesktopPromptInput> {
  /// 文本输入框的全局键，用于定位
  final textFieldKey = GlobalKey();
  /// 图层链接，用于@提及菜单定位
  final layerLink = LayerLink();
  /// 弹出层控制器，管理@提及菜单显示
  final overlayController = OverlayPortalController();
  /// 输入控制状态管理器
  final inputControlCubit = ChatInputControlCubit();
  /// 聊天用户状态管理器
  final chatUserCubit = ChatUserCubit();
  /// 焦点节点，管理输入框焦点
  final focusNode = FocusNode();

  /// 发送按钮状态（启用/禁用/流式）
  late SendButtonState sendButtonState;
  /// 是否正在输入（IME组合状态）
  bool isComposing = false;

  @override
  void initState() {
    super.initState();

    // 监听文本变化，处理@提及和发送按钮状态
    widget.textController.addListener(handleTextControllerChanged);
    focusNode
      ..addListener(
        () {
          if (!widget.hideDecoration) {
            setState(() {}); // 刷新边框颜色
          }
          if (!focusNode.hasFocus) {
            cancelMentionPage(); // 失去焦点时隐藏@提及菜单
          }
        },
      )
      ..onKeyEvent = handleKeyEvent;  // 处理键盘事件

    updateSendButtonState();

    // 初始化后自动聚焦，并检查是否从命令面板跳转而来
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
      checkForAskingAI();  // 检查是否需要自动执行AI查询
    });
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    updateSendButtonState();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    focusNode.dispose();
    widget.textController.removeListener(handleTextControllerChanged);
    inputControlCubit.close();
    chatUserCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: inputControlCubit),
        BlocProvider.value(value: chatUserCubit),
      ],
      child: BlocListener<ChatInputControlCubit, ChatInputControlState>(
        listener: (context, state) {
          state.maybeWhen(
            updateSelectedViews: (selectedViews) {
              context
                  .read<AIPromptInputBloc>()
                  .add(AIPromptInputEvent.updateMentionedViews(selectedViews));
            },
            orElse: () {},
          );
        },
        child: OverlayPortal(
          controller: overlayController,
          overlayChildBuilder: (context) {
            return PromptInputMentionPageMenu(
              anchor: PromptInputAnchor(textFieldKey, layerLink),
              textController: widget.textController,
              onPageSelected: handlePageSelected,
            );
          },
          child: DecoratedBox(
            decoration: decoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        DesktopAIPromptSizes.attachedFilesBarPadding.vertical +
                            DesktopAIPromptSizes.attachedFilesPreviewHeight,
                  ),
                  child: TextFieldTapRegion(
                    child: PromptInputFile(
                      onDeleted: (file) => context
                          .read<AIPromptInputBloc>()
                          .add(AIPromptInputEvent.removeFile(file)),
                    ),
                  ),
                ),
                const VSpace(4.0),
                BlocBuilder<AIPromptInputBloc, AIPromptInputState>(
                  builder: (context, state) {
                    return Stack(
                      children: [
                        ConstrainedBox(
                          constraints: getTextFieldConstraints(
                            state.showPredefinedFormats && !widget.hideFormats,
                          ),
                          child: inputTextField(),
                        ),
                        if (state.showPredefinedFormats && !widget.hideFormats)
                          Positioned.fill(
                            bottom: null,
                            child: TextFieldTapRegion(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 8.0,
                                ),
                                child: ChangeFormatBar(
                                  showImageFormats:
                                      state.modelState.type == AiType.cloud,
                                  predefinedFormat: state.predefinedFormat,
                                  spacing: 4.0,
                                  onSelectPredefinedFormat: (format) =>
                                      context.read<AIPromptInputBloc>().add(
                                            AIPromptInputEvent
                                                .updatePredefinedFormat(format),
                                          ),
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          top: null,
                          child: TextFieldTapRegion(
                            child: _PromptBottomActions(
                              showPredefinedFormatBar:
                                  state.showPredefinedFormats,
                              showPredefinedFormatButton: !widget.hideFormats,
                              onTogglePredefinedFormatSection: () =>
                                  context.read<AIPromptInputBloc>().add(
                                        AIPromptInputEvent
                                            .toggleShowPredefinedFormat(),
                                      ),
                              onStartMention: startMentionPageFromButton,
                              sendButtonState: sendButtonState,
                              onSendPressed: handleSend,
                              onStopStreaming: widget.onStopStreaming,
                              selectedSourcesNotifier:
                                  widget.selectedSourcesNotifier,
                              onUpdateSelectedSources:
                                  widget.onUpdateSelectedSources,
                              onSelectPrompt: handleOnSelectPrompt,
                              extraBottomActionButton:
                                  widget.extraBottomActionButton,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration decoration(BuildContext context) {
    if (widget.hideDecoration) {
      return BoxDecoration();
    }
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: focusNode.hasFocus
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        width: focusNode.hasFocus ? 1.5 : 1.0,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(12.0)),
    );
  }

  /// 检查是否从命令面板触发的AI查询
  /// 
  /// 功能说明：
  /// 1. 从命令面板状态读取查询内容
  /// 2. 获取选中的数据源
  /// 3. 自动提交查询
  void checkForAskingAI() {
    final paletteBloc = context.read<CommandPaletteBloc?>(),
        paletteState = paletteBloc?.state;
    if (paletteBloc == null || paletteState == null) return;
    
    // 检查是否是AI查询模式
    final isAskingAI = paletteState.askAI;
    if (!isAskingAI) return;
    
    // 标记已处理，避免重复执行
    paletteBloc.add(CommandPaletteEvent.askedAI());
    
    // 获取查询内容
    final query = paletteState.query ?? '';
    if (query.isEmpty) return;
    
    // 获取选中的数据源
    final sources = (paletteState.askAISources ?? []).map((e) => e.id).toList();
    
    // 获取元数据和提示词配置
    final metadata =
        context.read<AIPromptInputBloc?>()?.consumeMetadata() ?? {};
    final promptBloc = context.read<AIPromptInputBloc?>();
    final promptId = promptBloc?.promptId;
    final promptState = promptBloc?.state;
    final predefinedFormat = promptState?.predefinedFormat;
    
    // 更新数据源并提交查询
    if (sources.isNotEmpty) {
      widget.onUpdateSelectedSources(sources);
    }
    widget.onSubmitted.call(query, predefinedFormat, metadata, promptId ?? '');
  }

  /// 从按钮触发@提及功能
  /// 
  /// 流程：
  /// 1. 确保输入框获得焦点
  /// 2. 插入@符号
  /// 3. 显示页面选择菜单
  void startMentionPageFromButton() {
    // 避免重复显示
    if (overlayController.isShowing) {
      return;
    }
    // 确保输入框聚焦
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    // 插入@符号
    widget.textController.text += '@';
    // 下一帧显示菜单，确保@符号已渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context
            .read<ChatInputControlCubit>()
            .startSearching(widget.textController.value);
        overlayController.show();
      }
    });
  }

  void cancelMentionPage() {
    if (overlayController.isShowing) {
      inputControlCubit.reset();
      overlayController.hide();
    }
  }

  void updateSendButtonState() {
    if (widget.isStreaming) {
      sendButtonState = SendButtonState.streaming;
    } else if (widget.textController.text.trim().isEmpty) {
      sendButtonState = SendButtonState.disabled;
    } else {
      sendButtonState = SendButtonState.enabled;
    }
  }

  /// 处理发送操作
  /// 
  /// 功能流程：
  /// 1. 验证是否可发送（非流式状态、有内容）
  /// 2. 格式化输入文本
  /// 3. 收集元数据（附件、提及页面）
  /// 4. 获取格式设置
  /// 5. 调用提交回调
  void handleSend() {
    // 流式输出时不能发送新消息
    if (widget.isStreaming) {
      return;
    }
    
    // 处理和格式化输入文本
    String userInput = widget.textController.text.trim();
    userInput = inputControlCubit.formatIntputText(userInput);  // 格式化@提及
    userInput = AiPromptInputTextEditingController.restore(userInput);  // 还原特殊字符

    // 清空输入框
    widget.textController.clear();
    if (userInput.isEmpty) {
      return;
    }

    // 获取附件和提及页面的元数据
    final metadata = context.read<AIPromptInputBloc>().consumeMetadata();

    // 获取格式设置
    final bloc = context.read<AIPromptInputBloc>();
    final showPredefinedFormats = bloc.state.showPredefinedFormats;
    final predefinedFormat = bloc.state.predefinedFormat;

    // 提交输入
    widget.onSubmitted(
      userInput,
      showPredefinedFormats ? predefinedFormat : null,
      metadata,
      bloc.promptId,
    );
  }

  void handleTextControllerChanged() {
    setState(() {
      // update whether send button is clickable
      updateSendButtonState();
      isComposing = !widget.textController.value.composing.isCollapsed;
    });

    if (isComposing) {
      return;
    }

    // disable mention
    return;

    // handle text and selection changes ONLY when mentioning a page
    // ignore: dead_code
    if (!overlayController.isShowing ||
        inputControlCubit.filterStartPosition == -1) {
      return;
    }

    // handle cases where mention a page is cancelled
    final textController = widget.textController;
    final textSelection = textController.value.selection;
    final isSelectingMultipleCharacters = !textSelection.isCollapsed;
    final isCaretBeforeStartOfRange =
        textSelection.baseOffset < inputControlCubit.filterStartPosition;
    final isCaretAfterEndOfRange =
        textSelection.baseOffset > inputControlCubit.filterEndPosition;
    final isTextSame = inputControlCubit.inputText == textController.text;

    if (isSelectingMultipleCharacters ||
        isTextSame && (isCaretBeforeStartOfRange || isCaretAfterEndOfRange)) {
      cancelMentionPage();
      return;
    }

    final previousLength = inputControlCubit.inputText.characters.length;
    final currentLength = textController.text.characters.length;

    // delete "@"
    if (previousLength != currentLength && isCaretBeforeStartOfRange) {
      cancelMentionPage();
      return;
    }

    // handle cases where mention the filter is updated
    if (previousLength != currentLength) {
      final diff = currentLength - previousLength;
      final newEndPosition = inputControlCubit.filterEndPosition + diff;
      final newFilter = textController.text.substring(
        inputControlCubit.filterStartPosition,
        newEndPosition,
      );
      inputControlCubit.updateFilter(
        textController.text,
        newFilter,
        newEndPosition: newEndPosition,
      );
    } else if (!isTextSame) {
      final newFilter = textController.text.substring(
        inputControlCubit.filterStartPosition,
        inputControlCubit.filterEndPosition,
      );
      inputControlCubit.updateFilter(textController.text, newFilter);
    }
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    // if (event.character == '@') {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     inputControlCubit.startSearching(widget.textController.value);
    //     overlayController.show();
    //   });
    // }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      node.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void handlePageSelected(ViewPB view) {
    final newText = widget.textController.text.replaceRange(
      inputControlCubit.filterStartPosition,
      inputControlCubit.filterEndPosition,
      view.id,
    );
    widget.textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: inputControlCubit.filterStartPosition + view.id.length,
        affinity: TextAffinity.upstream,
      ),
    );

    inputControlCubit.selectPage(view);
    overlayController.hide();
  }

  Widget inputTextField() {
    return Shortcuts(
      shortcuts: buildShortcuts(),
      child: Actions(
        actions: buildActions(),
        child: CompositedTransformTarget(
          link: layerLink,
          child: BlocBuilder<AIPromptInputBloc, AIPromptInputState>(
            builder: (context, state) {
              Widget textField = PromptInputTextField(
                key: textFieldKey,
                editable: state.modelState.isEditable,
                cubit: inputControlCubit,
                textController: widget.textController,
                textFieldFocusNode: focusNode,
                contentPadding:
                    calculateContentPadding(state.showPredefinedFormats),
                hintText: state.modelState.hintText,
              );

              if (state.modelState.tooltip != null) {
                textField = FlowyTooltip(
                  message: state.modelState.tooltip!,
                  child: textField,
                );
              }

              return textField;
            },
          ),
        ),
      ),
    );
  }

  BoxConstraints getTextFieldConstraints(bool showPredefinedFormats) {
    double minHeight = DesktopAIPromptSizes.textFieldMinHeight +
        DesktopAIPromptSizes.actionBarSendButtonSize +
        DesktopAIChatSizes.inputActionBarMargin.vertical;
    double maxHeight = 300;
    if (showPredefinedFormats) {
      minHeight += DesktopAIPromptSizes.predefinedFormatButtonHeight;
      maxHeight += DesktopAIPromptSizes.predefinedFormatButtonHeight;
    }
    return BoxConstraints(minHeight: minHeight, maxHeight: maxHeight);
  }

  EdgeInsetsGeometry calculateContentPadding(bool showPredefinedFormats) {
    final top = showPredefinedFormats
        ? DesktopAIPromptSizes.predefinedFormatButtonHeight
        : 0.0;
    final bottom = DesktopAIPromptSizes.actionBarSendButtonSize +
        DesktopAIChatSizes.inputActionBarMargin.vertical;

    return DesktopAIPromptSizes.textFieldContentPadding
        .add(EdgeInsets.only(top: top, bottom: bottom));
  }

  Map<ShortcutActivator, Intent> buildShortcuts() {
    if (isComposing) {
      return const {};
    }

    return const {
      SingleActivator(LogicalKeyboardKey.arrowUp): _FocusPreviousItemIntent(),
      SingleActivator(LogicalKeyboardKey.arrowDown): _FocusNextItemIntent(),
      SingleActivator(LogicalKeyboardKey.escape): _CancelMentionPageIntent(),
      SingleActivator(LogicalKeyboardKey.enter): _SubmitOrMentionPageIntent(),
    };
  }

  Map<Type, Action<Intent>> buildActions() {
    return {
      _FocusPreviousItemIntent: CallbackAction<_FocusPreviousItemIntent>(
        onInvoke: (intent) {
          inputControlCubit.updateSelectionUp();
          return;
        },
      ),
      _FocusNextItemIntent: CallbackAction<_FocusNextItemIntent>(
        onInvoke: (intent) {
          inputControlCubit.updateSelectionDown();
          return;
        },
      ),
      _CancelMentionPageIntent: CallbackAction<_CancelMentionPageIntent>(
        onInvoke: (intent) {
          cancelMentionPage();
          return;
        },
      ),
      _SubmitOrMentionPageIntent: CallbackAction<_SubmitOrMentionPageIntent>(
        onInvoke: (intent) {
          if (overlayController.isShowing) {
            inputControlCubit.state.maybeWhen(
              ready: (visibleViews, focusedViewIndex) {
                if (focusedViewIndex != -1 &&
                    focusedViewIndex < visibleViews.length) {
                  handlePageSelected(visibleViews[focusedViewIndex]);
                }
              },
              orElse: () {},
            );
          } else {
            handleSend();
          }
          return;
        },
      ),
    };
  }

  /// 处理选择提示词
  /// 
  /// 功能：
  /// 1. 清空已提及的页面
  /// 2. 更新提示词ID
  /// 3. 替换输入框内容为提示词模板
  /// 4. 隐藏预定义格式栏（如果显示）
  void handleOnSelectPrompt(AiPrompt prompt) {
    final bloc = context.read<AIPromptInputBloc>();
    // 重置状态：清空提及页面，设置提示词ID
    bloc
      ..add(AIPromptInputEvent.updateMentionedViews([]))
      ..add(AIPromptInputEvent.updatePromptId(prompt.id));

    // 处理提示词内容中的特殊字符
    final content = AiPromptInputTextEditingController.replace(prompt.content);

    // 设置输入框内容，光标移到末尾
    widget.textController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(
        offset: content.length,
      ),
    );

    // 隐藏格式选择栏，避免与提示词冲突
    if (bloc.state.showPredefinedFormats) {
      bloc.add(
        AIPromptInputEvent.toggleShowPredefinedFormat(),
      );
    }
  }
}

/// 提交或选择提及页面的意图
/// Enter键触发：有@菜单时选择页面，否则发送消息
class _SubmitOrMentionPageIntent extends Intent {
  const _SubmitOrMentionPageIntent();
}

/// 取消@提及菜单的意图
/// Esc键触发
class _CancelMentionPageIntent extends Intent {
  const _CancelMentionPageIntent();
}

/// 聚焦上一个项目的意图
/// 上箭头键触发
class _FocusPreviousItemIntent extends Intent {
  const _FocusPreviousItemIntent();
}

/// 聚焦下一个项目的意图
/// 下箭头键触发
class _FocusNextItemIntent extends Intent {
  const _FocusNextItemIntent();
}

/// 提示词输入文本框组件
/// 
/// 功能：
/// 1. 多行文本输入
/// 2. 动态内边距（适应格式栏和操作栏）
/// 3. 可编辑状态控制
/// 4. 自定义提示文本
class PromptInputTextField extends StatelessWidget {
  const PromptInputTextField({
    super.key,
    required this.editable,
    required this.cubit,
    required this.textController,
    required this.textFieldFocusNode,
    required this.contentPadding,
    this.hintText = "",
  });

  /// 输入控制状态管理器
  final ChatInputControlCubit cubit;
  /// 文本控制器
  final TextEditingController textController;
  /// 焦点节点
  final FocusNode textFieldFocusNode;
  /// 内容内边距
  final EdgeInsetsGeometry contentPadding;
  /// 是否可编辑
  final bool editable;
  /// 提示文本
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return TextField(
      controller: textController,
      focusNode: textFieldFocusNode,
      readOnly: !editable,
      enabled: editable,
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: contentPadding,
        hintText: hintText,
        hintStyle: inputHintTextStyle(context),
        isCollapsed: true,
        isDense: true,
      ),
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      minLines: 1,
      maxLines: null,
      style: theme.textStyle.body.standard(
        color: theme.textColorScheme.primary,
      ),
    );
  }

  TextStyle? inputHintTextStyle(BuildContext context) {
    return AppFlowyTheme.of(context).textStyle.body.standard(
          color: Theme.of(context).isLightMode
              ? const Color(0xFFBDC2C8)
              : const Color(0xFF3C3E51),
        );
  }
}

/// 提示词输入框底部操作栏
/// 
/// 功能组件：
/// 1. 格式选择按钮
/// 2. 模型选择菜单
/// 3. 浏览提示词按钮
/// 4. 数据源选择按钮
/// 5. 文件附件按钮
/// 6. 发送/停止按钮
/// 
/// 布局：左侧功能按钮，右侧操作按钮
class _PromptBottomActions extends StatelessWidget {
  const _PromptBottomActions({
    required this.sendButtonState,
    required this.showPredefinedFormatBar,
    required this.showPredefinedFormatButton,
    required this.onTogglePredefinedFormatSection,
    required this.onStartMention,
    required this.onSendPressed,
    required this.onStopStreaming,
    required this.selectedSourcesNotifier,
    required this.onUpdateSelectedSources,
    required this.onSelectPrompt,
    this.extraBottomActionButton,
  });

  final bool showPredefinedFormatBar;
  final bool showPredefinedFormatButton;
  final void Function() onTogglePredefinedFormatSection;
  final void Function() onStartMention;
  final SendButtonState sendButtonState;
  final void Function() onSendPressed;
  final void Function() onStopStreaming;
  final ValueNotifier<List<String>> selectedSourcesNotifier;
  final void Function(List<String>) onUpdateSelectedSources;
  final void Function(AiPrompt) onSelectPrompt;
  final Widget? extraBottomActionButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesktopAIPromptSizes.actionBarSendButtonSize,
      margin: DesktopAIChatSizes.inputActionBarMargin,
      child: BlocBuilder<AIPromptInputBloc, AIPromptInputState>(
        builder: (context, state) {
          return Row(
            spacing: DesktopAIChatSizes.inputActionBarButtonSpacing,
            children: [
              if (showPredefinedFormatButton) _predefinedFormatButton(),
              _selectModelButton(context),
              _buildBrowsePromptsButton(),

              const Spacer(),

              if (context.read<ChatUserCubit>().supportSelectSource())
                _selectSourcesButton(),

              if (extraBottomActionButton != null) extraBottomActionButton!,
              // _mentionButton(context),
              if (state.supportChatWithFile) _attachmentButton(context),
              _sendButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _predefinedFormatButton() {
    return PromptInputDesktopToggleFormatButton(
      showFormatBar: showPredefinedFormatBar,
      onTap: onTogglePredefinedFormatSection,
    );
  }

  Widget _selectSourcesButton() {
    return PromptInputDesktopSelectSourcesButton(
      onUpdateSelectedSources: onUpdateSelectedSources,
      selectedSourcesNotifier: selectedSourcesNotifier,
    );
  }

  Widget _selectModelButton(BuildContext context) {
    return SelectModelMenu(
      aiModelStateNotifier:
          context.read<AIPromptInputBloc>().aiModelStateNotifier,
    );
  }

  Widget _buildBrowsePromptsButton() {
    return BrowsePromptsButton(
      onSelectPrompt: onSelectPrompt,
    );
  }

  // Widget _mentionButton(BuildContext context) {
  //   return PromptInputMentionButton(
  //     iconSize: DesktopAIPromptSizes.actionBarIconSize,
  //     buttonSize: DesktopAIPromptSizes.actionBarButtonSize,
  //     onTap: onStartMention,
  //   );
  // }

  /// 构建附件上传按钮
  /// 
  /// 支持上传PDF、TXT、MD格式文件
  Widget _attachmentButton(BuildContext context) {
    return PromptInputAttachmentButton(
      onTap: () async {
        // 打开文件选择器
        final path = await getIt<FilePickerService>().pickFiles(
          dialogTitle: '',
          type: FileType.custom,
          allowedExtensions: ["pdf", "txt", "md"],  // 支持的文件格式
        );

        if (path == null) {
          return;
        }

        // 添加选中的文件到状态中
        for (final file in path.files) {
          if (file.path != null && context.mounted) {
            context
                .read<AIPromptInputBloc>()
                .add(AIPromptInputEvent.attachFile(file.path!, file.name));
          }
        }
      },
    );
  }

  /// 构建发送按钮
  /// 
  /// 根据状态显示发送或停止图标
  Widget _sendButton() {
    return PromptInputSendButton(
      state: sendButtonState,
      onSendPressed: onSendPressed,
      onStopStreaming: onStopStreaming,
    );
  }
}
