/// 空白状态占位符组件
/// 
/// 这个文件定义了在移动端主页中用于显示空状态的占位符组件。
/// 用于最近访问和收藏页面为空时的友好提示显示。
/// 
/// 设计思想：
/// - 提供一致的空状态用户体验
/// - 区分不同类型的空状态（最近访问 vs 收藏）
/// - 使用插画和文字结合的方式提升用户体验
/// - 支持国际化，适配多种语言环境
/// - 为底部导航栏预留空间，避免内容被遮挡

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/home/shared/mobile_page_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 空白空间占位符组件
/// 
/// 无状态UI组件，用于在主页空间中显示空状态提示。
/// 
/// 功能说明：
/// 1. 根据不同的页面类型显示相应的空状态信息
/// 2. 使用大图标插画增强视觉效果
/// 3. 提供主标题和副标题的层次化信息展示
/// 4. 自适应底部导航栏高度，确保内容不被遮挡
/// 
/// 使用场景：
/// - 最近访问页面列表为空时
/// - 收藏页面列表为空时
class EmptySpacePlaceholder extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建空白空间占位符组件
  /// 
  /// 参数:
  /// - [type] 页面卡片类型，决定显示的文案内容
  const EmptySpacePlaceholder({
    super.key,
    required this.type,
  });

  /// 页面卡片类型
  /// 
  /// 用于区分是最近访问还是收藏页面的空状态，
  /// 不同类型会显示不同的提示文案
  final MobilePageCardType type;

  /// 构建空状态占位符UI
  /// 
  /// 创建居中显示的空状态内容，包含插画、主标题和副标题。
  /// 布局采用垂直排列，确保在各种屏幕尺寸下都有良好的显示效果。
  /// 
  /// 布局结构：
  /// - 水平内边距48px，为内容提供呼吸空间
  /// - 大尺寸插画图标，增强视觉吸引力
  /// - 主标题：18px中粗字体，突出重要信息
  /// - 副标题：17px常规字体，提供详细说明
  /// - 底部预留导航栏空间，避免内容被遮挡
  /// 
  /// 返回值: 完整的空状态占位符UI组件
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),  // 左右48px内边距，提供充足留白
      child: Column(
        mainAxisSize: MainAxisSize.min,            // 列高度自适应内容
        mainAxisAlignment: MainAxisAlignment.center,  // 垂直居中对齐
        children: [
          // 大尺寸空页面插画图标，作为视觉焦点
          const FlowySvg(
            FlowySvgs.m_empty_page_xl,  // 超大尺寸的空页面图标
          ),
          const VSpace(16.0),  // 图标和标题间16px垂直间距
          // 主标题：简洁明了地说明当前状态
          FlowyText.medium(
            _emptyPageText,              // 根据页面类型显示相应标题
            fontSize: 18.0,             // 18px字体，突出显示
            textAlign: TextAlign.center, // 文本居中对齐
          ),
          const VSpace(8.0),   // 主副标题间8px垂直间距
          // 副标题：提供更详细的说明和引导
          FlowyText.regular(
            _emptyPageSubText,           // 根据页面类型显示相应描述
            fontSize: 17.0,             // 17px字体，略小于主标题
            maxLines: 10,               // 最多显示10行，支持长文本
            textAlign: TextAlign.center, // 文本居中对齐
            lineHeight: 1.3,            // 1.3倍行高，增加可读性
            color: Theme.of(context).hintColor,  // 使用主题色的提示色
          ),
          // 底部空间：导航栏高度 + 36px额外空间，确保内容不被遮挡
          const VSpace(kBottomNavigationBarHeight + 36.0),
        ],
      ),
    );
  }

  /// 获取空页面主标题文本
  /// 
  /// 根据页面卡片类型返回相应的国际化文本。
  /// 使用switch表达式简洁地处理不同类型的文本映射。
  /// 
  /// 返回值: 对应类型的主标题文本
  String get _emptyPageText => switch (type) {
        MobilePageCardType.recent => LocaleKeys.sideBar_emptyRecent.tr(),      // "最近访问为空" 的国际化文本
        MobilePageCardType.favorite => LocaleKeys.sideBar_emptyFavorite.tr(),  // "收藏为空" 的国际化文本
      };

  /// 获取空页面副标题文本
  /// 
  /// 根据页面卡片类型返回相应的详细描述文本。
  /// 副标题提供更具体的说明和用户引导信息。
  /// 
  /// 返回值: 对应类型的副标题描述文本
  String get _emptyPageSubText => switch (type) {
        MobilePageCardType.recent =>
          LocaleKeys.sideBar_emptyRecentDescription.tr(),    // 最近访问空状态的详细描述
        MobilePageCardType.favorite =>
          LocaleKeys.sideBar_emptyFavoriteDescription.tr(),  // 收藏空状态的详细描述
      };
}
