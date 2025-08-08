import 'dart:ui' as ui;

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_configuration.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/background_color/theme_background_color.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/i18n/editor_i18n.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/plugins/document/presentation/editor_style.dart';
import 'package:appflowy/plugins/inline_actions/handlers/child_page.dart';
import 'package:appflowy/plugins/inline_actions/handlers/date_reference.dart';
import 'package:appflowy/plugins/inline_actions/handlers/inline_page_reference.dart';
import 'package:appflowy/plugins/inline_actions/handlers/reminder_reference.dart';
import 'package:appflowy/plugins/inline_actions/inline_actions_service.dart';
import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/shortcuts/settings_shortcuts_service.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/application/view_info/view_info_bloc.dart';
import 'package:appflowy/workspace/presentation/home/af_focus_manager.dart';
import 'package:appflowy_editor/appflowy_editor.dart' hide QuoteBlockKeys;
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import 'editor_plugins/desktop_toolbar/desktop_floating_toolbar.dart';
import 'editor_plugins/toolbar_item/custom_format_toolbar_items.dart';
import 'editor_plugins/toolbar_item/custom_hightlight_color_toolbar_item.dart';
import 'editor_plugins/toolbar_item/custom_link_toolbar_item.dart';
import 'editor_plugins/toolbar_item/custom_placeholder_toolbar_item.dart';
import 'editor_plugins/toolbar_item/custom_text_align_toolbar_item.dart';
import 'editor_plugins/toolbar_item/custom_text_color_toolbar_item.dart';
import 'editor_plugins/toolbar_item/more_option_toolbar_item.dart';
import 'editor_plugins/toolbar_item/text_heading_toolbar_item.dart';
import 'editor_plugins/toolbar_item/text_suggestions_toolbar_item.dart';

/// AppFlowy文档编辑器的包装器组件
/// 
/// 这是文档编辑功能的核心组件，负责：
/// 1. 集成AppFlowy Editor富文本编辑器
/// 2. 管理编辑器的状态和生命周期
/// 3. 提供工具栏、快捷键、插件等扩展功能
/// 4. 处理跨平台的编辑器适配（桌面端/移动端）
/// 
/// 架构设计：
/// - 采用装饰器模式包装原生的AppFlowyEditor
/// - 通过BLoC模式管理文档状态
/// - 支持插件化扩展（slash命令、行内操作等）
/// - 提供平台特定的工具栏实现
class AppFlowyEditorPage extends StatefulWidget {
  const AppFlowyEditorPage({
    super.key,
    required this.editorState,  // 编辑器状态，包含文档树和选区信息
    this.header,  // 编辑器顶部的自定义组件（如标题栏）
    this.shrinkWrap = false,  // 是否根据内容自适应高度
    this.scrollController,  // 外部提供的滚动控制器
    this.autoFocus,  // 是否自动获取焦点
    required this.styleCustomizer,  // 样式定制器，控制编辑器外观
    this.showParagraphPlaceholder,  // 是否显示段落占位符
    this.placeholderText,  // 自定义占位符文本生成函数
    this.initialSelection,  // 初始选区位置（用于定位跳转）
    this.useViewInfoBloc = true,  // 是否使用ViewInfoBloc管理编辑器状态
  });

  final Widget? header;  // 编辑器顶部组件
  final EditorState editorState;  // 核心编辑器状态对象
  final ScrollController? scrollController;  // 滚动控制器
  final bool shrinkWrap;  // 内容自适应高度标志
  final bool? autoFocus;  // 自动聚焦标志
  final EditorStyleCustomizer styleCustomizer;  // 样式定制器
  final ShowPlaceholder? showParagraphPlaceholder;  // 占位符显示控制函数
  final String Function(Node)? placeholderText;  // 占位符文本生成器

  /// 页面加载时的初始选区位置
  /// 用于实现跳转到特定位置的功能
  final Selection? initialSelection;

  /// 是否注册到ViewInfoBloc
  /// ViewInfoBloc用于管理编辑器实例，支持外部访问编辑器状态
  final bool useViewInfoBloc;

