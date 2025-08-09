/// AppFlowy移动端看板组头部组件
/// 
/// 这个文件包含看板中每个分组列的头部组件，负责显示分组名称、
/// 提供编辑功能、以及分组的操作菜单

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_quick_action_button.dart';
import 'package:appflowy/plugins/database/board/application/board_bloc.dart';
import 'package:appflowy/util/field_type_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// 移动端看板分组头部组件
/// 
/// 这个组件类似于桌面端的 [BoardColumnHeader]，但针对移动端进行了优化。
/// 主要功能包括：
/// - 显示分组名称和图标
/// - 支持双击编辑分组名称（如果字段类型允许）
/// - 提供添加新卡片的快捷按钮
/// - 提供更多操作菜单（重命名、隐藏列等）
/// 
/// 设计思想：
/// - 采用状态管理的方式处理编辑模式的切换
/// - 通过BLoC模式与看板状态进行通信
/// - 移动端优化的交互体验（底部菜单、触摸友好的按钮）
class GroupCardHeader extends StatefulWidget {
  const GroupCardHeader({
    super.key,
    required this.groupData, // 分组数据，包含分组的基本信息和自定义数据
  });

  /// 看板分组数据，包含分组的所有信息
  /// 包括分组ID、名称、自定义数据等
  final AppFlowyGroupData groupData;

  @override
  State<GroupCardHeader> createState() => _GroupCardHeaderState();
}

/// 分组头部组件的状态类
/// 主要管理文本编辑控制器和编辑状态
class _GroupCardHeaderState extends State<GroupCardHeader> {
  /// 文本编辑控制器，用于处理分组名称的编辑
  /// 初始化时设置当前分组名称，并将光标定位到文本末尾
  late final TextEditingController _controller =
      TextEditingController.fromValue(
    TextEditingValue(
      selection: TextSelection.collapsed(
        offset: widget.groupData.headerData.groupName.length, // 光标位置设置在文本末尾
      ),
      text: widget.groupData.headerData.groupName, // 初始文本为当前分组名称
    ),
  );

  @override
  void dispose() {
    _controller.dispose(); // 释放文本编辑控制器资源
    super.dispose();
  }

  /// 构建分组头部组件的UI
  /// 根据当前状态渲染不同的UI：普通显示、编辑模式等
  @override
  Widget build(BuildContext context) {
    // 获取看板自定义数据，包含分组的详细信息
    final boardCustomData = widget.groupData.customData as GroupData;
    // 定义标题文本样式，使用中等粗细字体
    final titleTextStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w600,
        );
    // 使用BlocBuilder监听看板状态变化，根据状态渲染不同UI
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        // 默认标题组件：显示分组名称，超长文本用省略号处理
        Widget title = Text(
          widget.groupData.headerData.groupName,
          style: titleTextStyle,
          overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
        );

        // 判断分组头部是否可以编辑：
        // 1. 不是默认分组（无状态分组）
        // 2. 字段类型支持编辑头部
        if (!boardCustomData.group.isDefault &&
            boardCustomData.fieldType.canEditHeader) {
          // 可编辑的标题：包装在GestureDetector中，点击时进入编辑模式
          title = GestureDetector(
            onTap: () => context
                .read<BoardBloc>()
                .add(BoardEvent.startEditingHeader(widget.groupData.id)), // 触发开始编辑事件
            child: Text(
              widget.groupData.headerData.groupName,
              style: titleTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        // 检查当前分组是否处于编辑状态
        // 通过比较当前分组ID与正在编辑的头部ID来判断
        final isEditing = state.maybeMap(
          ready: (value) => value.editingHeaderId == widget.groupData.id,
          orElse: () => false, // 其他状态下默认不在编辑
        );

        // 如果正在编辑，显示文本输入框
        if (isEditing) {
          title = TextField(
            controller: _controller,
            autofocus: true, // 自动获取焦点
            // 编辑完成时保存更改
            onEditingComplete: () => context.read<BoardBloc>().add(
                  BoardEvent.endEditingHeader(
                    widget.groupData.id,
                    _controller.text, // 传入新的分组名称
                  ),
                ),
            style: titleTextStyle,
            // 点击输入框外部时取消编辑，不保存更改
            onTapOutside: (_) => context.read<BoardBloc>().add(
                  // 分组头部从TextField切换回Text显示
                  // 分组名称不会被更改
                  BoardEvent.endEditingHeader(widget.groupData.id, null),
                ),
          );
        }

        // 返回完整的头部组件布局
        return Padding(
          padding: const EdgeInsets.only(left: 16), // 左侧留白
          child: SizedBox(
            height: 42, // 固定头部高度
            child: Row(
              children: [
                _buildHeaderIcon(boardCustomData), // 分组图标
                Expanded(child: title), // 标题占据剩余空间
                // 更多操作按钮：显示底部菜单
                IconButton(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  splashRadius: 5, // 点击波纹效果半径
                  onPressed: () => showMobileBottomSheet( // 显示移动端底部菜单
                    context,
                    showDragHandle: true, // 显示拖拽手柄
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    builder: (_) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 重命名列操作按钮
                        MobileQuickActionButton(
                          text: LocaleKeys.board_column_renameColumn.tr(),
                          icon: FlowySvgs.edit_s,
                          onTap: () {
                            // 触发开始编辑头部事件
                            context.read<BoardBloc>().add(
                                  BoardEvent.startEditingHeader(
                                    widget.groupData.id,
                                  ),
                                );
                            context.pop(); // 关闭底部菜单
                          },
                        ),
                        const MobileQuickActionDivider(), // 分割线
                        // 隐藏列操作按钮
                        MobileQuickActionButton(
                          text: LocaleKeys.board_column_hideColumn.tr(),
                          icon: FlowySvgs.hide_s,
                          onTap: () {
                            // 设置分组为不可见
                            context.read<BoardBloc>().add(
                                  BoardEvent.setGroupVisibility(
                                    widget.groupData.customData.group
                                        as GroupPB,
                                    false, // 设置为隐藏
                                  ),
                                );
                            context.pop(); // 关闭底部菜单
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // 添加新卡片按钮
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  splashRadius: 5,
                  onPressed: () {
                    // 在当前分组开头位置创建新行（卡片）
                    context.read<BoardBloc>().add(
                          BoardEvent.createRow(
                            widget.groupData.id, // 目标分组ID
                            OrderObjectPositionTypePB.Start, // 插入到开头位置
                            null, // 无特定参考行
                            null, // 无特定数据
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 根据字段类型构建对应的头部图标
  /// 目前只支持复选框类型字段的图标显示
  /// 
  /// [customData] 分组自定义数据，包含字段类型信息
  /// 返回对应的图标组件
  Widget _buildHeaderIcon(GroupData customData) =>
      switch (customData.fieldType) {
        // 复选框字段：根据选中状态显示不同图标
        FieldType.Checkbox => FlowySvg(
            customData.asCheckboxGroup()!.isCheck
                ? FlowySvgs.check_filled_s // 已选中状态图标
                : FlowySvgs.uncheck_s,     // 未选中状态图标
            blendMode: BlendMode.dst, // 混合模式设置
          ),
        // 其他字段类型暂不显示图标
        _ => const SizedBox.shrink(),
      };
}
