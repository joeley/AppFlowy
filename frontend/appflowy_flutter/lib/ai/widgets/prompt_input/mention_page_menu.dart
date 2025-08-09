import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_input_control_cubit.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view_title/view_title_bar_bloc.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/space_icon.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// 界面常量定义
const double _itemHeight = 44.0;     // 每个页面项的高度
const double _noPageHeight = 20.0;   // 无页面提示的高度
const double _fixedWidth = 360.0;    // 菜单固定宽度
const double _maxHeight = 328.0;     // 菜单最大高度

/// 提示词输入锚点
/// 
/// 用于定位@提及菜单的位置
/// 包含输入框的key和层链接
class PromptInputAnchor {
  PromptInputAnchor(this.anchorKey, this.layerLink);

  final GlobalKey<State<StatefulWidget>> anchorKey;
  final LayerLink layerLink;
}

/// @提及页面菜单组件
/// 
/// 功能说明：
/// 1. 显示可@提及的页面列表
/// 2. 支持搜索过滤
/// 3. 键盘导航（上下箭头）
/// 4. 自动定位到光标位置
/// 
/// 设计特点：
/// - 使用CompositedTransformFollower跟随输入框
/// - 自动滚动到选中项
/// - 显示页面图标、名称和路径
class PromptInputMentionPageMenu extends StatefulWidget {
  const PromptInputMentionPageMenu({
    super.key,
    required this.anchor,
    required this.textController,
    required this.onPageSelected,
  });

  final PromptInputAnchor anchor;
  final TextEditingController textController;
  final void Function(ViewPB view) onPageSelected;

  @override
  State<PromptInputMentionPageMenu> createState() =>
      _PromptInputMentionPageMenuState();
}

