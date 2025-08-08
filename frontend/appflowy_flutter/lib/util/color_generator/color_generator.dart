/*
 * 颜色生成器工具
 * 
 * 设计理念：
 * 基于字符串内容生成确定性的颜色值。
 * 相同的字符串总是生成相同的颜色，确保UI一致性。
 * 
 * 使用场景：
 * - 用户头像背景色生成
 * - 标签和分类的颜色分配
 * - 任何需要基于内容生成颜色的场景
 * 
 * 特点：
 * 1. 确定性：相同输入产生相同输出
 * 2. 分布均匀：颜色在色相环上均匀分布
 * 3. 预设颜色：提供精心挑选的颜色组合
 */

import 'package:flutter/material.dart';

/* 
 * 预设颜色集合
 * 
 * AI生成的颜色对，每对包含：
 * - 主色：深色，用于文字或图标
 * - 背景色：浅色，用于背景
 * 
 * 颜色设计原则：
 * - 高对比度确保可读性
 * - 柔和的背景色避免视觉疲劳
 * - 覆盖多种色相提供丰富选择
 */
final _builtInColorSet = [
  (const Color(0xFF8A2BE2), const Color(0xFFF0E6FF)),  /* 紫罗兰色 */
  (const Color(0xFF2E8B57), const Color(0xFFE0FFF0)),  /* 海洋绿 */
  (const Color(0xFF1E90FF), const Color(0xFFE6F3FF)),  /* 道奇蓝 */
  (const Color(0xFFFF7F50), const Color(0xFFFFF0E6)),  /* 珊瑚色 */
  (const Color(0xFFFF69B4), const Color(0xFFFFE6F0)),  /* 热粉红 */
  (const Color(0xFF20B2AA), const Color(0xFFE0FFFF)),  /* 浅海洋绿 */
  (const Color(0xFFDC143C), const Color(0xFFFFE6E6)),  /* 深红色 */
  (const Color(0xFF8B4513), const Color(0xFFFFF0E6)),  /* 马鞍棕 */
];

/*
 * 颜色生成器扩展类型
 * 
 * 基于字符串值生成颜色的工具类。
 * 使用extension type提供零成本抽象。
 * 
 * 核心方法：
 * 1. toColor：生成HSL颜色
 * 2. randomColor：从预设集合选择颜色
 */
extension type ColorGenerator(String value) {
  /*
   * 生成HSL颜色
   * 
   * 算法说明：
   * 1. 计算字符串的哈希值（所有字符码点之和）
   * 2. 将哈希值映射到0-360度的色相值
   * 3. 固定饱和度和亮度，生成柔和的颜色
   * 
   * HSL参数：
   * - H(色相)：0-360度，由哈希值决定
   * - S(饱和度)：0.5，中等饱和度
   * - L(亮度)：0.8，偏亮的颜色
   * 
   * 返回：生成的颜色对象
   */
  Color toColor() {
    /* 计算字符串哈希值 */
    final int hash = value.codeUnits.fold(0, (int acc, int unit) => acc + unit);
    /* 映射到色相值（0-360度） */
    final double hue = (hash % 360).toDouble();
    /* 生成HSL颜色并转换为RGB */
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.8).toColor();
  }

  /*
   * 从预设集合选择颜色
   * 
   * 算法说明：
   * 1. 计算字符串哈希值
   * 2. 使用模运算映射到预设颜色索引
   * 3. 返回对应的颜色对
   * 
   * 特点：
   * - 相同名称总是返回相同颜色
   * - 提供主色和背景色的配对
   * - 颜色经过精心设计，视觉效果更佳
   * 
   * 返回：(主色, 背景色) 元组
   */
  (Color, Color) randomColor() {
    /* 计算哈希值 */
    final hash = value.codeUnits.fold(0, (int acc, int unit) => acc + unit);
    /* 映射到颜色索引 */
    final index = hash % _builtInColorSet.length;
    /* 返回颜色对 */
    return _builtInColorSet[index];
  }
}
