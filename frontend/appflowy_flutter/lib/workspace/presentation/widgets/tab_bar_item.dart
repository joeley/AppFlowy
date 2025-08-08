import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_listener.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/*
 * 视图标签栏项组件
 * 
 * 用于在标签栏中显示视图信息
 * 支持显示图标和名称
 * 
 * 核心功能：
 * 1. 显示视图图标（如果存在）
 * 2. 显示视图名称
 * 3. 监听视图更新并实时刷新
 * 4. 支持短格式显示（仅图标）
 * 
 * 设计特点：
 * - 使用ViewListener监听视图变化
 * - 响应式更新UI
 * - 自适应布局（完整/简洁模式）
 */
class ViewTabBarItem extends StatefulWidget {
  const ViewTabBarItem({
    super.key,
    required this.view,
    this.shortForm = false,
  });

  /* 要显示的视图对象 */
  final ViewPB view;
  /* 是否使用短格式（仅显示图标或居中显示） */
  final bool shortForm;

  @override
  State<ViewTabBarItem> createState() => _ViewTabBarItemState();
}

class _ViewTabBarItemState extends State<ViewTabBarItem> {
  /* 视图监听器，用于接收视图更新通知 */
  late final ViewListener _viewListener;
  /* 当前视图状态的本地副本 */
  late ViewPB view;

  @override
  void initState() {
    super.initState();
    view = widget.view;
    /* 创建并启动视图监听器
     * 当视图数据发生变化时（如重命名、更改图标等）
     * 会自动更新UI显示
     */
    _viewListener = ViewListener(viewId: widget.view.id);
    _viewListener.start(
      onViewUpdated: (updatedView) {
        /* 仅在组件仍挂载时更新状态，避免内存泄漏 */
        if (mounted) {
          setState(() => view = updatedView);
        }
      },
    );
  }

  @override
  void dispose() {
    /* 停止监听器，释放资源 */
    _viewListener.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      /* 短格式时居中显示，常规格式时左对齐 */
      mainAxisAlignment:
          widget.shortForm ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        /* 如果视图有图标，显示图标 */
        if (widget.view.icon.value.isNotEmpty)
          RawEmojiIconWidget(
            emoji: widget.view.icon.toEmojiIconData(),
            emojiSize: 16,
          ),
        /* 常规格式且有图标时，添加间距 */
        if (!widget.shortForm && view.icon.value.isNotEmpty) const HSpace(6),
        /* 常规格式或无图标时，显示文字 */
        if (!widget.shortForm || view.icon.value.isEmpty) ...[
          Flexible(
            child: FlowyText.medium(
              view.nameOrDefault,  /* 使用默认名称避免空值 */
              overflow: TextOverflow.ellipsis,  /* 文字过长时显示省略号 */
            ),
          ),
        ],
      ],
    );
  }
}
