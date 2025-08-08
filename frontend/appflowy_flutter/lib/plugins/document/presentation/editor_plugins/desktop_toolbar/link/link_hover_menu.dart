import 'dart:math';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/clipboard_service.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/desktop_toolbar/desktop_floating_toolbar.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/link_embed/link_embed_block_component.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/link_preview/shared.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_page_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mobile_toolbar_v3/link_toolbar_item.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/toolbar_item/custom_link_toolbar_item.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_plugins/appflowy_editor_plugins.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import 'link_create_menu.dart';
import 'link_edit_menu.dart';
import 'link_extension.dart';

class LinkHoverTrigger extends StatefulWidget {
  const LinkHoverTrigger({
    super.key,
    required this.editorState,
    required this.selection,
    required this.node,
    required this.attribute,
    required this.size,
    this.delayToShow = const Duration(milliseconds: 50),
    this.delayToHide = const Duration(milliseconds: 300),
  });

  final EditorState editorState;
  final Selection selection;
  final Node node;
  final Attributes attribute;
  final Size size;
  final Duration delayToShow;
  final Duration delayToHide;

  @override
  State<LinkHoverTrigger> createState() => _LinkHoverTriggerState();
}

class _LinkHoverTriggerState extends State<LinkHoverTrigger> {
  final hoverMenuController = PopoverController();
  final editMenuController = PopoverController();
  final toolbarController = getIt<FloatingToolbarController>();
  bool isHoverMenuShowing = false;
  bool isHoverMenuHovering = false;
  bool isHoverTriggerHovering = false;

  Size get size => widget.size;

  EditorState get editorState => widget.editorState;

  Selection get selection => widget.selection;

  Attributes get attribute => widget.attribute;

  /// 触发器唯一标识
  /// 用于在全局注册表中标识此链接
  late HoverTriggerKey triggerKey = HoverTriggerKey(widget.node.id, selection);

  @override
  void initState() {
    super.initState();
    // 注册到全局链接触发器管理器
    // 这样其他地方可以通过key触发显示此链接的菜单
    getIt<LinkHoverTriggers>()._add(triggerKey, showLinkHoverMenu);
    // 监听工具栏显示事件，工具栏显示时自动隐藏链接菜单
    toolbarController.addDisplayListener(onToolbarShow);
  }

