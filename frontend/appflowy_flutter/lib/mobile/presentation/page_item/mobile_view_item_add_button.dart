/// 移动端视图项操作按钮组件
/// 
/// 这个文件定义了移动端视图项中使用的操作按钮组件，包括添加按钮和更多操作按钮。
/// 主要用于工作空间、页面列表等界面中的快捷操作入口。
/// 
/// 设计思想：
/// - 提供统一的按钮尺寸和样式标准
/// - 使用系统定义的尺寸常量，保持界面一致性
/// - 采用简洁的图标设计，符合移动端交互习惯
/// - 基于FlowyIconButton进行封装，复用基础组件能力
/// - 支持自定义回调函数，提供灵活的交互处理

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 移动端视图添加按钮组件
/// 
/// 用于在移动端界面中添加新视图或页面的无状态UI组件。
/// 
/// 功能说明：
/// 1. 显示统一样式的添加按钮图标
/// 2. 使用系统定义的标准尺寸
/// 3. 支持自定义点击回调处理
/// 4. 基于FlowyIconButton实现，继承其基础功能
/// 
/// 使用场景：
/// - 工作空间中添加新页面
/// - 文件夹中添加子项目
/// - 列表界面的添加操作入口
/// - 其他需要添加功能的界面元素
class MobileViewAddButton extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建移动端视图添加按钮组件
  /// 
  /// 参数:
  /// - [onPressed] 按钮点击时的回调函数
  /// 构造函数
  /// 
  /// 创建移动端视图添加按钮组件
  /// 
  /// 参数:
  /// - [onPressed] 按钮点击时的回调函数
  const MobileViewAddButton({
    super.key,
    required this.onPressed,
  });

  /// 按钮点击时的回调函数
  /// 
  /// 当用户点击添加按钮时会调用此函数，
  /// 由调用者实现具体的添加逻辑
  final VoidCallback onPressed;

  /// 构建添加按钮UI
  /// 
  /// 创建一个固定尺寸的圆形图标按钮，显示添加图标。
  /// 使用系统定义的尺寸常量确保与其他按钮保持一致的大小。
  /// 
  /// 尺寸说明：
  /// - 宽度和高度都使用HomeSpaceViewSizes.mViewButtonDimension
  /// - 确保在不同界面中保持统一的视觉效果
  /// - 符合移动端触摸目标的最小尺寸要求
  /// 
  /// 图标说明：
  /// - 使用FlowySvgs.m_space_add_s小尺寸添加图标
  /// - 保持与应用整体图标风格的一致性
  /// 
  /// 返回值: 完整的添加按钮UI组件
  @override
  Widget build(BuildContext context) {
    return FlowyIconButton(
      width: HomeSpaceViewSizes.mViewButtonDimension,   // 使用系统定义的按钮宽度
      height: HomeSpaceViewSizes.mViewButtonDimension,  // 使用系统定义的按钮高度
      icon: const FlowySvg(
        FlowySvgs.m_space_add_s,  // 小尺寸的添加图标
      ),
      onPressed: onPressed,  // 传递用户定义的点击回调
    );
  }
}

/// 移动端视图更多操作按钮组件
/// 
/// 用于在移动端界面中显示更多操作选项的无状态UI组件。
/// 
/// 功能说明：
/// 1. 显示统一样式的更多操作按钮图标
/// 2. 使用与添加按钮相同的尺寸标准，保持界面一致性
/// 3. 支持自定义点击回调处理
/// 4. 通常用于触发上下文菜单或操作面板
/// 
/// 使用场景：
/// - 页面列表项的更多操作入口
/// - 工作空间的设置和管理选项
/// - 文件夹的额外操作功能
/// - 需要显示次要操作的界面元素
/// 
/// 与MobileViewAddButton的区别：
/// - 功能不同：更多操作 vs 添加操作
/// - 图标不同：三个点 vs 加号
/// - 用途不同：展开菜单 vs 创建新项
class MobileViewMoreButton extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建移动端视图更多操作按钮组件
  /// 
  /// 参数:
  /// - [onPressed] 按钮点击时的回调函数，通常用于显示更多操作菜单
  /// 构造函数
  /// 
  /// 创建移动端视图更多操作按钮组件
  /// 
  /// 参数:
  /// - [onPressed] 按钮点击时的回调函数，通常用于显示更多操作菜单
  const MobileViewMoreButton({
    super.key,
    required this.onPressed,
  });

  /// 按钮点击时的回调函数
  /// 
  /// 当用户点击更多按钮时会调用此函数，
  /// 通常用于显示上下文菜单、底部弹窗或其他操作选项
  final VoidCallback onPressed;

  /// 构建更多操作按钮UI
  /// 
  /// 创建一个与添加按钮尺寸相同的更多操作按钮，显示三点图标。
  /// 保持与其他操作按钮的视觉一致性和交互一致性。
  /// 
  /// 设计特点：
  /// - 使用相同的尺寸常量，确保按钮大小统一
  /// - 三点图标暗示有更多隐藏的操作选项
  /// - 点击后通常会触发菜单或弹窗显示
  /// 
  /// 交互模式：
  /// - 通常配合底部弹窗(BottomSheet)使用
  /// - 可以触发上下文菜单(ContextMenu)
  /// - 支持显示操作列表或设置面板
  /// 
  /// 返回值: 完整的更多操作按钮UI组件
  @override
  Widget build(BuildContext context) {
    return FlowyIconButton(
      width: HomeSpaceViewSizes.mViewButtonDimension,   // 与添加按钮使用相同宽度
      height: HomeSpaceViewSizes.mViewButtonDimension,  // 与添加按钮使用相同高度
      icon: const FlowySvg(
        FlowySvgs.m_space_more_s,  // 小尺寸的三点更多图标
      ),
      onPressed: onPressed,  // 传递用户定义的点击回调
    );
  }
}
