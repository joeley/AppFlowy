// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端通用组件
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
// 导入后端protobuf定义的文件夹类型
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * 添加新页面的底部弹窗组件
 * 
 * 设计思想：
 * 1. **快速创建** - 提供一个直观的界面让用户快速选择要创建的页面类型
 * 2. **类型全面** - 支持AppFlowy中的所有主要页面类型
 * 3. **视觉直观** - 每个选项都有相应的图标和本地化名称
 * 4. **一致性** - 使用统一的FlowyOptionTile组件保证视觉一致
 * 
 * 使用场景：
 * - 用户在文件夹或工作区中点击"添加新页面"时
 * - 提供一个简洁的选择界面，让用户选择页面类型
 * - 在移动端的触摸交互中特别有用
 * 
 * 支持的页面类型：
 * - Document: 文档页面（丰富文本编辑）
 * - Grid: 表格页面（数据表格）
 * - Board: 看板页面（卡片式任务管理）
 * - Calendar: 日历页面（日程和事件管理）
 * - Chat: 聊天页面（AI对话）
 * 
 * 架构说明：
 * - 接收一个父级ViewPB对象，表示将在哪个容器下创建新页面
 * - 通过回调函数返回用户选择的页面类型
 * - 父组件负责处理具体的创建逻辑
 */
class AddNewPageWidgetBottomSheet extends StatelessWidget {
  const AddNewPageWidgetBottomSheet({
    super.key,
    required this.view,        // 父级视图对象，新页面将创建在此视图下
    required this.onAction,    // 页面类型选择回调函数
  });

  /// 父级视图对象
  /// 表示将在哪个容器（文件夹或工作区）下创建新页面
  final ViewPB view;
  
  /// 页面类型选择回调函数
  /// 当用户选择某个页面类型时，会调用此函数并传入对应的ViewLayoutPB
  final void Function(ViewLayoutPB layout) onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ===== 文档页面类型 =====
        // 丰富文本编辑器，支持标题、段落、列表、代码块等各种内容类型
        FlowyOptionTile.text(
          text: LocaleKeys.document_menuName.tr(),  // 国际化文档名称
          height: 52.0,                           // 统一的选项高度，适合触摸操作
          leftIcon: const FlowySvg(
            FlowySvgs.icon_document_s,            // 文档图标
            size: Size.square(20),                // 统一的图标尺寸
          ),
          showTopBorder: false,                  // 不显示顶部边框，保持清洁外观
          showBottomBorder: false,               // 不显示底部边框
          onTap: () => onAction(ViewLayoutPB.Document), // 选择文档类型
        ),
        
        // ===== 表格页面类型 =====
        // 结构化数据管理，支持行列操作、排序、过滤等数据库功能
        FlowyOptionTile.text(
          text: LocaleKeys.grid_menuName.tr(),
          height: 52.0,
          leftIcon: const FlowySvg(
            FlowySvgs.icon_grid_s,               // 表格图标
            size: Size.square(20),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(ViewLayoutPB.Grid),     // 选择表格类型
        ),
        
        // ===== 看板页面类型 =====
        // 卡片式任务管理，类似Trello的看板布局，适合项目管理
        FlowyOptionTile.text(
          text: LocaleKeys.board_menuName.tr(),
          height: 52.0,
          leftIcon: const FlowySvg(
            FlowySvgs.icon_board_s,              // 看板图标
            size: Size.square(20),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(ViewLayoutPB.Board),    // 选择看板类型
        ),
        
        // ===== 日历页面类型 =====
        // 日程和事件管理，支持按日期组织和查看内容
        FlowyOptionTile.text(
          text: LocaleKeys.calendar_menuName.tr(),
          height: 52.0,
          leftIcon: const FlowySvg(
            FlowySvgs.icon_calendar_s,           // 日历图标
            size: Size.square(20),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(ViewLayoutPB.Calendar), // 选择日历类型
        ),
        
        // ===== 聊天页面类型 =====
        // AI对话界面，支持与AI助手进行智能对话和协作
        FlowyOptionTile.text(
          text: LocaleKeys.chat_newChat.tr(),   // 新聊天文本
          height: 52.0,
          leftIcon: const FlowySvg(
            FlowySvgs.chat_ai_page_s,           // AI聊天图标
            size: Size.square(20),
          ),
          showTopBorder: false,
          showBottomBorder: false,
          onTap: () => onAction(ViewLayoutPB.Chat),     // 选择聊天类型
        ),
      ],
    );
  }
}
