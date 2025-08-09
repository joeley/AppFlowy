/// AppFlowy移动端日历事件空状态组件
/// 
/// 这个文件定义了当日历视图中没有事件时的空状态显示组件。
/// 提供了简洁的提示信息，帮助用户理解当前状态

import 'package:flutter/material.dart';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';

/// 移动端日历事件空状态组件
/// 
/// 这是一个无状态的UI组件，用于在日历视图中显示空状态。
/// 主要用途：
/// - 当某个日期没有事件时显示
/// - 当筛选条件下没有匹配的事件时显示
/// - 为用户提供友好的空状态提示
/// 
/// 设计思想：
/// - 采用简洁的中心对齐布局
/// - 使用主标题和副标题的层次结构
/// - 支持国际化，适配不同语言环境
class MobileCalendarEventsEmpty extends StatelessWidget {
  const MobileCalendarEventsEmpty({super.key});

  /// 构建空状态组件的UI
  /// 
  /// 布局结构：
  /// - 外层使用Center实现居中对齐
  /// - 内层使用Column垂直排列标题和描述
  /// - 适当的内边距和间距控制
  @override
  Widget build(BuildContext context) {
    return Center( // 居中显示整个空状态内容
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // 上下12px，左右16px内边距
        child: Column(
          mainAxisSize: MainAxisSize.min, // 列高度自适应内容
          children: [
            // 主标题：显示空状态的主要描述
            FlowyText(
              LocaleKeys.calendar_mobileEventScreen_emptyTitle.tr(), // 国际化文本
              fontWeight: FontWeight.w700, // 加粗字体
              fontSize: 14,                // 14px字体大小
            ),
            const VSpace(8), // 在8px的垂直间距
            // 副标题：提供更详细的说明信息
            FlowyText.regular(
              LocaleKeys.calendar_mobileEventScreen_emptyBody.tr(), // 国际化文本
              textAlign: TextAlign.center, // 文本居中对齐
              maxLines: 2,                 // 最多显示2行
            ),
          ],
        ),
      ),
    );
  }
}
