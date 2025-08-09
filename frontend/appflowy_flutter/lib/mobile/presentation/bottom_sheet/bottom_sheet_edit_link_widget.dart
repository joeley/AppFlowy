import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_header.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/desktop_toolbar/link/link_edit_menu.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/desktop_toolbar/link/link_search_text_field.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/desktop_toolbar/link/link_styles.dart';
import 'package:appflowy/plugins/shared/share/constants.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/util/link_util.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 移动端底部弹窗链接编辑器组件
/// 
/// 这是一个功能强大的链接编辑器，支持创建和编辑文档中的链接。
/// 设计思想：
/// 1. 统一的链接编辑体验 - 同时支持外部URL链接和内部页面链接
/// 2. 智能搜索 - 集成页面搜索功能，可以快速找到要链接的内部页面
/// 3. 实时验证 - 对URL链接进行实时有效性检查
/// 4. 响应式UI - 根据不同状态动态调整界面布局
/// 5. 完整的生命周期管理 - 妥善处理资源的创建和释放
/// 
/// 架构特点：
/// - 使用StatefulWidget管理复杂的编辑状态
/// - 集成LinkSearchTextField进行智能搜索
/// - 支持页面链接和外部链接的统一处理
/// - 通过回调函数与父组件进行数据交互
/// 
/// 使用场景：移动端文档编辑器中的链接创建和编辑功能
class MobileBottomSheetEditLinkWidget extends StatefulWidget {
  const MobileBottomSheetEditLinkWidget({
    super.key,
    required this.linkInfo,
    required this.onApply,
    required this.onRemoveLink,
    required this.currentViewId,
    required this.onDispose,
  });

  /// 初始链接信息，包含链接名称、URL和页面标识
  final LinkInfo linkInfo;
  /// 应用链接编辑结果的回调函数，在用户确认编辑时调用
  final ValueChanged<LinkInfo> onApply;
  /// 移除链接的回调函数，在用户选择删除链接时调用
  final ValueChanged<LinkInfo> onRemoveLink;
  /// 组件销毁时的回调函数，用于通知父组件进行清理工作
  final VoidCallback onDispose;
  /// 当前文档视图的ID，用于搜索时排除自己
  final String currentViewId;

  @override
  State<MobileBottomSheetEditLinkWidget> createState() =>
      _MobileBottomSheetEditLinkWidgetState();
}

