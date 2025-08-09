/// 类型选项菜单组件
/// 
/// 这个文件定义了移动端的类型选项菜单系统，用于显示各种类型选项的网格菜单。
/// 主要用于数据库字段类型选择、页面类型选择等场景。
/// 
/// 设计思想：
/// - 采用泛型设计，支持任意类型的值
/// - 网格布局，提供直观的视觉选择体验
/// - 高度可定制化，支持图标、文本、背景色等定制
/// - 响应式缩放，适配不同屏幕尺寸

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 类型选项菜单项值模型
/// 
/// 泛型数据类用于封装菜单项的所有属性和行为。
/// 每个菜单项包含值、图标、文本、背景色和点击回调等信息。
/// 
/// 功能特点：
/// - 支持泛型值，可以存储任意类型的数据
/// - 包含视觉元素（图标、文本、背景色）
/// - 支持自定义图标内边距
/// - 提供点击回调，传递上下文和值
class TypeOptionMenuItemValue<T> {
  /// 构造函数
  /// 
  /// 创建一个类型选项菜单项值对象
  /// 
  /// 参数:
  /// - [value] 菜单项对应的值，可以是任意类型T
  /// - [icon] 显示的SVG图标数据
  /// - [text] 显示的文本标签
  /// - [backgroundColor] 图标容器的背景色
  /// - [onTap] 点击时的回调函数，接收BuildContext和值
  /// - [iconPadding] 可选的图标内边距调整
  const TypeOptionMenuItemValue({
    required this.value,
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.onTap,
    this.iconPadding,
  });

  /// 菜单项对应的值，泛型T可以是任意类型
  final T value;
  /// 显示的SVG图标数据
  final FlowySvgData icon;
  /// 显示的文本标签
  final String text;
  /// 图标容器的背景色
  final Color backgroundColor;
  /// 可选的图标内边距调整
  final EdgeInsets? iconPadding;
  /// 点击时的回调函数，接收BuildContext和对应的值
  final void Function(BuildContext context, T value) onTap;
}

/// 类型选项菜单主组件
/// 
/// 显示类型选项的网格菜单，是整个类型选择系统的容器组件。
/// 
/// 功能说明：
/// 1. 接收菜单项值列表，自动生成网格布局
/// 2. 支持自定义网格列数、间距、尺寸等参数
/// 3. 支持缩放因子，适配不同屏幕密度
/// 4. 使用TypeOptionGridView进行实际的网格布局
/// 
/// 设计思想：
/// - 将数据和展示分离，专注于数据到UI的转换
/// - 提供丰富的布局参数，支持不同使用场景
/// - 通过泛型支持任意类型的值传递
class TypeOptionMenu<T> extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建类型选项菜单组件
  /// 
  /// 参数:
  /// - [values] 菜单项值列表，包含所有要显示的选项
  /// - [width] 每个菜单项的宽度，默认98px
  /// - [iconWidth] 图标容器的宽度，默认72px
  /// - [scaleFactor] 缩放因子，用于适配不同屏幕密度，默认1.0
  /// - [maxAxisSpacing] 最大主轴间距，默认18px
  /// - [crossAxisCount] 交叉轴（横向）菜单项数量，默认3列
  const TypeOptionMenu({
    super.key,
    required this.values,
    this.width = 98,
    this.iconWidth = 72,
    this.scaleFactor = 1.0,
    this.maxAxisSpacing = 18,
    this.crossAxisCount = 3,
  });

  /// 菜单项值列表，包含所有要显示的选项数据
  final List<TypeOptionMenuItemValue<T>> values;

  /// 图标容器的宽度，影响圆形背景的大小
  final double iconWidth;
  /// 每个菜单项的总宽度，包含图标和文本
  final double width;
  /// 缩放因子，用于响应式适配不同屏幕密度
  final double scaleFactor;
  /// 主轴（垂直）间距的最大值
  final double maxAxisSpacing;
  /// 交叉轴（水平）每行显示的菜单项数量
  final int crossAxisCount;

  /// 构建菜单UI
  /// 
  /// 将菜单项值列表转换为菜单项组件列表，并使用网格视图进行布局。
  /// 所有尺寸参数都会根据缩放因子进行调整。
  /// 
  /// 返回值: 包含所有菜单项的网格视图组件
  @override
  Widget build(BuildContext context) {
    return TypeOptionGridView(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: maxAxisSpacing * scaleFactor,  // 应用缩放因子到间距
      itemWidth: width * scaleFactor,                  // 应用缩放因子到宽度
      children: values
          .map(
            (value) => TypeOptionMenuItem<T>(
              value: value,                    // 传递菜单项值
              width: width,                    // 菜单项宽度
              iconWidth: iconWidth,            // 图标容器宽度
              scaleFactor: scaleFactor,        // 缩放因子
              iconPadding: value.iconPadding,  // 图标内边距
            ),
          )
          .toList(),
    );
  }
}