  @override
  State<AppFlowyEditorPage> createState() => _AppFlowyEditorPageState();
}

/// 编辑器页面的状态管理类
/// 
/// 职责：
/// 1. 管理编辑器的生命周期
/// 2. 处理键盘快捷键和字符输入
/// 3. 管理工具栏和上下文菜单
/// 4. 处理应用生命周期变化（如应用切换）
/// 5. 管理焦点和选区状态
class _AppFlowyEditorPageState extends State<AppFlowyEditorPage>
    with WidgetsBindingObserver {  // 混入WidgetsBindingObserver以监听应用生命周期
  /// 实际使用的滚动控制器
  /// 如果外部没有提供，则创建一个内部控制器
  late final ScrollController effectiveScrollController;

  /// 行内操作服务
  /// 负责处理@提及、日期引用、提醒等行内交互功能
  /// 
  /// 支持的功能：
  /// - 子页面提及（实验性功能）
  /// - 页面引用（@其他页面）
  /// - 日期引用（插入日期）
  /// - 提醒设置（创建提醒）
  late final InlineActionsService inlineActionsService = InlineActionsService(
    context: context,
    handlers: [
      // 子页面提及功能（通过特性开关控制）
      if (FeatureFlag.inlineSubPageMention.isOn)
        InlineChildPageService(currentViewId: documentBloc.documentId),
      // 页面引用功能
      InlinePageReferenceService(currentViewId: documentBloc.documentId),
      // 日期引用功能
      DateReferenceService(context),
      // 提醒功能
      ReminderReferenceService(context),
    ],
  );

  /// 命令快捷键列表
  /// 包含所有编辑器支持的键盘快捷键
  late final List<CommandShortcutEvent> commandShortcuts = [
    ...commandShortcutEvents,  // 基础快捷键（复制、粘贴、撤销等）
    ..._buildFindAndReplaceCommands(),  // 查找替换快捷键
  ];

  /// 工具栏项目配置
  /// 定义了浮动工具栏中显示的所有工具按钮
  /// 
  /// 工具栏布局：
  /// [AI改写] | [AI写作] [标题] | [格式化] | [颜色] | [高亮] [代码] [建议] [链接] | [对齐] [更多]
  final List<ToolbarItem> toolbarItems = [
    improveWritingItem,  // AI改写功能
    group0PaddingItem,  // 分组间距
    aiWriterItem,  // AI写作助手
    customTextHeadingItem,  // 标题级别选择
    buildPaddingPlaceholderItem(  // 动态间距
      1,
      isActive: onlyShowInSingleTextTypeSelectionAndExcludeTable,
    ),
    ...customMarkdownFormatItems,  // Markdown格式化（加粗、斜体、下划线等）
    group1PaddingItem,  // 分组间距
    customTextColorItem,  // 文字颜色
    group1PaddingItem,  // 分组间距
    customHighlightColorItem,  // 高亮背景色
    customInlineCodeItem,  // 行内代码
    suggestionsItem,  // AI建议
    customLinkItem,  // 超链接
    group4PaddingItem,  // 分组间距
    customTextAlignItem,  // 文本对齐
    moreOptionItem,  // 更多选项
  ];

  /// 字符快捷键事件列表
  /// 处理特殊字符输入触发的功能（如/命令、@提及等）
  List<CharacterShortcutEvent> get characterShortcutEvents {
    return buildCharacterShortcutEvents(
      context,
      documentBloc,
      styleCustomizer,
      inlineActionsService,
      (editorState, node) => _customSlashMenuItems(
        editorState: editorState,
        node: node,
      ),
    );
  }

  /// 获取样式定制器
  EditorStyleCustomizer get styleCustomizer => widget.styleCustomizer;

  /// 获取文档BLoC实例
  /// DocumentBloc管理文档的加载、保存、同步等核心逻辑
  DocumentBloc get documentBloc => context.read<DocumentBloc>();

  /// 编辑器专用滚动控制器
  /// 提供滚动到特定节点、监听滚动事件等功能
  late final EditorScrollController editorScrollController;

  /// 视图信息BLoC
  /// 管理当前视图的元数据和编辑器实例
  late final ViewInfoBloc viewInfoBloc = context.read<ViewInfoBloc>();

  /// 键盘拦截器
  /// 用于处理特殊的键盘输入场景
  final editorKeyboardInterceptor = EditorKeyboardInterceptor();

  /// 显示斜杠命令菜单
  /// 当用户输入/时触发，显示可插入的块类型列表
  Future<bool> showSlashMenu(editorState) async => customSlashCommand(
        _customSlashMenuItems(),
        shouldInsertSlash: false,
        style: styleCustomizer.selectionMenuStyleBuilder(),
        supportSlashMenuNodeTypes: supportSlashMenuNodeTypes,
      ).handler(editorState);

  /// AppFlowy自定义焦点管理器
  /// 处理编辑器的焦点获取和失去
  AFFocusManager? focusManager;

  /// 应用生命周期状态
  /// 用于处理应用切换时的选区恢复
  AppLifecycleState? lifecycleState = WidgetsBinding.instance.lifecycleState;
  
  /// 历史选区记录
  /// 用于应用恢复时恢复之前的选区
  List<Selection?> previousSelections = [];

  @override
  void initState() {
    super.initState();
    // 注册为应用生命周期观察者
    WidgetsBinding.instance.addObserver(this);

    // 将编辑器状态注册到ViewInfoBloc
    // 这样其他组件可以通过ViewInfoBloc访问编辑器
    if (widget.useViewInfoBloc) {
      viewInfoBloc.add(
        ViewInfoEvent.registerEditorState(editorState: widget.editorState),
      );
    }

    // 初始化编辑器国际化
    _initEditorL10n();
    // 初始化快捷键配置
    _initializeShortcuts();

    // 配置部分切片支持的富文本键
    // 这些键的内容在复制粘贴时会被部分保留
    AppFlowyRichTextKeys.partialSliced.addAll([
      MentionBlockKeys.mention,  // @提及
      InlineMathEquationKeys.formula,  // 数学公式
    ]);

    // 配置可缩进的块类型
    // 这些块类型支持Tab/Shift+Tab进行缩进
    indentableBlockTypes.addAll([
      ToggleListBlockKeys.type,  // 折叠列表
      CalloutBlockKeys.type,  // 标注块
      QuoteBlockKeys.type,  // 引用块
    ]);
    // 配置可转换的块类型
    // 这些块类型可以通过快捷键相互转换
    convertibleBlockTypes.addAll([
      ToggleListBlockKeys.type,  // 折叠列表
      CalloutBlockKeys.type,  // 标注块
      QuoteBlockKeys.type,  // 引用块
    ]);

    // 配置URL启动处理器
    // 当用户点击链接时，使用系统默认浏览器打开
    editorLaunchUrl = (url) {
      if (url != null) {
        afLaunchUrlString(url, addingHttpSchemeWhenFailed: true);
      }

      return Future.value(true);
    };

    // 设置滚动控制器
    effectiveScrollController = widget.scrollController ?? ScrollController();
    // 禁用HTML解码器中的颜色解析
    // AppFlowy使用自定义的颜色系统
    DocumentHTMLDecoder.enableColorParse = false;

    // 创建编辑器专用滚动控制器
    // 处理滚动到特定节点、虚拟滚动等功能
    editorScrollController = EditorScrollController(
      editorState: widget.editorState,
      shrinkWrap: widget.shrinkWrap,
      scrollController: effectiveScrollController,
    );

    // 配置工具栏白名单
    // 这些块类型中可以显示工具栏
    toolbarItemWhiteList.addAll([
      ToggleListBlockKeys.type,  // 折叠列表
      CalloutBlockKeys.type,  // 标注块
      TableBlockKeys.type,  // 表格
      SimpleTableBlockKeys.type,  // 简单表格
      SimpleTableCellBlockKeys.type,  // 表格单元格
      SimpleTableRowBlockKeys.type,  // 表格行
    ]);
    // 添加字体族到支持切片的富文本键
    AppFlowyRichTextKeys.supportSliced.add(AppFlowyRichTextKeys.fontFamily);

    // 自定义动态主题颜色装饰器
    // 用于根据主题设置块组件的背景色
    _customizeBlockComponentBackgroundColorDecorator();

    // 监听选区变化
    // 用于记录选区历史，支持应用切换后恢复
    widget.editorState.selectionNotifier.addListener(onSelectionChanged);

    // 在第一帧渲染后执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      // 获取焦点管理器并监听失焦事件
      focusManager = AFFocusManager.maybeOf(context);
      focusManager?.loseFocusNotifier.addListener(_loseFocus);

      // 如果有初始选区，滚动到对应位置
      _scrollToSelectionIfNeeded();

      // 注册键盘拦截器
      widget.editorState.service.keyboardService?.registerInterceptor(
        editorKeyboardInterceptor,
      );
    });
  }

  /// 滚动到初始选区位置
  /// 用于实现跳转到特定位置的功能（如搜索结果定位）
  void _scrollToSelectionIfNeeded() {
    final initialSelection = widget.initialSelection;
    final path = initialSelection?.start.path;
    if (path == null) {
      return;
    }

    // 桌面端使用jumpTo立即跳转到选区
    // 移动端使用scrollTo平滑滚动，避免破坏滚动通知指标
    if (UniversalPlatform.isDesktop) {
      editorScrollController.itemScrollController.jumpTo(
        index: path.first,
        alignment: 0.5,
      );
      widget.editorState.updateSelectionWithReason(
        initialSelection,
      );
    } else {
      const delayDuration = Duration(milliseconds: 250);
      const animationDuration = Duration(milliseconds: 400);
      Future.delayed(delayDuration, () {
        editorScrollController.itemScrollController.scrollTo(
          index: path.first,
          duration: animationDuration,
          curve: Curves.easeInOut,
        );
        widget.editorState.updateSelectionWithReason(
          initialSelection,
          extraInfo: {
            selectionExtraInfoDoNotAttachTextService: true,
            selectionExtraInfoDisableMobileToolbarKey: true,
          },
        );
      }).then((_) {
        Future.delayed(animationDuration, () {
          widget.editorState.selectionType = SelectionType.inline;
          widget.editorState.selectionExtraInfo = null;
        });
      });
    }
  }

  /// 选区变化回调
  /// 记录最近的两个选区，用于应用恢复时使用
  void onSelectionChanged() {
    if (widget.editorState.isDisposed) {
      return;
    }

    // 记录选区历史
    previousSelections.add(widget.editorState.selection);

    // 只保留最近两个选区
    if (previousSelections.length > 2) {
      previousSelections.removeAt(0);
    }
  }

  /// 应用生命周期变化回调
  /// 处理应用切换时的选区恢复
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    lifecycleState = state;

    if (widget.editorState.isDisposed) {
      return;
    }

    // 应用恢复时，如果选区丢失，恢复之前的选区
    if (previousSelections.length == 2 &&
        state == AppLifecycleState.resumed &&
        widget.editorState.selection == null) {
      widget.editorState.selection = previousSelections.first;
    }
  }

  /// 依赖变化回调
  /// 更新焦点管理器引用
  @override
  void didChangeDependencies() {
    final currFocusManager = AFFocusManager.maybeOf(context);
    if (focusManager != currFocusManager) {
      // 移除旧的监听器
      focusManager?.loseFocusNotifier.removeListener(_loseFocus);
      // 更新焦点管理器
      focusManager = currFocusManager;
      // 添加新的监听器
      focusManager?.loseFocusNotifier.addListener(_loseFocus);
    }

    super.didChangeDependencies();
  }

  /// 清理资源
  @override
  void dispose() {
    // 移除选区监听器
    widget.editorState.selectionNotifier.removeListener(onSelectionChanged);
    // 注销键盘拦截器
    widget.editorState.service.keyboardService?.unregisterInterceptor(
      editorKeyboardInterceptor,
    );
    // 移除焦点监听器
    focusManager?.loseFocusNotifier.removeListener(_loseFocus);

    // 从ViewInfoBloc注销编辑器状态
    if (widget.useViewInfoBloc && !viewInfoBloc.isClosed) {
      viewInfoBloc.add(const ViewInfoEvent.unregisterEditorState());
    }

    // 隐藏键盘
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // 清理滚动控制器（只清理内部创建的）
    if (widget.scrollController == null) {
      effectiveScrollController.dispose();
    }
    // 清理服务
    inlineActionsService.dispose();
    editorScrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 计算自动聚焦参数
    final (bool autoFocus, Selection? selection) =
        _computeAutoFocusParameters();

    // 检查是否为RTL（从右到左）布局
    final isRTL =
        context.read<AppearanceSettingsCubit>().state.layoutDirection ==
            LayoutDirection.rtlLayout;
    final textDirection = isRTL ? ui.TextDirection.rtl : ui.TextDirection.ltr;

    // 根据设置决定是否显示RTL工具栏项
    _setRTLToolbarItems(
      context.read<AppearanceSettingsCubit>().state.enableRtlToolbarItems,
    );

    // 检查文档状态
    final isViewDeleted = context.read<DocumentBloc>().state.isDeleted;  // 文档是否已删除
    final isEditable =
        context.read<PageAccessLevelBloc?>()?.state.isEditable ?? true;  // 用户是否有编辑权限

    // 构建核心编辑器组件
    final editor = Directionality(
      textDirection: textDirection,
      child: AppFlowyEditor(
        editorState: widget.editorState,
        editable: !isViewDeleted && isEditable,  // 只有文档未删除且有权限时才可编辑
        disableSelectionService: UniversalPlatform.isMobile && !isEditable,  // 移动端只读时禁用选择
        disableKeyboardService: UniversalPlatform.isMobile && !isEditable,  // 移动端只读时禁用键盘
        editorScrollController: editorScrollController,
        // 设置自动聚焦参数
        autoFocus: widget.autoFocus ?? autoFocus,
        focusedSelection: selection,
        // 设置编辑器主题样式
        editorStyle: styleCustomizer.style(),
        // 自定义块组件构建器
        // 为不同类型的块提供自定义渲染
        blockComponentBuilders: buildBlockComponentBuilders(
          slashMenuItemsBuilder: (editorState, node) => _customSlashMenuItems(
            editorState: editorState,
            node: node,
          ),
          context: context,
          editorState: widget.editorState,
          styleCustomizer: widget.styleCustomizer,
          showParagraphPlaceholder: widget.showParagraphPlaceholder,
          placeholderText: widget.placeholderText,
        ),
        // 自定义快捷键
        characterShortcutEvents: characterShortcutEvents,  // 字符触发的快捷键（如/命令）
        commandShortcutEvents: commandShortcuts,  // 组合键快捷键（如Ctrl+B）
        // 自定义右键菜单项
        contextMenuItems: customContextMenuItems,
        // 自定义头部和底部
        header: widget.header,
        // 自动滚动边缘偏移量
        // 当光标接近边缘时触发自动滚动
        autoScrollEdgeOffset: UniversalPlatform.isDesktopOrWeb
            ? 250
            : appFlowyEditorAutoScrollEdgeOffset,
        // 底部点击区域
        // 点击底部空白区域时，在末尾添加新段落
        footer: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            // 如果最后一个节点不是空段落，插入一个新的空段落
            await _focusOnLastEmptyParagraph();
          },
          child: SizedBox(
            width: double.infinity,
            height: UniversalPlatform.isDesktopOrWeb ? 600 : 400,  // 底部留白高度
          ),
        ),
        // 拖放目标样式
        // 定义拖放时的指示器样式
        dropTargetStyle: AppFlowyDropTargetStyle(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          margin: const EdgeInsets.only(left: 44),  // 左侧缩进对齐块内容
        ),
      ),
    );

    // 如果文档已删除，直接返回只读编辑器
    if (isViewDeleted) {
      return editor;
    }

    final editorState = widget.editorState;

    // 移动端：添加移动端工具栏
    if (UniversalPlatform.isMobile) {
      return AppFlowyMobileToolbar(
        toolbarHeight: 42.0,
        editorState: editorState,
        toolbarItemsBuilder: (sel) => buildMobileToolbarItems(editorState, sel),
        child: MobileFloatingToolbar(
          editorState: editorState,
          editorScrollController: editorScrollController,
          toolbarBuilder: (_, anchor, closeToolbar) =>
              CustomMobileFloatingToolbar(
            editorState: editorState,
            anchor: anchor,
            closeToolbar: closeToolbar,
          ),
          floatingToolbarHeight: 32,
          child: editor,
        ),
      );
    }
    final appTheme = AppFlowyTheme.of(context);
    // 桌面端：添加浮动工具栏
    return Center(
      child: BlocProvider.value(
        value: context.read<DocumentBloc>(),
        child: FloatingToolbar(
          floatingToolbarHeight: 40,
          padding: EdgeInsets.symmetric(horizontal: 6),
          style: FloatingToolbarStyle(
            backgroundColor: Theme.of(context).cardColor,
            toolbarActiveColor: Color(0xffe0f8fd),
          ),
          items: toolbarItems,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(appTheme.borderRadius.l),
            color: appTheme.surfaceColorScheme.primary,
            boxShadow: appTheme.shadow.small,
          ),
          toolbarBuilder: (_, child, onDismiss, isMetricsChanged) =>
              BlocProvider.value(
            value: context.read<DocumentBloc>(),
            child: DesktopFloatingToolbar(
              editorState: editorState,
              onDismiss: onDismiss,
              enableAnimation: !isMetricsChanged,
              child: child,
            ),
          ),
          placeHolderBuilder: (_) => customPlaceholderItem,
          editorState: editorState,
          editorScrollController: editorScrollController,
          textDirection: textDirection,
          tooltipBuilder: (context, id, message, child) =>
              widget.styleCustomizer.buildToolbarItemTooltip(
            context,
            id,
            message,
            child,
          ),
          child: editor,
        ),
      ),
    );
  }

  /// 构建自定义的斜杠命令菜单项
  /// 根据当前上下文和文档状态返回可用的命令
  List<SelectionMenuItem> _customSlashMenuItems({
    EditorState? editorState,
    Node? node,
  }) {
    final documentBloc = context.read<DocumentBloc>();
    final isLocalMode = documentBloc.isLocalMode;
    final view = context.read<ViewBloc>().state.view;
    return slashMenuItemsBuilder(
      editorState: editorState,
      node: node,
      isLocalMode: isLocalMode,
      documentBloc: documentBloc,
      view: view,
    );
  }

  /// 计算自动聚焦参数
  /// 如果文档为空，自动聚焦到第一个段落
  (bool, Selection?) _computeAutoFocusParameters() {
    if (widget.editorState.document.isEmpty) {
      return (true, Selection.collapsed(Position(path: [0])));
    }
    return const (false, null);
  }

  /// 初始化快捷键配置
  /// 加载用户自定义的快捷键设置
  Future<void> _initializeShortcuts() async {
    defaultCommandShortcutEvents;
    final settingsShortcutService = SettingsShortcutService();
    final customizeShortcuts =
        await settingsShortcutService.getCustomizeShortcuts();
    await settingsShortcutService.updateCommandShortcuts(
      commandShortcuts,
      customizeShortcuts,
    );
  }

  /// 设置RTL工具栏项
  /// 根据配置决定是否显示文本方向切换按钮
  void _setRTLToolbarItems(bool enableRtlToolbarItems) {
    final textDirectionItemIds = textDirectionItems.map((e) => e.id);
    // clear all the text direction items
    toolbarItems.removeWhere((item) => textDirectionItemIds.contains(item.id));
    // only show the rtl item when the layout direction is ltr.
    if (enableRtlToolbarItems) {
      toolbarItems.addAll(textDirectionItems);
    }
  }

  /// 构建查找和替换命令
  /// 返回Ctrl+F查找和Ctrl+H替换的快捷键事件
  List<CommandShortcutEvent> _buildFindAndReplaceCommands() {
    return findAndReplaceCommands(
      context: context,
      style: FindReplaceStyle(
        findMenuBuilder: (
          context,
          editorState,
          localizations,
          style,
          showReplaceMenu,
          onDismiss,
        ) =>
            Material(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FindAndReplaceMenuWidget(
              showReplaceMenu: showReplaceMenu,
              editorState: editorState,
              onDismiss: onDismiss,
            ),
          ),
        ),
      ),
    );
  }

  /// 自定义块组件背景色装饰器
  /// 根据主题和颜色字符串返回实际的颜色值
  void _customizeBlockComponentBackgroundColorDecorator() {
    blockComponentBackgroundColorDecorator = (Node node, String colorString) {
      if (mounted && context.mounted) {
        return buildEditorCustomizedColor(context, node, colorString);
      }
      return null;
    };
  }

  /// 初始化编辑器国际化
  /// 设置编辑器的多语言支持
  void _initEditorL10n() => AppFlowyEditorL10n.current = EditorI18n();

  /// 聚焦到最后一个空段落
  /// 如果最后不是空段落，则创建一个新的空段落
  Future<void> _focusOnLastEmptyParagraph() async {
    final editorState = widget.editorState;
    final root = editorState.document.root;
    final lastNode = root.children.lastOrNull;
    final transaction = editorState.transaction;
    if (lastNode == null ||
        lastNode.delta?.isEmpty == false ||
        lastNode.type != ParagraphBlockKeys.type) {
      transaction.insertNode([root.children.length], paragraphNode());
      transaction.afterSelection = Selection.collapsed(
        Position(path: [root.children.length]),
      );
    } else {
      transaction.afterSelection = Selection.collapsed(
        Position(path: lastNode.path),
      );
    }

    transaction.customSelectionType = SelectionType.inline;
    transaction.reason = SelectionUpdateReason.uiEvent;

    await editorState.apply(transaction);
  }

  /// 失去焦点时的处理
  /// 清除选区状态
  void _loseFocus() {
    if (!widget.editorState.isDisposed) {
      widget.editorState.selection = null;
    }
  }
}