class _MobileBottomSheetEditLinkWidgetState
    extends State<MobileBottomSheetEditLinkWidget> {
  /// 获取应用回调的快捷访问器
  ValueChanged<LinkInfo> get onApply => widget.onApply;

  /// 获取删除回调的快捷访问器
  ValueChanged<LinkInfo> get onRemoveLink => widget.onRemoveLink;

  /// 链接名称输入框控制器，用于管理链接显示名称
  late TextEditingController linkNameController =
      TextEditingController(text: linkInfo.name);
  /// 文本输入框的焦点节点，用于控制输入框的焦点状态
  final textFocusNode = FocusNode();
  /// 当前编辑的链接信息，包含名称、URL和页面属性
  late LinkInfo linkInfo = widget.linkInfo;
  /// 链接搜索文本框组件，提供页面搜索和URL输入功能
  late LinkSearchTextField searchTextField;
  /// 是否正在显示搜索结果界面的状态标志
  bool isShowingSearchResult = false;
  /// 当前选中的页面视图对象，用于页面链接
  ViewPB? currentView;
  /// 是否显示错误提示文本的状态标志
  bool showErrorText = false;
  /// 是否显示移除链接按钮的状态标志
  bool showRemoveLink = false;
  /// 弹窗标题文本，根据编辑模式动态变化
  String title = LocaleKeys.editor_editLink.tr();

  /// 获取当前主题数据的快捷访问器
  AppFlowyThemeData get theme => AppFlowyTheme.of(context);

  @override
  void initState() {
    super.initState();
    // 检查当前链接是否为页面链接
    final isPageLink = linkInfo.isPage;
    // 如果是页面链接，需要获取页面视图信息
    if (isPageLink) getPageView();
    
    // 初始化搜索文本框组件
    searchTextField = LinkSearchTextField(
      // 页面链接时搜索框为空，外部链接时显示现有链接
      initialSearchText: isPageLink ? '' : linkInfo.link,
      // 设置初始视图ID
      initialViewId: linkInfo.viewId,
      // 传入当前视图ID以排除自引用
      currentViewId: widget.currentViewId,
      // 空的回车和退出回调，移动端不需要键盘快捷键
      onEnter: () {},
      onEscape: () {},
      // 数据刷新时更新界面状态
      onDataRefresh: () {
        if (mounted) setState(() {});
      },
    )..searchRecentViews(); // 立即搜索最近访问的页面
    
    // 根据链接是否为空决定初始状态
    if (linkInfo.link.isEmpty) {
      // 新建链接时显示搜索界面
      isShowingSearchResult = true;
      title = LocaleKeys.toolbar_addLink.tr();
    } else {
      // 编辑现有链接时显示移除按钮并聚焦到名称输入框
      showRemoveLink = true;
      textFocusNode.requestFocus();
    }
    
    // 监听文本框焦点变化，聚焦时隐藏搜索结果
    textFocusNode.addListener(() {
      if (!mounted) return;
      if (textFocusNode.hasFocus) {
        setState(() {
          isShowingSearchResult = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // 释放文本编辑控制器资源
    linkNameController.dispose();
    // 释放焦点节点资源
    textFocusNode.dispose();
    // 释放搜索文本框资源
    searchTextField.dispose();
    // 通知父组件进行清理工作
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 设置弹窗高度为屏幕高度的80%，确保有足够空间显示内容
      height: MediaQuery.of(context).size.height * 0.8,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 底部弹窗头部，包含标题和确认按钮
            BottomSheetHeader(
              title: title,
              onClose: () => context.pop(),
              confirmButton: FlowyTextButton(
                LocaleKeys.button_done.tr(),
                // 固定按钮尺寸，确保布局稳定
                constraints:
                    const BoxConstraints.tightFor(width: 62, height: 30),
                padding: const EdgeInsets.only(left: 12),
                fontColor: theme.textColorScheme.onFill,
                fillColor: Theme.of(context).primaryColor,
                onPressed: () {
                  // 如果正在显示搜索结果，执行搜索确认逻辑
                  if (isShowingSearchResult) {
                    onConfirm();
                    return;
                  }
                  // 验证链接的有效性
                  if (linkInfo.link.isEmpty || !isUri(linkInfo.link)) {
                    setState(() {
                      showErrorText = true;
                    });
                    return;
                  }
                  // 应用链接编辑结果并关闭弹窗
                  widget.onApply.call(linkInfo);
                  context.pop();
                },
              ),
            ),
            const VSpace(20.0),
            // 链接名称输入字段
            buildNameTextField(),
            const VSpace(16.0),
            // 链接地址输入/显示字段
            buildLinkField(),
            const VSpace(20.0),
            // 移除链接按钮（条件显示）
            buildRemoveLink(),
          ],
        ),
      ),
    );
  }

  /// 构建链接名称输入文本框
  /// 允许用户自定义链接的显示文本
  Widget buildNameTextField() {
    return SizedBox(
      height: 48,
      child: TextFormField(
        // 绑定焦点节点，用于控制焦点状态
        focusNode: textFocusNode,
        textAlign: TextAlign.left,
        // 绑定文本控制器管理输入内容
        controller: linkNameController,
        style: TextStyle(
          fontSize: 16,
          // 设置行高比例，确保文本垂直居中
          height: 20 / 16,
          fontWeight: FontWeight.w400,
        ),
        // 监听文本变化，实时更新链接信息
        onChanged: (text) {
          linkInfo = LinkInfo(
            name: text,
            link: linkInfo.link,
            isPage: linkInfo.isPage,
          );
        },
        // 使用统一的链接输入框样式
        decoration: LinkStyle.buildLinkTextFieldInputDecoration(
          LocaleKeys.document_toolbar_linkNameHint.tr(),
          contentPadding: EdgeInsets.all(14),
          radius: 12,
          context,
        ),
      ),
    );
  }

  /// 构建链接地址输入/显示字段
  /// 根据当前状态显示不同的UI：搜索界面、页面视图或链接视图
  Widget buildLinkField() {
    final width = MediaQuery.of(context).size.width;
    // 判断是否应该显示页面视图（页面链接且不在搜索状态）
    final showPageView = linkInfo.isPage && !isShowingSearchResult;
    Widget child;
    
    if (showPageView) {
      // 显示选中的页面信息
      child = buildPageView();
    } else if (!isShowingSearchResult) {
      // 显示外部链接信息
      child = buildLinkView();
    } else {
      // 显示搜索界面
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 构建搜索输入框
          searchTextField.buildTextField(
            autofocus: true,
            context: context,
            contentPadding: EdgeInsets.all(14),
            textStyle: TextStyle(
              fontSize: 16,
              height: 20 / 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          VSpace(6),
          // 构建搜索结果容器
          searchTextField.buildResultContainer(
            context: context,
            onPageLinkSelected: onPageSelected,
            onLinkSelected: onLinkSelected,
            // 减去左右边距，确保结果容器宽度合适
            width: width - 32,
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        // 显示错误提示文本（条件显示）
        if (showErrorText)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FlowyText.regular(
              LocaleKeys.document_plugins_file_networkUrlInvalid.tr(),
              color: theme.textColorScheme.error,
              fontSize: 12,
              figmaLineHeight: 16,
            ),
          ),
      ],
    );
  }

  /// 构建页面视图显示组件
  /// 显示选中页面的名称和图标，用户可点击重新搜索
  Widget buildPageView() {
    final height = 48.0;
    late Widget child;
    final view = currentView;
    
    if (view == null) {
      // 页面信息加载中，显示加载指示器
      child = Center(
        child: SizedBox.fromSize(
          size: Size(10, 10),
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      // 显示页面信息
      final viewName = view.name;
      // 如果页面名称为空，使用占位符文本
      final displayName = viewName.isEmpty
          ? LocaleKeys.document_title_placeholder.tr()
          : viewName;
      
      child = GestureDetector(
        // 点击可重新打开搜索界面
        onTap: showSearchResult,
        child: Container(
          height: height,
          // 几乎透明的背景色，提供点击反馈
          color: Colors.grey.withAlpha(1),
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              // 显示页面类型图标
              searchTextField.buildIcon(view),
              HSpace(4),
              // 显示页面名称，支持文本溢出省略
              Flexible(
                child: FlowyText.regular(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  figmaLineHeight: 20,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: height,
      decoration: buildBorderDecoration(),
      child: child,
    );
  }

  /// 构建外部链接视图显示组件
  /// 显示外部链接URL和地球图标，用户可点击重新编辑
  Widget buildLinkView() {
    return Container(
      height: 48,
      decoration: buildBorderDecoration(),
      child: GestureDetector(
        // 使用opaque确保整个区域都可以响应点击
        behavior: HitTestBehavior.opaque,
        // 点击可重新打开搜索/编辑界面
        onTap: showSearchResult,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // 显示地球图标表示外部链接
              FlowySvg(FlowySvgs.toolbar_link_earth_m),
              HSpace(8),
              // 显示链接URL，支持文本溢出省略
              Flexible(
                child: FlowyText.regular(
                  linkInfo.link,
                  overflow: TextOverflow.ellipsis,
                  figmaLineHeight: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建移除链接按钮组件
  /// 只在编辑现有链接时显示，允许用户删除链接
  Widget buildRemoveLink() {
    // 如果不应该显示移除按钮，返回空组件
    if (!showRemoveLink) return SizedBox.shrink();
    
    return GestureDetector(
      // 确保整个区域都可以响应点击
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 执行移除链接回调并关闭弹窗
        widget.onRemoveLink(linkInfo);
        context.pop();
      },
      child: SizedBox(
        height: 32,
        child: Center(
          child: Row(
            // 居中显示按钮内容
            mainAxisSize: MainAxisSize.min,
            children: [
              // 移除链接图标
              FlowySvg(
                FlowySvgs.mobile_icon_remove_link_m,
                color: theme.iconColorScheme.secondary,
              ),
              HSpace(8),
              // 移除链接文本
              FlowyText.regular(
                LocaleKeys.editor_removeLink.tr(),
                overflow: TextOverflow.ellipsis,
                figmaLineHeight: 20,
                color: theme.textColorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理搜索确认操作
  /// 根据搜索结果类型执行相应的处理逻辑
  void onConfirm() {
    searchTextField.onSearchResult(
      // 选择外部链接时的处理
      onLink: onLinkSelected,
      // 选择最近访问页面时的处理
      onRecentViews: () => onPageSelected(searchTextField.currentRecentView),
      // 选择搜索到的页面时的处理
      onSearchViews: () => onPageSelected(searchTextField.currentSearchedView),
      // 没有搜索结果时的处理
      onEmpty: () {
        searchTextField.unfocus();
      },
    );
  }

  /// 处理页面选择事件
  /// 当用户选择一个页面作为链接目标时调用
  /// 
  /// [view] - 被选中的页面视图对象
  Future<void> onPageSelected(ViewPB view) async {
    // 保存选中的视图
    currentView = view;
    
    // 构建页面分享链接URL
    final link = ShareConstants.buildShareUrl(
      // 获取当前工作空间ID
      workspaceId: await UserBackendService.getCurrentWorkspace().fold(
        (s) => s.id,
        (f) => '',
      ),
      viewId: view.id,
    );
    
    // 更新链接信息，标记为页面链接
    linkInfo = LinkInfo(
      name: linkInfo.name,
      link: link,
      isPage: true,
    );
    
    // 更新搜索文本框的内容
    searchTextField.updateText(linkInfo.link);
    
    // 更新UI状态，隐藏搜索结果并取消焦点
    if (mounted) {
      setState(() {
        isShowingSearchResult = false;
        searchTextField.unfocus();
      });
    }
  }

  /// 处理外部链接选择事件
  /// 当用户输入外部URL作为链接时调用
  void onLinkSelected() {
    if (mounted) {
      // 更新链接信息为外部链接
      linkInfo = LinkInfo(
        name: linkInfo.name,
        link: searchTextField.searchText,
      );
      // 隐藏搜索结果界面
      hideSearchResult();
    }
  }

  /// 隐藏搜索结果界面
  /// 将界面切换回编辑状态，取消所有输入框焦点
  void hideSearchResult() {
    setState(() {
      isShowingSearchResult = false;
      // 取消搜索文本框焦点
      searchTextField.unfocus();
      // 取消名称输入框焦点
      textFocusNode.unfocus();
    });
  }

  /// 显示搜索结果界面
  /// 将界面切换到搜索状态，聚焦到搜索输入框
  void showSearchResult() {
    setState(() {
      // 如果是页面链接，清空搜索文本以便重新搜索
      if (linkInfo.isPage) searchTextField.updateText('');
      isShowingSearchResult = true;
      // 聚焦到搜索输入框
      searchTextField.requestFocus();
    });
  }

  /// 获取页面视图信息
  /// 根据链接信息中的viewId异步获取页面详情
  Future<void> getPageView() async {
    // 只有页面链接才需要获取视图信息
    if (!linkInfo.isPage) return;
    
    // 通过后端服务获取页面状态信息
    final (view, isInTrash, isDeleted) =
        await ViewBackendService.getMentionPageStatus(linkInfo.viewId);
    
    // 更新当前视图状态
    if (mounted) {
      setState(() {
        currentView = view;
      });
    }
  }

  /// 构建卡片装饰样式
  /// 创建带有圆角和阴影的卡片外观（当前未使用）
  BoxDecoration buildCardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(theme.borderRadius.l),
      boxShadow: theme.shadow.medium,
    );
  }

  /// 构建边框装饰样式
  /// 创建带有圆角和边框的装饰，用于链接显示区域
  BoxDecoration buildBorderDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(theme.borderRadius.l),
      border: Border.all(color: theme.borderColorScheme.primary),
    );
  }
}