/// 类型选项菜单项组件
/// 
/// 单个菜单选项的UI实现，包含圆形图标容器和文本标签。
/// 
/// 功能说明：
/// 1. 显示圆形背景的图标
/// 2. 在图标下方显示文本标签
/// 3. 支持点击交互，触发回调函数
/// 4. 支持缩放和响应式适配
/// 
/// 设计思想：
/// - 采用垂直布局，图标在上，文本在下
/// - 圆形图标背景增强视觉识别
/// - 文本支持多行显示和溢出省略
/// - 通过GestureDetector处理用户交互
class TypeOptionMenuItem<T> extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建类型选项菜单项组件
  /// 
  /// 参数:
  /// - [value] 菜单项值对象，包含所有显示和交互数据
  /// - [width] 菜单项的总宽度，默认94px
  /// - [iconWidth] 图标容器的宽度，默认72px
  /// - [scaleFactor] 缩放因子，用于响应式适配，默认1.0
  /// - [iconPadding] 可选的图标内边距调整
  const TypeOptionMenuItem({
    super.key,
    required this.value,
    this.width = 94,
    this.iconWidth = 72,
    this.scaleFactor = 1.0,
    this.iconPadding,
  });

  /// 菜单项值对象，包含显示内容和交互回调
  final TypeOptionMenuItemValue<T> value;
  /// 图标容器的基础宽度
  final double iconWidth;
  /// 菜单项的基础总宽度
  final double width;
  /// 缩放因子，用于响应式适配
  final double scaleFactor;
  /// 可选的图标内边距调整
  final EdgeInsets? iconPadding;

  /// 获取应用缩放因子后的图标宽度
  double get scaledIconWidth => iconWidth * scaleFactor;
  /// 获取应用缩放因子后的总宽度
  double get scaledWidth => width * scaleFactor;

  /// 构建菜单项UI
  /// 
  /// 创建包含圆形图标容器和文本标签的垂直布局。
  /// 整个组件可点击，点击时会触发value中定义的回调函数。
  /// 
  /// 布局结构：
  /// - 圆形图标容器（可缩放）
  /// - 6px垂直间距
  /// - 受约束的文本标签（最多2行，居中对齐）
  /// 
  /// 返回值: 可交互的菜单项UI组件
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 点击时触发回调，传递上下文和对应的值
      onTap: () => value.onTap(context, value.value),
      child: Column(
        children: [
          // 圆形图标容器
          Container(
            height: scaledIconWidth,
            width: scaledIconWidth,
            decoration: ShapeDecoration(
              color: value.backgroundColor,  // 使用值中定义的背景色
              shape: RoundedRectangleBorder(
                // 圆角半径也应用缩放因子，保持比例
                borderRadius: BorderRadius.circular(24 * scaleFactor),
              ),
            ),
            // 内边距：基础21px + 可选的额外内边距
            padding: EdgeInsets.all(21 * scaleFactor) +
                (iconPadding ?? EdgeInsets.zero),
            child: FlowySvg(
              value.icon,  // 显示值中定义的图标
            ),
          ),
          const VSpace(6),  // 固定6px的垂直间距
          // 受约束的文本容器，防止文本超出边界
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: scaledWidth,  // 最大宽度为缩放后的宽度
            ),
            child: FlowyText(
              value.text,                        // 显示值中定义的文本
              fontSize: 14.0,                    // 14px字体大小
              maxLines: 2,                       // 最多显示2行
              lineHeight: 1.0,                   // 行高为1倍
              overflow: TextOverflow.ellipsis,   // 超出时显示省略号
              textAlign: TextAlign.center,       // 居中对齐
            ),
          ),
        ],
      ),
    );
  }
}

/// 类型选项网格视图组件
/// 
/// 自定义的网格布局组件，用于显示类型选项菜单项的网格排列。
/// 与Flutter内置的GridView不同，这个组件更加轻量和可控。
/// 
/// 功能说明：
/// 1. 按指定的列数将子组件排列成网格
/// 2. 支持自定义主轴间距
/// 3. 每行不足的位置用占位空间填充
/// 4. 使用Column和Row的组合实现网格效果
/// 
/// 设计思想：
/// - 避免使用复杂的GridView，提供更直接的布局控制
/// - 通过循环生成行，每行包含固定数量的列
/// - 空位置使用HSpace填充，保持对齐效果
class TypeOptionGridView extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建类型选项网格视图组件
  /// 
  /// 参数:
  /// - [children] 要在网格中显示的子组件列表
  /// - [crossAxisCount] 交叉轴（水平方向）的列数
  /// - [mainAxisSpacing] 主轴（垂直方向）的间距
  /// - [itemWidth] 每个网格项的宽度，用于空位置占位
  const TypeOptionGridView({
    super.key,
    required this.children,
    required this.crossAxisCount,
    required this.mainAxisSpacing,
    required this.itemWidth,
  });

  /// 要在网格中显示的子组件列表
  final List<Widget> children;
  /// 交叉轴（水平方向）每行显示的列数
  final int crossAxisCount;
  /// 主轴（垂直方向）行与行之间的间距
  final double mainAxisSpacing;
  /// 每个网格项的宽度，用于空位置的占位计算
  final double itemWidth;

  /// 构建网格视图UI
  /// 
  /// 使用Column包含多个Row来实现网格效果。
  /// 每行包含crossAxisCount个项目，不足的位置用HSpace填充。
  /// 
  /// 算法逻辑：
  /// 1. 外层循环按crossAxisCount步长遍历children
  /// 2. 每次循环创建一行，包含最多crossAxisCount个项目
  /// 3. 内层循环填充当前行，空位置用HSpace占位
  /// 4. 每行之间添加mainAxisSpacing间距
  /// 
  /// 返回值: 网格布局的Column组件
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,  // 列高度自适应内容
      children: [
        // 外层循环：按列数步长遍历所有子组件
        for (var i = 0; i < children.length; i += crossAxisCount)
          Padding(
            padding: EdgeInsets.only(bottom: mainAxisSpacing),  // 行间距
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,       // 顶部对齐
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // 两端对齐
              children: [
                // 内层循环：填充当前行的列
                for (var j = 0; j < crossAxisCount; j++)
                  i + j < children.length
                      ? // 有子组件时：用SizedBox包装确保固定宽度
                        SizedBox(
                          width: itemWidth,
                          child: children[i + j],
                        )
                      : // 空位置时：用HSpace占位保持对齐
                        HSpace(itemWidth),
              ],
            ),
          ),
      ],
    );
  }
}
