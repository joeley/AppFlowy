// 导入页面访问级别状态管理
import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端通用组件
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';
// 导入状态管理库
import 'package:provider/provider.dart';

/**
 * 移动端视图项底部弹窗主体操作枚举
 * 
 * 定义了视图项（文档、数据库、文件夹等）的所有可用操作
 * 这些操作是AppFlowy中内容管理的核心功能
 */
enum MobileViewItemBottomSheetBodyAction {
  rename,               // 重命名操作
  duplicate,            // 复制操作
  share,                // 分享操作
  delete,               // 删除操作
  addToFavorites,       // 添加到收藏夹
  removeFromFavorites,  // 从收藏夹移除
  divider,              // 视觉分隔符
  removeFromRecent,     // 从最近访问移除
}

/**
 * 移动端视图项底部弹窗主体组件
 * 
 * 设计思想：
 * 1. **可配置性** - 通过actions列表动态控制显示的操作项
 * 2. **状态感知** - 根据收藏状态、锁定状态等动态调整UI
 * 3. **视觉一致性** - 使用统一的FlowyOptionTile组件
 * 4. **权限管理** - 集成页面访问级别控制，禁用限制操作
 * 
 * 使用场景：
 * - 用户长按文档、文件夹或数据库项目
 * - 显示针对该项目的上下文操作菜单
 * - 适用于移动端的触摸交互
 * 
 * 架构说明：
 * - 使用构建器模式动态生成操作按钮列表
 * - 通过Provider访问页面访问控制状态
 * - 支持条件渲染和状态相关的UI变化
 */
class MobileViewItemBottomSheetBody extends StatelessWidget {
  const MobileViewItemBottomSheetBody({
    super.key,
    this.isFavorite = false,  // 当前项目是否已收藏
    required this.onAction,   // 操作回调函数
    required this.actions,    // 显示的操作列表
  });

  /// 当前项目的收藏状态
  /// 用于决定显示"添加到收藏"还是"从收藏移除"
  final bool isFavorite;
  
  /// 操作回调函数
  /// 当用户点击某个操作时，会调用此函数并传入对应的操作类型
  final void Function(MobileViewItemBottomSheetBodyAction action) onAction;
  
  /// 显示的操作列表
  /// 允许不同上下文下显示不同的操作选项
  /// 例如：最近访问列表中不显示删除选项
  final List<MobileViewItemBottomSheetBodyAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      // 伸展占满整个宽度，提供更大的触摸区域
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // 动态构建操作按钮列表
      // 根据actions配置动态显示不同的操作选项
      children:
          actions.map((action) => _buildActionButton(context, action)).toList(),
    );
  }

  /// 构建单个操作按钮
  /// 
  /// 根据操作类型创建对应的UI组件，并处理权限控制
  /// @param context 构建上下文
  /// @param action 操作类型枚举
  /// @return 对应的操作按钮Widget
  Widget _buildActionButton(
    BuildContext context,
    MobileViewItemBottomSheetBodyAction action,
  ) {
    // 检查当前页面是否被锁定（只读模式）
    // 从PageAccessLevelBloc获取锁定状态，如果Bloc不存在则默认为未锁定
    final isLocked =
        context.read<PageAccessLevelBloc?>()?.state.isLocked ?? false;
    
    // 根据操作类型构建不同的按钮UI
    switch (action) {
      // ===== 重命名操作 =====
      case MobileViewItemBottomSheetBodyAction.rename:
        return FlowyOptionTile.text(
          text: LocaleKeys.button_rename.tr(),
          height: 52.0,                           // 统一的按钮高度，适合触摸操作
          leftIcon: const FlowySvg(
            FlowySvgs.view_item_rename_s,          // 重命名图标
            size: Size.square(18),
          ),
          enable: !isLocked,                      // 锁定状态下禁用重命名
          showTopBorder: false,                   // 不显示顶部边框，保持清洁
          showBottomBorder: false,                // 不显示底部边框
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.rename,
          ),
        );
      // ===== 复制操作 =====
      case MobileViewItemBottomSheetBodyAction.duplicate:
        return FlowyOptionTile.text(
          text: LocaleKeys.button_duplicate.tr(),
          height: 52.0,
          leftIcon: const FlowySvg(
            FlowySvgs.duplicate_s,                // 复制图标
            size: Size.square(18),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.duplicate,
          ),
        );

      // ===== 分享操作 =====
      case MobileViewItemBottomSheetBodyAction.share:
        return FlowyOptionTile.text(
          text: LocaleKeys.button_share.tr(),
          height: 52.0,
          leftIcon: const FlowySvg(
            FlowySvgs.share_s,                   // 分享图标
            size: Size.square(18),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.share,
          ),
        );
      // ===== 删除操作 =====
      case MobileViewItemBottomSheetBodyAction.delete:
        return FlowyOptionTile.text(
          text: LocaleKeys.button_delete.tr(),
          height: 52.0,
          // 使用主题的错误颜色，警示用户这是危险操作
          textColor: Theme.of(context).colorScheme.error,
          leftIcon: FlowySvg(
            FlowySvgs.trash_s,                   // 垃圾桶图标
            size: const Size.square(18),
            // 图标也使用错误颜色，保持一致性
            color: Theme.of(context).colorScheme.error,
          ),
          enable: !isLocked,                   // 锁定状态下禁用删除
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.delete,
          ),
        );
      // ===== 添加到收藏操作 =====
      case MobileViewItemBottomSheetBodyAction.addToFavorites:
        return FlowyOptionTile.text(
          height: 52.0,
          text: LocaleKeys.button_addToFavorites.tr(),
          leftIcon: const FlowySvg(
            FlowySvgs.favorite_s,                // 收藏图标（空心）
            size: Size.square(18),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.addToFavorites,
          ),
        );
      // ===== 从收藏移除操作 =====
      case MobileViewItemBottomSheetBodyAction.removeFromFavorites:
        return FlowyOptionTile.text(
          height: 52.0,
          text: LocaleKeys.button_removeFromFavorites.tr(),
          leftIcon: const FlowySvg(
            // 从收藏移除的专用图标（实心收藏图标或带删除标记）
            FlowySvgs.favorite_section_remove_from_favorite_s,
            size: Size.square(18),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.removeFromFavorites,
          ),
        );
      // ===== 从最近访问移除操作 =====
      case MobileViewItemBottomSheetBodyAction.removeFromRecent:
        return FlowyOptionTile.text(
          height: 52.0,
          text: LocaleKeys.button_removeFromRecent.tr(),
          leftIcon: const FlowySvg(
            FlowySvgs.remove_from_recent_s,      // 从最近访问移除的图标
            size: Size.square(18),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(
            MobileViewItemBottomSheetBodyAction.removeFromRecent,
          ),
        );

      // ===== 视觉分隔符 =====
      case MobileViewItemBottomSheetBodyAction.divider:
        return const Padding(
          // 水平内边距，让分割线与按钮内容对齐
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Divider(height: 0.5),        // 极细的分割线
        );
    }
  }
}
