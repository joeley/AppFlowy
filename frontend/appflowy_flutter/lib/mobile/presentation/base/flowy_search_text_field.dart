import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 移动端搜索文本输入框组件
/// 
/// 提供统一风格的搜索输入框，基于Cupertino设计语言打造原生iOS体验。
/// 封装了CupertinoSearchTextField，并自定义了图标、样式和交互行为。
/// 
/// 设计思想：
/// 1. **平台一致性**：使用Cupertino组件保持与iOS原生应用的一致体验
/// 2. **视觉统一**：通过自定义图标和样式与AppFlowy设计系统保持一致
/// 3. **易用性**：提供简洁的API，隐藏复杂的样式配置
/// 4. **响应式设计**：自动适配主题变化，支持深浅色模式
/// 
/// 使用场景：
/// - 页面级搜索：在文档、数据库等页面提供内容搜索
/// - 快速过滤：在列表页面实现实时过滤功能
/// - 全局搜索：作为应用级搜索入口的输入框
/// - 命令面板：支持快捷命令的输入和执行
class FlowySearchTextField extends StatelessWidget {
  /// 创建一个搜索文本输入框
  /// 
  /// [hintText] 占位符文本，提示用户输入内容
  /// [controller] 文本控制器，用于外部控制和获取输入内容
  /// [onChanged] 文本变化回调，支持实时搜索
  /// [onSubmitted] 提交回调，用户按下搜索键时触发
  const FlowySearchTextField({
    super.key,
    this.hintText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  /// 占位符文本，当输入框为空时显示
  /// 用于提示用户输入的内容类型或格式
  final String? hintText;
  
  /// 文本控制器，管理输入框的文本内容
  /// 允许外部读取或修改输入框的值
  final TextEditingController? controller;
  
  /// 文本变化回调函数
  /// 每次输入内容改变时触发，适合实现实时搜索功能
  final ValueChanged<String>? onChanged;
  
  /// 提交回调函数
  /// 用户点击键盘搜索按钮或按下回车键时触发
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 固定高度44像素，符合移动端标准触摸目标大小
      // 确保在不同设备上保持一致的视觉效果
      height: 44.0,
      child: CupertinoSearchTextField(
        // 基础配置：连接控制器和回调函数
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        placeholder: hintText,
        
        // 前缀图标配置：使用自定义的搜索图标
        // FlowySvg确保图标在不同主题下正确显示
        prefixIcon: const FlowySvg(FlowySvgs.m_search_m),
        // 左侧留出更多空间，右侧减少间距，优化视觉平衡
        prefixInsets: const EdgeInsets.only(left: 16.0, right: 2.0),
        
        // 后缀图标配置：清除按钮
        // 使用系统标准的关闭图标，用户熟悉度高
        suffixIcon: const Icon(Icons.close),
        // 右侧保持合适的边距，确保可点击区域足够大
        suffixInsets: const EdgeInsets.only(right: 16.0),
        
        // 占位符样式配置
        // 使用主题的titleSmall样式作为基础，确保与应用整体风格一致
        placeholderStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
              // 使用主题的提示颜色，在深浅模式下自动适配
              color: Theme.of(context).hintColor,
              // 使用较轻的字重，区别于实际输入内容
              fontWeight: FontWeight.w400,
              // 14像素字体大小，保证可读性
              fontSize: 14.0,
            ),
      ),
    );
  }
}
