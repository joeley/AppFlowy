import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/database/widgets/cell_editor/extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';
import 'package:flowy_infra/size.dart';
import 'package:flutter/material.dart';

/// 选项颜色选择器组件
/// 
/// 提供一个美观的颜色网格选择器，专门用于数据库视图中的选项颜色选择。
/// 支持单选模式，显示所有可用颜色并突出显示当前选中颜色。
/// 
/// 设计思想：
/// 1. **网格布局**：使用6列网格，在移动端屏幕上提供最佳的空间利用率
/// 2. **视觉反馈**：通过边框粗细和勾选图标清晰指示选中状态
/// 3. **数据驱动**：基于Protocol Buffer定义的颜色枚举，确保与后端一致
/// 4. **交互优化**：通过禁用滚动和shrinkWrap优化在弹窗中的使用体验
/// 
/// 使用场景：
/// - 数据库标签颜色选择：为单选/多选字段的选项设置颜色
/// - 看板卡片颜色：为看板视图中的卡片设置分类颜色
/// - 日历事件标记：为日历视图中的事件设置颜色标记
/// - 状态指示器：作为状态或优先级的可视化标识
class OptionColorList extends StatelessWidget {
  /// 创建一个选项颜色选择器
  /// 
  /// [selectedColor] 当前选中的颜色，用于显示选中状态
  /// [onSelectedColor] 颜色选择回调，当用户点击颜色时触发
  const OptionColorList({
    super.key,
    this.selectedColor,
    required this.onSelectedColor,
  });

  /// 当前选中的颜色
  /// 使用Protocol Buffer定义的颜色枚举，确保与后端数据一致
  final SelectOptionColorPB? selectedColor;
  
  /// 颜色选择回调函数
  /// 当用户点击某个颜色时触发，传递选中的颜色枚举值
  final void Function(SelectOptionColorPB color) onSelectedColor;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      // 6列布局：在移动端屏幕上提供最佳的显示效果
      // 每行6个颜色，既不会太拥挤也不会太稀疏
      crossAxisCount: 6,
      
      // shrinkWrap: 让GridView根据内容自适应高度
      // 适合在弹窗或列表中使用，避免占用过多空间
      shrinkWrap: true,
      
      // 禁用滚动：因为通常在可滚动的弹窗中使用
      // 避免滚动冲突，提供更好的用户体验
      physics: const NeverScrollableScrollPhysics(),
      
      // 移除默认内边距，充分利用可用空间
      padding: EdgeInsets.zero,
      
      // 遍历所有可用颜色，为每个颜色创建一个可点击的颜色块
      children: SelectOptionColorPB.values.map(
        (colorPB) {
          // 将Protocol Buffer颜色枚举转换为实际的Flutter颜色
          // toColor方法会根据主题返回适合的颜色值
          final color = colorPB.toColor(context);
          
          // 判断当前颜色是否被选中
          // 通过比较枚举值来确定选中状态
          final isSelected = selectedColor?.value == colorPB.value;
          
          return GestureDetector(
            // 点击时触发颜色选择回调
            onTap: () => onSelectedColor(colorPB),
            child: Container(
              // 为每个颜色块添加8像素的间距
              // 确保颜色块之间有适当的分隔，提高可辨识度
              margin: const EdgeInsets.all(
                8.0,
              ),
              decoration: BoxDecoration(
                // 设置颜色块的背景颜色
                color: color,
                
                // 使用12像素圆角，提供柔和的视觉效果
                borderRadius: Corners.s12Border,
                
                // 边框设置：选中状态使用更粗的边框
                border: Border.all(
                  // 选中时2像素粗边框，未选中1像素细边框
                  width: isSelected ? 2.0 : 1.0,
                  // 选中时使用鲜艳的青色，未选中使用分割线颜色
                  color: isSelected
                      ? const Color(0xff00C6F1)  // AppFlowy主题色
                      : Theme.of(context).dividerColor,
                ),
              ),
              alignment: Alignment.center,
              
              // 选中状态显示勾选图标
              // 提供明确的视觉反馈，增强可访问性
              child: isSelected
                  ? const FlowySvg(
                      FlowySvgs.m_blue_check_s,  // 蓝色勾选图标
                      size: Size.square(28.0),    // 28像素正方形
                      blendMode: null,             // 不使用混合模式
                    )
                  : null,  // 未选中时不显示图标
            ),
          );
        },
      ).toList(),
    );
  }
}