  @override
  void dispose() {
    hoverMenuController.close();
    editMenuController.close();
    // 从全局注册表移除，避免内存泄漏
    getIt<LinkHoverTriggers>()._remove(triggerKey, showLinkHoverMenu);
    toolbarController.removeDisplayListener(onToolbarShow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 创建一个几乎透明的占位符，覆盖在链接文本上
    // 用于捕获鼠标事件
    final placeHolder = Container(
      color: Colors.black.withAlpha(1),  // 几乎透明，但可以接收事件
      width: size.width,
      height: size.height,
    );
    
    // 移动端处理：点击打开链接，长按编辑
    if (UniversalPlatform.isMobile) {
      return GestureDetector(
        onTap: openLink,
        onLongPress: () async {
          await showEditLinkBottomSheet(context, selection, editorState);
        },
        child: placeHolder,
      );
    }
    
    // 桌面端处理：鼠标悬停显示菜单
    return MouseRegion(
      cursor: SystemMouseCursors.click,  // 鼠标指针变为手型
      onEnter: (v) {
        // 鼠标进入链接区域
        isHoverTriggerHovering = true;
        // 延迟显示，避免快速移动鼠标时误触发
        Future.delayed(widget.delayToShow, () {
          // 检查鼠标仍在链接上且菜单未显示
          if (isHoverTriggerHovering && !isHoverMenuShowing) {
            showLinkHoverMenu();
          }
        });
      },
      onExit: (v) {
        // 鼠标离开链接区域
        isHoverTriggerHovering = false;
        // 尝试关闭菜单（如果鼠标不在菜单上）
        tryToDismissLinkHoverMenu();
      },
      // 嵌套两个Popover：悬停菜单和编辑菜单
      child: buildHoverPopover(buildEditPopover(placeHolder)),
    );
  }

  /// 构建悬停弹出菜单
  /// 
  /// 包装子组件，添加悬停菜单功能。
  /// 当鼠标悬停时显示LinkHoverMenu。
  Widget buildHoverPopover(Widget child) {
    return AppFlowyPopover(
      controller: hoverMenuController,
      direction: PopoverDirection.topWithLeftAligned,
      offset: Offset(0, size.height),
      onOpen: () {
        // 增加焦点保持计数，防止编辑器因为点击菜单而失去焦点
        keepEditorFocusNotifier.increase();
        isHoverMenuShowing = true;
      },
      onClose: () {
        // 减少焦点保持计数
        keepEditorFocusNotifier.decrease();
        isHoverMenuShowing = false;
      },
      margin: EdgeInsets.zero,
      constraints: BoxConstraints(
        maxWidth: max(320, size.width),
        maxHeight: 48 + size.height,
      ),
      decorationColor: Colors.transparent,
      popoverDecoration: BoxDecoration(),
      popupBuilder: (context) => LinkHoverMenu(
        attribute: widget.attribute,
        triggerSize: size,
        editable: editorState.editable,
        onEnter: (_) {
          isHoverMenuHovering = true;
        },
        onExit: (_) {
          isHoverMenuHovering = false;
          tryToDismissLinkHoverMenu();
        },
        onConvertTo: (type) => convertLinkTo(editorState, selection, type),
        onOpenLink: openLink,
        onCopyLink: () => copyLink(context),
        onEditLink: showLinkEditMenu,
        onRemoveLink: () => editorState.removeLink(selection),
      ),
      child: child,
    );
  }

  /// 构建编辑弹出菜单
  /// 
  /// 包装子组件，添加编辑菜单功能。
  /// 点击编辑按钮时显示LinkEditMenu。
  Widget buildEditPopover(Widget child) {
    final href = attribute.href ?? '',
        isPage = attribute.isPage,
        title = editorState.getTextInSelection(selection).join();
    final currentViewId = context.read<DocumentBloc?>()?.documentId ?? '';
    return AppFlowyPopover(
      controller: editMenuController,
      direction: PopoverDirection.bottomWithLeftAligned,
      offset: Offset(0, 0),
      onOpen: () => keepEditorFocusNotifier.increase(),
      onClose: () => keepEditorFocusNotifier.decrease(),
      margin: EdgeInsets.zero,
      asBarrier: true,
      decorationColor: Colors.transparent,
      popoverDecoration: BoxDecoration(),
      constraints: BoxConstraints(
        maxWidth: 400,
        minHeight: 282,
      ),
      popupBuilder: (context) => LinkEditMenu(
        currentViewId: currentViewId,
        linkInfo: LinkInfo(name: title, link: href, isPage: isPage),
        onDismiss: () => editMenuController.close(),
        onApply: (info) => editorState.applyLink(selection, info),
        onRemoveLink: (linkinfo) {
          final replaceText =
              linkinfo.name.isEmpty ? linkinfo.link : linkinfo.name;
          onRemoveAndReplaceLink(editorState, selection, replaceText);
        },
      ),
      child: child,
    );
  }

  /// 工具栏显示时的回调
  /// 
  /// 当浮动工具栏显示时，关闭链接悬停菜单，
  /// 避免多个浮动UI重叠。
  void onToolbarShow() => hoverMenuController.close();

  /// 显示链接悬停菜单
  /// 
  /// 检查各种条件，确保可以安全显示菜单。
  /// 增加焦点保持计数，防止编辑器失去焦点。
  void showLinkHoverMenu() {
    // 检查多个条件，任一不满足就不显示
    if (UniversalPlatform.isMobile ||      // 移动端不支持悬停
        isHoverMenuShowing ||               // 已经在显示
        toolbarController.isToolbarShowing || // 其他工具栏在显示
        !mounted) {                        // 组件已销毁
      return;
    }
    keepEditorFocusNotifier.increase();
    hoverMenuController.show();
  }

  /// 显示链接编辑菜单
  /// 
  /// 关闭悬停菜单，显示编辑菜单。
  /// 保持编辑器焦点。
  void showLinkEditMenu() {
    if (UniversalPlatform.isMobile) return;
    keepEditorFocusNotifier.increase();
    hoverMenuController.close();
    editMenuController.show();
  }

  /// 尝试关闭链接悬停菜单
  /// 
  /// 延迟检查鼠标是否真的离开了链接和菜单区域。
  /// 如果鼠标在菜单上，不关闭菜单。
  void tryToDismissLinkHoverMenu() {
    Future.delayed(widget.delayToHide, () {
      if (isHoverMenuHovering || isHoverTriggerHovering) {
        return;
      }
      hoverMenuController.close();
    });
  }

  /// 打开链接
  /// 
  /// 根据链接类型执行不同操作：
  /// - 页面链接：导航到对应页面
  /// - 外部链接：在浏览器中打开
  Future<void> openLink() async {
    final href = widget.attribute.href ?? '', isPage = widget.attribute.isPage;

    if (isPage) {
      // 页面链接格式: pageId/viewId
      final viewId = href.split('/').lastOrNull ?? '';
      if (viewId.isEmpty) {
        // 格式不正确，当作普通链接处理
        await afLaunchUrlString(href, addingHttpSchemeWhenFailed: true);
      } else {
        // 获取页面状态（是否在垃圾桶、是否已删除）
        final (view, isInTrash, isDeleted) =
            await ViewBackendService.getMentionPageStatus(viewId);
        if (view != null) {
          // 导航到对应页面
          await handleMentionBlockTap(context, widget.editorState, view);
        }
      }
    } else {
      // 外部链接，在浏览器中打开
      await afLaunchUrlString(href, addingHttpSchemeWhenFailed: true);
    }
  }

  /// 复制链接到剪贴板
  /// 
  /// 复制链接地址并显示成功提示。
  Future<void> copyLink(BuildContext context) async {
    final href = widget.attribute.href ?? '';
    await context.copyLink(href);
    hoverMenuController.close();
  }

  /// 转换链接类型
  /// 
  /// 将链接转换为其他形式：
  /// - 书签：显示预览卡片
  /// - @提及：引用页面
  /// - 嵌入：嵌入网页内容
  Future<void> convertLinkTo(
    EditorState editorState,
    Selection selection,
    LinkConvertMenuCommand type,
  ) async {
    final url = widget.attribute.href ?? '';
    if (type == LinkConvertMenuCommand.toBookmark) {
      await convertUrlToLinkPreview(editorState, selection, url);
    } else if (type == LinkConvertMenuCommand.toMention) {
      await convertUrlToMention(editorState, selection);
    } else if (type == LinkConvertMenuCommand.toEmbed) {
      await convertUrlToLinkPreview(
        editorState,
        selection,
        url,
        previewType: LinkEmbedKeys.embed,
      );
    }
  }

  /// 移除链接并替换为纯文本
  /// 
  /// 保留文本内容，移除链接格式。
  void onRemoveAndReplaceLink(
    EditorState editorState,
    Selection selection,
    String text,
  ) {
    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null) {
      return;
    }
    final index = selection.normalized.startIndex;
    final length = selection.length;
    // 创建事务，替换文本并移除链接属性
    final transaction = editorState.transaction
      ..replaceText(
        node,
        index,
        length,
        text,
        attributes: {
          BuiltInAttributeKey.href: null,  // 移除链接地址
          kIsPageLink: null,                // 移除页面链接标记
        },
      );
    editorState.apply(transaction);
  }
}

