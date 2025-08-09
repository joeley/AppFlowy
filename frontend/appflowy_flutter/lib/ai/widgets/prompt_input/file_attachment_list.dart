import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/ai/service/ai_prompt_input_bloc.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_input_file_bloc.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:styled_widget/styled_widget.dart';

import 'layout_define.dart';

/// 提示词输入文件附件列表组件
/// 
/// 功能说明：
/// 1. 显示已附加的文件列表
/// 2. 横向滚动布局，节省垂直空间
/// 3. 支持删除已添加的文件
/// 
/// 使用场景：
/// - 在AI对话中附加文档供AI参考
/// - 支持PDF、TXT、MD等文本格式
class PromptInputFile extends StatelessWidget {
  const PromptInputFile({
    super.key,
    required this.onDeleted,
  });

  /// 删除文件的回调函数
  final void Function(ChatFile) onDeleted;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AIPromptInputBloc, AIPromptInputState, List<ChatFile>>(
      // 只监听附件列表变化
      selector: (state) => state.attachedFiles,
      builder: (context, files) {
        // 无附件时不显示
        if (files.isEmpty) {
          return const SizedBox.shrink();
        }
        // 横向列表显示附件
        return ListView.separated(
          scrollDirection: Axis.horizontal,  // 横向滚动
          padding: DesktopAIPromptSizes.attachedFilesBarPadding -
              const EdgeInsets.only(top: 6),
          separatorBuilder: (context, index) => const HSpace(
            DesktopAIPromptSizes.attachedFilesPreviewSpacing - 6,
          ),
          itemCount: files.length,
          itemBuilder: (context, index) => ChatFilePreview(
            file: files[index],
            onDeleted: () => onDeleted(files[index]),
          ),
        );
      },
    );
  }
}

/// 聊天文件预览组件
/// 
/// 功能说明：
/// 1. 显示文件图标、名称和类型
/// 2. 悬停时显示删除按钮
/// 3. 使用卡片样式展示
/// 
/// 设计特点：
/// - 固定最大宽度，防止文件名过长
/// - 圆角边框设计，美观大方
/// - 悬停交互，简洁高效
class ChatFilePreview extends StatefulWidget {
  const ChatFilePreview({
    required this.file,
    required this.onDeleted,
    super.key,
  });

  /// 聊天文件对象
  final ChatFile file;
  /// 删除回调
  final VoidCallback onDeleted;

  @override
  State<ChatFilePreview> createState() => _ChatFilePreviewState();
}

class _ChatFilePreviewState extends State<ChatFilePreview> {
  /// 悬停状态
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 为每个文件创建独立的状态管理器
      create: (context) => ChatInputFileBloc(file: widget.file),
      child: BlocBuilder<ChatInputFileBloc, ChatInputFileState>(
        builder: (context, state) {
          return MouseRegion(
            // 鼠标悬停事件处理
            onEnter: (_) => setHover(true),
            onExit: (_) => setHover(false),
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsetsDirectional.only(top: 6, end: 6),
                  constraints: const BoxConstraints(maxWidth: 240),  // 限制最大宽度
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 文件图标容器
                      Container(
                        decoration: BoxDecoration(
                          color: AFThemeExtension.of(context).tint1,  // 淡色背景
                          borderRadius: BorderRadius.circular(8),
                        ),
                        height: 32,
                        width: 32,
                        child: Center(
                          child: FlowySvg(
                            FlowySvgs.page_m,  // 页面图标
                            size: const Size.square(16),
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                      const HSpace(8),
                      // 文件信息
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 文件名
                            FlowyText(
                              widget.file.fileName,
                              fontSize: 12.0,
                            ),
                            // 文件类型
                            FlowyText(
                              widget.file.fileType.name,
                              color: Theme.of(context).hintColor,
                              fontSize: 12.0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 悬停时显示删除按钮
                if (isHover)
                  _CloseButton(
                    onTap: widget.onDeleted,
                  ).positioned(top: 0, right: 0),  // 定位在右上角
              ],
            ),
          );
        },
      ),
    );
  }

  /// 设置悬停状态
  /// 
  /// 只在状态真正改变时更新，避免不必要的重建
  void setHover(bool value) {
    if (value != isHover) {
      setState(() => isHover = value);
    }
  }
}

/// 关闭（删除）按钮组件
/// 
/// 功能：
/// 1. 显示关闭图标
/// 2. 点击时删除对应文件
/// 3. 鼠标悬停时显示手型光标
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  /// 点击回调
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,  // 手型光标
      child: GestureDetector(
        onTap: onTap,
        child: FlowySvg(
          FlowySvgs.ai_close_filled_s,  // 填充式关闭图标
          color: AFThemeExtension.of(context).greyHover,
          size: const Size.square(16),
        ),
      ),
    );
  }
}
