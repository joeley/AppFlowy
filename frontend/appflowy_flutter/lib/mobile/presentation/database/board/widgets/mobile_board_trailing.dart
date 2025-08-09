/// AppFlowy移动端看板尾随组件
/// 
/// 这个文件实现了看板尾部的添加新分组功能。
/// 提供了一个可展开的编辑界面，用户可以输入新分组的名称

import 'package:flutter/material.dart';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/board/application/board_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端看板尾随组件 - 添加新分组
/// 
/// 这个组件显示在看板的最右侧，用于添加新的分组列。
/// 主要特点：
/// - 默认显示一个按钮，点击后展开编辑界面
/// - 编辑模式下显示文本输入框和确认/取消按钮
/// - 支持实时验证输入内容的有效性
/// - 优雅的动画过渡和移动端优化的交互体验
/// 
/// 设计思想：
/// - 采用状态管理方式切换显示和编辑模式
/// - 使用屏幕宽度百分比定义组件大小，适配不同屏幕
/// - 注重用户交互体验，提供直观的反馈
class MobileBoardTrailing extends StatefulWidget {
  const MobileBoardTrailing({super.key});

  @override
  State<MobileBoardTrailing> createState() => _MobileBoardTrailingState();
}

/// 看板尾随组件的状态类
/// 管理编辑状态和文本输入控制
class _MobileBoardTrailingState extends State<MobileBoardTrailing> {
  /// 文本输入控制器，用于管理新分组名称的输入
  final TextEditingController _textController = TextEditingController();

  /// 编辑状态标记，控制UI的切换
  bool isEditing = false;

  @override
  void dispose() {
    _textController.dispose(); // 释放文本控制器资源
    super.dispose();
  }

  /// 构建组件UI
  /// 根据isEditing状态渲染不同的界面：按钮或编辑表单
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size; // 获取屏幕尺寸信息
    final style = Theme.of(context); // 获取当前主题样式

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8), // 水平边距
      child: SizedBox(
        width: screenSize.width * 0.7, // 宽度为屏幕宽度的70%
        // 根据编辑状态切换不同的UI
        child: isEditing
            // 编辑模式：显示输入框和操作按钮
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: style.colorScheme.secondary, // 使用主题的次要颜色
                  borderRadius: BorderRadius.circular(8), // 8px圆角
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 内边距
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 列高度最小化
                    children: [
                      // 文本输入框
                      TextField(
                        controller: _textController,
                        autofocus: true, // 自动获取焦点
                        onChanged: (_) => setState(() {}), // 输入改变时更新UI
                        decoration: InputDecoration(
                          // 可清空按钮：只在有文本时显示
                          suffixIcon: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200), // 200ms渐变动画
                            opacity: _textController.text.isNotEmpty ? 1 : 0, // 根据输入内容控制透明度
                            child: Material(
                              color: Colors.transparent, // 透明背景
                              shape: const CircleBorder(), // 圆形按钮
                              clipBehavior: Clip.antiAlias, // 裁剪子组件
                              child: IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: style.colorScheme.onSurface,
                                ),
                                onPressed: () =>
                                    setState(() => _textController.clear()), // 清空输入内容
                              ),
                            ),
                          ),
                          isDense: true, // 紧凑样式
                        ),
                        // 编辑完成时（按回车键）创建新分组
                        onEditingComplete: () {
                          context.read<BoardBloc>().add(
                                BoardEvent.createGroup(
                                  _textController.text, // 传入输入的分组名称
                                ),
                              );
                          _textController.clear(); // 清空输入框
                          setState(() => isEditing = false); // 退出编辑模式
                        },
                      ),
                      // 操作按钮行：取消和确认
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 两端对齐
                        children: [
                          // 取消按钮
                          TextButton(
                            child: Text(
                              LocaleKeys.button_cancel.tr(),
                              style: style.textTheme.titleSmall?.copyWith(
                                color: style.colorScheme.onSurface,
                              ),
                            ),
                            onPressed: () => setState(() => isEditing = false), // 退出编辑模式
                          ),
                          // 确认添加按钮
                          TextButton(
                            child: Text(
                              LocaleKeys.button_add.tr(),
                              style: style.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold, // 加粗字体
                                color: style.colorScheme.onSurface,
                              ),
                            ),
                            onPressed: () {
                              // 创建新分组
                              context.read<BoardBloc>().add(
                                    BoardEvent.createGroup(
                                      _textController.text,
                                    ),
                                  );
                              _textController.clear(); // 清空输入
                              setState(() => isEditing = false); // 退出编辑模式
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            // 非编辑模式：显示添加新分组按钮
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: style.colorScheme.onSurface, // 前景色
                  backgroundColor: style.colorScheme.secondary, // 背景色
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 圆角边框
                  ),
                ).copyWith(
                  // 悬停时的覆盖颜色
                  overlayColor:
                      WidgetStateProperty.all(Theme.of(context).hoverColor),
                ),
                icon: const Icon(Icons.add), // 加号图标
                label: Text(
                  LocaleKeys.board_column_newGroup.tr(), // 国际化文本
                  style: style.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600, // 中等粗细字体
                  ),
                ),
                onPressed: () => setState(() => isEditing = true), // 点击时进入编辑模式
              ),
      ),
    );
  }
}