/// 构建编辑器自定义颜色
/// 
/// 颜色来源优先级：
/// 1. FlowyTint预定义颜色
/// 2. 主题背景色
/// 3. 特殊默认色（如标注块、表格单元格）
/// 4. 颜色字符串解析
Color? buildEditorCustomizedColor(
  BuildContext context,
  Node node,
  String colorString,
) {
  if (!context.mounted) {
    return null;
  }

  // 尝试从FlowyTint预定义颜色中查找
  final tintColor = FlowyTint.values.firstWhereOrNull(
    (e) => e.id == colorString,
  );
  if (tintColor != null) {
    return tintColor.color(context);
  }

  // 尝试从主题背景色中查找
  final themeColor = themeBackgroundColors[colorString];
  if (themeColor != null) {
    return themeColor.color(context);
  }

  // 处理默认颜色
  if (colorString == optionActionColorDefaultColor) {
    // 标注块使用特定背景色，其他使用透明
    final defaultColor = node.type == CalloutBlockKeys.type
        ? AFThemeExtension.of(context).calloutBGColor
        : Colors.transparent;
    return defaultColor;
  }

  // 表格单元格默认颜色
  if (colorString == tableCellDefaultColor) {
    return AFThemeExtension.of(context).tableCellBGColor;
  }

  // 尝试将字符串解析为颜色
  try {
    return colorString.tryToColor();
  } catch (e) {
    return null;
  }
}

/// 检查是否在任何文本类型中显示工具栏
/// 用于决定工具栏项的可见性
bool showInAnyTextType(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return false;
  }

  final nodes = editorState.getNodesInSelection(selection);
  return nodes.any((node) => toolbarItemWhiteList.contains(node.type));
}
