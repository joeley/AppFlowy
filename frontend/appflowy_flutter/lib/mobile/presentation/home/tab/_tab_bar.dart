import 'package:appflowy/mobile/presentation/home/tab/_round_underline_tab_indicator.dart';
import 'package:appflowy/mobile/presentation/home/tab/space_order_bloc.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

/// 移动端空间Tab栏
/// 
/// 功能说明：
/// 1. 显示可重新排序的Tab标签
/// 2. 支持自定义样式和指示器
/// 3. 使用圆角下划线指示器
/// 4. 支持拖拽重新排序
/// 
/// 使用场景：
/// - 移动端主页的顶部导航
/// - 空间切换导航
/// - 支持用户自定义排序
class MobileSpaceTabBar extends StatelessWidget {
  const MobileSpaceTabBar({
    super.key,
    this.height = 38.0,
    required this.tabController,
    required this.tabs,
    required this.onReorder,
  });

  /// Tab栏高度
  final double height;
  
  /// Tab类型列表
  final List<MobileSpaceTabType> tabs;
  
  /// Tab控制器
  final TabController tabController;
  
  /// 重新排序回调
  final OnReorder onReorder;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    
    // 选中标签的文本样式
    final labelStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 16.0,
      height: 22.0 / 16.0,  // 行高
    );
    
    // 未选中标签的文本样式
    final unselectedLabelStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w400,
      fontSize: 15.0,
      height: 22.0 / 15.0,  // 行高
    );

    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 8.0),
      child: ReorderableTabBar(
        controller: tabController,
        // 将Tab类型转换为Tab组件，使用本地化文本
        tabs: tabs.map((e) => Tab(text: e.tr)).toList(),
        indicatorSize: TabBarIndicatorSize.label,  // 指示器大小跟随标签
        indicatorColor: Theme.of(context).primaryColor,
        isScrollable: true,  // 允许横向滚动
        labelStyle: labelStyle,
        labelColor: baseStyle?.color,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12.0),
        unselectedLabelStyle: unselectedLabelStyle,
        overlayColor: WidgetStateProperty.all(Colors.transparent),  // 点击时无水波纹效果
        // 使用自定义的圆角下划线指示器
        indicator: RoundUnderlineTabIndicator(
          width: 28.0,  // 固定宽度
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 3,  // 线条粗细
          ),
        ),
        onReorder: onReorder,  // 拖拽重新排序回调
      ),
    );
  }
}