class _PromptInputMentionPageMenuState
    extends State<PromptInputMentionPageMenu> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (mounted) {
        context.read<ChatInputControlCubit>().refreshViews();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatInputControlCubit, ChatInputControlState>(
      builder: (context, state) {
        return Stack(
          children: [
            CompositedTransformFollower(
              link: widget.anchor.layerLink,
              showWhenUnlinked: false,
              offset: Offset(getPopupOffsetX(), 0.0),
              followerAnchor: Alignment.bottomLeft,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: _fixedWidth,
                  maxWidth: _fixedWidth,
                  maxHeight: _maxHeight,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A1F2329),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Color(0x0A1F2329),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Color(0x0F1F2329),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: TextFieldTapRegion(
                  child: PromptInputMentionPageList(
                    onPageSelected: widget.onPageSelected,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 计算弹出菜单的X偏移量
  /// 
  /// 功能说明：
  /// 1. 根据@符号在输入框中的位置计算
  /// 2. 使用TextPainter测量文本宽度
  /// 3. 返回光标位置的x坐标
  /// 
  /// 确保菜单显示在@符号下方
  double getPopupOffsetX() {
    if (widget.anchor.anchorKey.currentContext == null) {
      return 0.0;
    }

    final cubit = context.read<ChatInputControlCubit>();
    if (cubit.filterStartPosition == -1) {
      return 0.0;
    }

    // 获取@符号结束位置
    final textPosition = TextPosition(offset: cubit.filterEndPosition);
    final renderBox =
        widget.anchor.anchorKey.currentContext?.findRenderObject() as RenderBox;

    // 创建文本绘制器测量文本
    final textPainter = TextPainter(
      text: TextSpan(text: cubit.formatIntputText(widget.textController.text)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      minWidth: renderBox.size.width,
      maxWidth: renderBox.size.width,
    );

    // 获取光标偏移量
    final caretOffset = textPainter.getOffsetForCaret(textPosition, Rect.zero);
    final boxes = textPainter.getBoxesForSelection(
      TextSelection(
        baseOffset: textPosition.offset,
        extentOffset: textPosition.offset,
      ),
    );

    if (boxes.isNotEmpty) {
      return boxes.last.right;
    }

    return caretOffset.dx;
  }
}

/// @提及页面列表组件
/// 
/// 功能说明：
/// 1. 显示过滤后的页面列表
/// 2. 支持键盘导航选择
/// 3. 自动滚动到焦点项
/// 4. 空状态和加载状态处理
/// 
/// 设计特点：
/// - 使用SimpleAutoScrollController实现平滑滚动
/// - BlocConsumer监听焦点变化
/// - 列表项显示图标、标题和祖先路径
class PromptInputMentionPageList extends StatefulWidget {
  const PromptInputMentionPageList({
    super.key,
    required this.onPageSelected,
  });

  final void Function(ViewPB view) onPageSelected;

  @override
  State<PromptInputMentionPageList> createState() =>
      _PromptInputMentionPageListState();
}

class _PromptInputMentionPageListState
    extends State<PromptInputMentionPageList> {
  final autoScrollController = SimpleAutoScrollController(
    suggestedRowHeight: _itemHeight,
    beginGetter: (rect) => rect.top + 8.0,
    endGetter: (rect) => rect.bottom - 8.0,
  );

  @override
  void dispose() {
    autoScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatInputControlCubit, ChatInputControlState>(
      listenWhen: (previous, current) {
        return previous.maybeWhen(
          ready: (_, pFocusedViewIndex) => current.maybeWhen(
            ready: (_, cFocusedViewIndex) =>
                pFocusedViewIndex != cFocusedViewIndex,
            orElse: () => false,
          ),
          orElse: () => false,
        );
      },
      listener: (context, state) {
        state.maybeWhen(
          ready: (views, focusedViewIndex) {
            if (focusedViewIndex == -1 || !autoScrollController.hasClients) {
              return;
            }
            if (autoScrollController.isAutoScrolling) {
              autoScrollController.position
                  .jumpTo(autoScrollController.position.pixels);
            }
            autoScrollController.scrollToIndex(
              focusedViewIndex,
              duration: const Duration(milliseconds: 200),
              preferPosition: AutoScrollPosition.begin,
            );
          },
          orElse: () {},
        );
      },
      builder: (context, state) {
        return state.maybeWhen(
          loading: () {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                height: _noPageHeight,
                child: Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            );
          },
          ready: (views, focusedViewIndex) {
            if (views.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: _noPageHeight,
                  child: Center(
                    child: FlowyText(
                      LocaleKeys.chat_inputActionNoPages.tr(),
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              controller: autoScrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: views.length,
              itemBuilder: (context, index) {
                final view = views[index];
                return AutoScrollTag(
                  key: ValueKey("chat_mention_page_item_${view.id}"),
                  index: index,
                  controller: autoScrollController,
                  child: _ChatMentionPageItem(
                    view: view,
                    onTap: () => widget.onPageSelected(view),
                    isSelected: focusedViewIndex == index,
                  ),
                );
              },
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// 聊天提及页面项组件
/// 
/// 功能说明：
/// 1. 显示单个可提及的页面
/// 2. 包含图标、标题和路径
/// 3. 支持选中高亮
/// 4. 悬停显示完整名称
class _ChatMentionPageItem extends StatelessWidget {
  const _ChatMentionPageItem({
    required this.view,
    required this.isSelected,
    required this.onTap,
  });

  final ViewPB view;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: view.name,  // 悬停显示完整名称
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: FlowyHover(
            isSelected: () => isSelected,  // 键盘导航选中状态
            child: Container(
              height: _itemHeight,
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  MentionViewIcon(view: view),  // 页面图标
                  const HSpace(8.0),
                  Expanded(child: MentionViewTitleAndAncestors(view: view)),  // 标题和路径
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 提及视图图标组件
/// 
/// 功能说明：
/// 1. 显示页面的图标
/// 2. 支持自定义emoji图标
/// 3. 空间视图显示特殊图标
/// 4. 默认显示布局类型图标
/// 
/// 优先级：自定义emoji > 空间图标 > 布局图标
class MentionViewIcon extends StatelessWidget {
  const MentionViewIcon({
    super.key,
    required this.view,
  });

  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    final spaceIcon = view.buildSpaceIconSvg(context);

    if (view.icon.value.isNotEmpty) {
      return SizedBox(
        width: 16.0,
        child: RawEmojiIconWidget(
          emoji: view.icon.toEmojiIconData(),
          emojiSize: 14,
        ),
      );
    }

    if (view.isSpace == true && spaceIcon != null) {
      return SpaceIcon(
        dimension: 16.0,
        svgSize: 9.68,
        space: view,
        cornerRadius: 4,
      );
    }

    return FlowySvg(
      view.layout.icon,
      size: const Size.square(16),
      color: Theme.of(context).hintColor,
    );
  }
}

/// 提及视图标题和祖先路径组件
/// 
/// 功能说明：
/// 1. 显示页面标题
/// 2. 显示页面的祖先路径（面包屑）
/// 3. 路径过长时使用省略号
/// 4. 空标题显示占位符
/// 
/// 设计特点：
/// - 两行布局：标题在上，路径在下
/// - 路径使用灰色小字体
/// - 智能路径压缩（中间省略）
class MentionViewTitleAndAncestors extends StatelessWidget {
  const MentionViewTitleAndAncestors({
    super.key,
    required this.view,
  });

  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ViewTitleBarBloc(view: view),
      child: BlocBuilder<ViewTitleBarBloc, ViewTitleBarState>(
        builder: (context, state) {
          // 处理空标题
          final nonEmptyName = view.name.isEmpty
              ? LocaleKeys.document_title_placeholder.tr()
              : view.name;

          // 获取祖先路径字符串
          final ancestorList = _getViewAncestorList(state.ancestors);

          // 无祖先路径时只显示标题
          if (state.ancestors.isEmpty || ancestorList.trim().isEmpty) {
            return FlowyText(
              nonEmptyName,
              fontSize: 14.0,
              overflow: TextOverflow.ellipsis,
            );
          }

          // 有祖先路径时显示两行
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlowyText(
                nonEmptyName,  // 页面标题
                fontSize: 14.0,
                figmaLineHeight: 20.0,
                overflow: TextOverflow.ellipsis,
              ),
              FlowyText(
                ancestorList,  // 祖先路径
                fontSize: 12.0,
                figmaLineHeight: 16.0,
                color: Theme.of(context).hintColor,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 获取视图祖先列表字符串
  /// 
  /// 功能说明：
  /// 1. 跳过工作区名称（索引0）
  /// 2. 不包含当前视图（最后一个）
  /// 3. 路径过长时中间使用省略号
  /// 4. 使用"/"分隔路径
  /// 
  /// 基于workspace/presentation/widgets/view_title_bar.dart实现
  /// 但返回字符串而非组件列表
  String _getViewAncestorList(
    List<ViewPB> views,
  ) {
    const lowerBound = 2;  // 显示前两个
    final upperBound = views.length - 2;  // 显示最后一个
    bool hasAddedEllipsis = false;
    String result = "";

    if (views.length <= 1) {
      return "";
    }

    // 跳过工作区视图（索引0），从索引1开始
    // 不包含当前视图（最后一个）
    for (var i = 1; i < views.length - 1; i++) {
      final view = views[i];

      // 中间部分用省略号代替
      if (i >= lowerBound && i < upperBound) {
        if (!hasAddedEllipsis) {
          hasAddedEllipsis = true;
          result += "… / ";
        }
        continue;
      }

      // 处理空名称
      final nonEmptyName = view.name.isEmpty
          ? LocaleKeys.document_title_placeholder.tr()
          : view.name;

      result += nonEmptyName;

      // 添加路径分隔符
      if (i != views.length - 2) {
        result += " / ";
      }
    }
    return result;
  }
}