class LinkHoverMenu extends StatefulWidget {
  const LinkHoverMenu({
    super.key,
    required this.attribute,
    required this.onEnter,
    required this.onExit,
    required this.editable,
    required this.triggerSize,
    required this.onCopyLink,
    required this.onOpenLink,
    required this.onEditLink,
    required this.onRemoveLink,
    required this.onConvertTo,
  });

  final Attributes attribute;
  final PointerEnterEventListener onEnter;
  final PointerExitEventListener onExit;
  final Size triggerSize;
  final VoidCallback onCopyLink;
  final VoidCallback onOpenLink;
  final VoidCallback onEditLink;
  final VoidCallback onRemoveLink;
  final bool editable;
  final ValueChanged<LinkConvertMenuCommand> onConvertTo;

  @override
  State<LinkHoverMenu> createState() => _LinkHoverMenuState();
}

class _LinkHoverMenuState extends State<LinkHoverMenu> {
  ViewPB? currentView;
  late bool isPage = widget.attribute.isPage;
  late String href = widget.attribute.href ?? '';
  final popoverController = PopoverController();
  bool isConvertButtonSelected = false;

  bool get editable => widget.editable;

  @override
  void initState() {
    super.initState();
    if (isPage) getPageView();
  }

  @override
  void dispose() {
    super.dispose();
    popoverController.close();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: widget.onEnter,
          onExit: widget.onExit,
          child: SizedBox(
            width: max(320, widget.triggerSize.width),
            height: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 320,
                height: 48,
                decoration: buildToolbarLinkDecoration(context),
                padding: EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: buildLinkWidget()),
                    Container(
                      height: 20,
                      width: 1,
                      color: Color(0xffE8ECF3)
                          .withAlpha(Theme.of(context).isLightMode ? 255 : 40),
                      margin: EdgeInsets.symmetric(horizontal: 6),
                    ),
                    FlowyIconButton(
                      icon: FlowySvg(FlowySvgs.toolbar_link_m),
                      tooltipText: LocaleKeys.editor_copyLink.tr(),
                      preferBelow: false,
                      width: 36,
                      height: 32,
                      onPressed: widget.onCopyLink,
                    ),
                    FlowyIconButton(
                      icon: FlowySvg(FlowySvgs.toolbar_link_edit_m),
                      tooltipText: LocaleKeys.editor_editLink.tr(),
                      hoverColor: hoverColor,
                      preferBelow: false,
                      width: 36,
                      height: 32,
                      onPressed: getTapCallback(widget.onEditLink),
                    ),
                    buildConvertButton(),
                    FlowyIconButton(
                      icon: FlowySvg(FlowySvgs.toolbar_link_unlink_m),
                      tooltipText: LocaleKeys.editor_removeLink.tr(),
                      hoverColor: hoverColor,
                      preferBelow: false,
                      width: 36,
                      height: 32,
                      onPressed: getTapCallback(widget.onRemoveLink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: widget.onEnter,
          onExit: widget.onExit,
          child: GestureDetector(
            onTap: widget.onOpenLink,
            child: Container(
              width: widget.triggerSize.width,
              height: widget.triggerSize.height,
              color: Colors.black.withAlpha(1),
            ),
          ),
        ),
      ],
    );
  }

  /// 获取页面视图信息
  /// 
  /// 异步加载链接指向的页面信息，
  /// 用于显示页面标题而不是URL。
  Future<void> getPageView() async {
    final viewId = href.split('/').lastOrNull ?? '';
    final (view, isInTrash, isDeleted) =
        await ViewBackendService.getMentionPageStatus(viewId);
    if (mounted) {
      setState(() {
        currentView = view;
      });
    }
  }

  /// 构建链接显示组件
  /// 
  /// 根据链接类型显示不同内容：
  /// - 页面链接：显示页面标题
  /// - 外部链接：显示URL
  /// - 加载中：显示进度指示器
  Widget buildLinkWidget() {
    final view = currentView;
    if (isPage && view == null) {
      return SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(),
      );
    }
    String text = '';
    if (isPage && view != null) {
      text = view.name;
      if (text.isEmpty) {
        text = LocaleKeys.document_title_placeholder.tr();
      }
    } else {
      text = href;
    }
    return FlowyTooltip(
      message: text,
      preferBelow: false,
      child: FlowyText.regular(
        text,
        overflow: TextOverflow.ellipsis,
        figmaLineHeight: 20,
        fontSize: 14,
      ),
    );
  }

  /// 构建转换按钮
  /// 
  /// 显示转换图标，点击展开转换选项菜单。
  /// 只在可编辑状态下可用。
  Widget buildConvertButton() {
    final button = FlowyIconButton(
      icon: FlowySvg(FlowySvgs.turninto_m),
      isSelected: isConvertButtonSelected,
      tooltipText: LocaleKeys.editor_convertTo.tr(),
      preferBelow: false,
      hoverColor: hoverColor,
      width: 36,
      height: 32,
      onPressed: getTapCallback(() {
        setState(() {
          isConvertButtonSelected = true;
        });
        showConvertMenu();
      }),
    );
    if (!editable) return button;
    return AppFlowyPopover(
      offset: Offset(44, 10.0),
      direction: PopoverDirection.bottomWithRightAligned,
      margin: EdgeInsets.zero,
      controller: popoverController,
      onOpen: () => keepEditorFocusNotifier.increase(),
      onClose: () => keepEditorFocusNotifier.decrease(),
      popupBuilder: (context) => buildConvertMenu(),
      child: button,
    );
  }

  /// 构建转换选项菜单
  /// 
  /// 列出所有可用的转换选项，
  /// 点击执行相应的转换操作。
  Widget buildConvertMenu() {
    return MouseRegion(
      onEnter: widget.onEnter,
      onExit: widget.onExit,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SeparatedColumn(
          mainAxisSize: MainAxisSize.min,
          separatorBuilder: () => const VSpace(0.0),
          children:
              List.generate(LinkConvertMenuCommand.values.length, (index) {
            final command = LinkConvertMenuCommand.values[index];
            return SizedBox(
              height: 36,
              child: FlowyButton(
                text: FlowyText(
                  command.title,
                  fontWeight: FontWeight.w400,
                  figmaLineHeight: 20,
                ),
                onTap: () {
                  widget.onConvertTo(command);
                  closeConvertMenu();
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 获取悬停颜色
  /// 
  /// 只读模式下禁用悬停效果
  Color? get hoverColor => editable ? null : Colors.transparent;

  /// 获取点击回调
  /// 
  /// 只读模式下返回null，禁用点击
  VoidCallback? getTapCallback(VoidCallback callback) {
    if (editable) return callback;
    return null;
  }

  /// 显示转换菜单
  void showConvertMenu() {
    keepEditorFocusNotifier.increase();
    popoverController.show();
  }

  /// 关闭转换菜单
  void closeConvertMenu() {
    popoverController.close();
  }
}

/// 悬停触发器键
/// 
/// 用作LinkHoverTriggers中的唯一标识符。
/// 组合节点ID和选区信息来唯一标识一个链接。
/// 
/// ## 设计思想
/// - 使用节点ID确保文档中的唯一性
/// - 使用选区信息区分同一节点中的多个链接
/// - 重写equals和hashCode支持Map存储
/// 
/// ## 特殊处理
/// - 选区比较支持正向和反向选区（start和end交换）
/// - 使用identical优先检查引用相等，提高性能
class HoverTriggerKey {
  HoverTriggerKey(this.nodeId, this.selection);

  /// 节点ID，标识链接所在的文档节点
  final String nodeId;
  /// 选区，标识链接在节点中的位置
  final Selection selection;

  /// 相等性比较
  /// 
  /// 支持：
  /// 1. 引用相等（identical）
  /// 2. 类型、nodeId和selection都相等
  /// 3. 选区正反向都认为相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoverTriggerKey &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          isSelectionSame(other.selection);

  /// 比较两个选区是否相同
  /// 
  /// 考虑正向选区（start->end）和反向选区（end->start）
  /// 两种情况都认为是同一个选区
  /// 比较两个选区是否相同
  /// 
  /// 特别处理：正向选区(start->end)和反向选区(end->start)视为相同
  /// 这是因为用户选择文本时可能从左到右或从右到左
  bool isSelectionSame(Selection other) =>
      (selection.start == other.start && selection.end == other.end) ||  // 正向相同
      (selection.start == other.end && selection.end == other.start);    // 反向相同

  /// 哈希码生成
  /// 
  /// 组合nodeId和selection的哈希码
  @override
  int get hashCode => nodeId.hashCode ^ selection.hashCode;
}

/// 链接悬停触发器管理器
/// 
/// 全局管理文档编辑器中所有链接的悬停菜单触发器。
/// 确保每个链接都能独立管理自己的悬停菜单，避免冲突。
/// 
/// ## 核心功能
/// 1. **触发器注册**：每个链接创建时注册自己的触发器
/// 2. **触发器查找**：通过唯一key快速找到对应的触发器
/// 3. **生命周期管理**：链接销毁时自动注销触发器
/// 
/// ## 设计思想
/// - 使用Map存储，以节点ID和选区作为复合键
/// - 支持同一个key注册多个回调（虽然实际通常只有一个）
/// - 采用注册表模式，解耦链接组件之间的依赖
/// 
/// ## 工作流程
/// ```
/// 链接创建 → 注册触发器(节点ID+选区) → 存储回调
///     ↓
/// 需要显示菜单 → 通过key查找 → 调用第一个回调
///     ↓
/// 链接销毁 → 注销触发器 → 清理内存
/// ```
/// 
/// ## 使用场景
/// - 鼠标悬停在链接上显示操作菜单
/// - 点击链接时显示编辑菜单
/// - 管理链接的各种交互状态
class LinkHoverTriggers {
  /// 触发器映射表
  /// 
  /// key: HoverTriggerKey (包含节点ID和选区信息)
  /// value: 该触发器的所有回调函数集合
  /// 
  /// 使用Set避免重复注册同一个回调
  final Map<HoverTriggerKey, Set<VoidCallback>> _map = {};

  /// 添加触发器（内部方法）
  /// 
  /// 当LinkHoverTrigger组件初始化时调用，
  /// 注册显示悬停菜单的回调函数。
  /// 
  /// [key] 触发器的唯一标识，包含节点ID和选区
  /// [callback] 显示悬停菜单的回调函数
  void _add(HoverTriggerKey key, VoidCallback callback) {
    final callbacks = _map[key] ?? {};
    callbacks.add(callback);
    _map[key] = callbacks;
  }

  /// 移除触发器（内部方法）
  /// 
  /// 当LinkHoverTrigger组件销毁时调用，
  /// 清理注册的回调，避免内存泄漏。
  /// 
  /// [key] 触发器的唯一标识
  /// [callback] 要移除的回调函数
  void _remove(HoverTriggerKey key, VoidCallback callback) {
    final callbacks = _map[key] ?? {};
    callbacks.remove(callback);
    _map[key] = callbacks;
  }

  /// 触发悬停菜单显示
  /// 
  /// 通过key查找对应的触发器并调用其回调。
  /// 如果有多个回调，只调用第一个（通常只有一个）。
  /// 
  /// [key] 要触发的链接标识
  /// 
  /// 调用时机：
  /// - 鼠标悬停在链接上
  /// - 需要程序化显示链接菜单
  /// - 链接被选中需要显示编辑选项
  void call(HoverTriggerKey key) {
    final callbacks = _map[key] ?? {};
    if (callbacks.isEmpty) return;
    // 只调用第一个回调（通常一个链接只有一个触发器）
    callbacks.first.call();
  }
}

/// 链接转换菜单命令枚举
/// 
/// 定义链接可以转换的目标类型。
/// 支持将普通链接转换为更丰富的内容展示形式。
/// 
/// ## 转换类型
/// - **toMention**: 转为@提及，用于引用页面或用户
/// - **toBookmark**: 转为书签，显示链接预览卡片
/// - **toEmbed**: 转为嵌入，直接嵌入网页内容
enum LinkConvertMenuCommand {
  /// 转换为@提及
  toMention,
  /// 转换为书签预览
  toBookmark,
  /// 转换为嵌入内容
  toEmbed;

  /// 获取本地化的显示标题
  String get title {
    switch (this) {
      case toMention:
        return LocaleKeys.document_plugins_linkPreview_linkPreviewMenu_toMetion
            .tr();
      case toBookmark:
        return LocaleKeys
            .document_plugins_linkPreview_linkPreviewMenu_toBookmark
            .tr();
      case toEmbed:
        return LocaleKeys.document_plugins_linkPreview_linkPreviewMenu_toEmbed
            .tr();
    }
  }

  /// 获取对应的块类型
  /// 
  /// 返回转换后的块类型标识符，
  /// 用于创建相应的块组件。
  String get type {
    switch (this) {
      case toMention:
        return MentionBlockKeys.type;
      case toBookmark:
        return LinkPreviewBlockKeys.type;
      case toEmbed:
        return LinkPreviewBlockKeys.type;
    }
  }
}

/// BuildContext的链接扩展
/// 
/// 为BuildContext添加链接相关的便捷方法。
extension LinkExtension on BuildContext {
  /// 复制链接到剪贴板
  /// 
  /// 使用全局剪贴板服务复制链接，
  /// 并显示成功提示。
  /// 
  /// [link] 要复制的链接地址
  Future<void> copyLink(String link) async {
    if (link.isEmpty) return;
    await getIt<ClipboardService>()
        .setData(ClipboardServiceData(plainText: link));
    if (mounted) {
      showToastNotification(
        message: LocaleKeys.shareAction_copyLinkSuccess.tr(),
      );
    }
  }
}
