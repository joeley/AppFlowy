/*
 * 移动端底部弹窗拖动手柄组件模块
 * 
 * 为AppFlowy移动端底部弹窗提供标准化的拖动手柄视觉指示器
 * 符合Material Design的设计规范，提供直观的拖动交互反馈
 * 
 * 设计思想：
 * 1. **视觉提示**：小的圆角矩形条向用户传达可拖动信息
 * 2. **标准化**：遵循系统设计语言，与其他平台保持一致
 * 3. **主题适应**：使用系统提示色，自动适应深浅主题
 * 4. **精简实用**：最小化设计，不干扰主要内容
 * 
 * 使用场景：
 * - 底部弹窗顶部的拖动指示器
 * - 可拖动对话框
 * - 其他需要拖动交互的组件
 */

import 'package:flutter/material.dart';

/*
 * 移动端底部弹窗拖动手柄组件
 * 
 * 提供标准化的拖动手柄视觉元素，用于指示用户可以拖动底部弹窗
 * 
 * 视觉设计特点：
 * 1. **尺寸标准**：60x4像素的横向条形，符合Material Design规范
 * 2. **圆角设计**：2像素圆角，提供柔和的视觉感受
 * 3. **适度间距**：上下10像素内边距，确保触摸区域合理
 * 4. **主题颜色**：使用hintColor，自动适应深浅主题
 * 
 * 交互设计考虑：
 * - 尺寸足够大，便于手指操作
 * - 位置突出，一眼就能发现
 * - 颜色适中，既不太突兴也不太蕴淡
 * 
 * 技术实现：
 * - StatelessWidget：纯展示组件，无状态管理
 * - Container + BoxDecoration：灵活的样式控制
 * - Theme主题集成：保证与应用整体风格一致
 */
class MobileBottomSheetDragHandler extends StatelessWidget {
  const MobileBottomSheetDragHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      /* 上下内边距10像素
       * 作用：
       * 1. 为手柄提供足够的触摸区域
       * 2. 与其他内容保持合理间距
       * 3. 保证在各种屏幕密度下都有良好的可点击性 */
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Container(
        width: 60,   /* 手柄宽度：60像素，既显眼又不占过多空间 */
        height: 4,   /* 手柄高度：4像素，细致而不占地方 */
        decoration: BoxDecoration(
          /* 圆角半径：2像素（等于高度的一半）
           * 效果：使手柄两端呈半圆形，视觉更加柔和 */
          borderRadius: BorderRadius.circular(2.0),
          /* 使用主题的提示颜色
           * hintColor通常是一种中性的灰色，既可见又不突兴
           * 在深浅主题中会自动调整为合适的颜色 */
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}
