// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入iOS风格的UI组件
import 'package:flutter/cupertino.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * AppFlowy移动端搜索文本输入框组件
 * 
 * 设计思想：
 * 1. **原生体验** - 使用iOS原生CupertinoSearchTextField组件
 * 2. **视觉一致** - 统一的搜索框样式和图标设计
 * 3. **灵活配置** - 支持自定义提示文本、回调等
 * 4. **主题适配** - 自动适配应用主题的文本样式
 * 
 * 使用场景：
 * - 文档和页面的搜索功能
 * - 数据库表格的筛选和搜索
 * - 用户在内容中快速寻找特定信息
 * - 任何需要搜索输入的场景
 * 
 * 交互特性：
 * - 支持实时搜索（onChanged）
 * - 支持回车搜索（onSubmitted）
 * - 自带清除按钮，方便用户清空输入
 * - 视觉反馈清晰，符合移动端交互规范
 * 
 * 架构说明：
 * - 使用SizedBox控制固定高度，保证布局稳定性
 * - 传递controller给父组件管理文本内容
 * - 图标和样式统一管理，保持视觉一致性
 */
class FlowyMobileSearchTextField extends StatelessWidget {
  const FlowyMobileSearchTextField({
    super.key,
    this.hintText,     // 提示文本，显示在输入框为空时
    this.controller,   // 文本编辑控制器，管理输入内容
    this.onChanged,    // 文本变化回调，实时搜索时使用
    this.onSubmitted,  // 提交回调，用户按回车键时触发
  });

  /// 提示文本
  /// 在输入框为空时显示，指导用户输入内容
  /// 例如："搜索文档"、"输入关键词"等
  final String? hintText;
  
  /// 文本编辑控制器
  /// 由父组件传入并管理，用于控制输入内容和光标位置
  final TextEditingController? controller;
  
  /// 文本内容变化回调
  /// 在用户输入每个字符时触发，适合实时搜索功能
  final ValueChanged<String>? onChanged;
  
  /// 提交回调
  /// 用户点击软键盘的“搜索”或“完成”按钮时触发
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 固定高度，符合iOS设计规范，保证布局稳定性
      height: 44.0,
      child: CupertinoSearchTextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        // 显示在输入框内的提示文本
        placeholder: hintText,
        
        // ===== 前缀图标设置 =====
        // 使用AppFlowy的搜索图标，保持视觉一致性
        prefixIcon: const FlowySvg(FlowySvgs.m_search_m),
        // 前缀图标的内边距：左侧16px留白，右2px与文本分开
        prefixInsets: const EdgeInsets.only(left: 16.0, right: 2.0),
        
        // ===== 后缀图标设置 =====
        // 清除按钮，允许用户快速清空输入内容
        suffixIcon: const Icon(Icons.close),
        // 后缀图标的内边距：右16px留白
        suffixInsets: const EdgeInsets.only(right: 16.0),
        
        // ===== 样式设置 =====
        // 提示文本样式：使用主题的提示颜色，显示为灰色
        placeholderStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).hintColor,  // 使用主题的提示颜色
              fontWeight: FontWeight.w400,         // 中等粗细
              fontSize: 14.0,                      // 14px字体大小
            ),
        // 输入文本样式：使用主题的正文颜色
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color, // 主题正文颜色
              fontWeight: FontWeight.w400,                          // 与提示文本保持一致
              fontSize: 14.0,                                       // 相同字体大小
            ),
      ),
    );
  }
}
