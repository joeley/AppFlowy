// 自动生成的国际化键值定义文件
import 'package:appflowy/generated/locale_keys.g.dart';
// 底部弹出框的基础组件和功能
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
// 移动端确认对话框组件
import 'package:appflowy/mobile/presentation/widgets/show_flowy_mobile_confirm_dialog.dart';
// 全局应用上下文管理
import 'package:appflowy/startup/tasks/app_widget.dart';
// 收藏功能的BLoC状态管理
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
// 最近访问视图的BLoC状态管理
import 'package:appflowy/workspace/application/recent/recent_views_bloc.dart';
// 视图的BLoC状态管理，处理视图的CRUD操作
import 'package:appflowy/workspace/application/view/view_bloc.dart';
// 通用对话框组件
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
// 文件夹相关的协议缓冲区定义，包含ViewPB等
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
// 国际化支持库
import 'package:easy_localization/easy_localization.dart';
// AppFlowy自定义UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
// BLoC状态管理库，用于访问各种Bloc
import 'package:flutter_bloc/flutter_bloc.dart';
// Toast提示组件库
import 'package:fluttertoast/fluttertoast.dart';

/// 移动端底部弹出框的类型枚举
/// 
/// 用于区分弹出框当前显示的内容类型，实现单个组件内的多种视图切换
enum MobileBottomSheetType {
  /// 视图操作列表模式（默认模式）
  view,
  /// 重命名输入模式
  rename,
}

/// 移动端视图项目底部弹出框组件
/// 
/// 设计思想：
/// 1. 作为视图项目操作的统一入口，集成多种常用操作（重命名、复制、删除等）
/// 2. 使用StatefulWidget管理弹窗内部状态切换（操作列表 ↔ 重命名输入）
/// 3. 集成多个BLoC进行状态管理，包括视图、收藏、最近访问等
/// 4. 提供统一的Toast提示反馈，增强用户体验
/// 
/// 架构优势：
/// - 单一职责原则：只处理视图项目相关操作
/// - 组合模式：通过actions参数灵活配置可用操作
/// - 状态分离：业务逻辑在BLoC中，UI组件只负责展示
/// 
/// 使用场景：
/// - 文件夹列表中的视图项目操作
/// - 最近访问列表中的视图项目管理
/// - 收藏列表中的视图项目管理
/// - 任何需要对视图进行操作的移动端场景
class MobileViewItemBottomSheet extends StatefulWidget {
  const MobileViewItemBottomSheet({
    super.key,
    required this.view,
    required this.actions,
    this.defaultType = MobileBottomSheetType.view,
  });

  /// 当前操作的视图对象，包含视图的所有元信息
  final ViewPB view;
  /// 默认显示的弹窗类型，通常为操作列表模式
  final MobileBottomSheetType defaultType;
  /// 允许的操作列表，支持灵活配置不同场景下的可用操作
  final List<MobileViewItemBottomSheetBodyAction> actions;

  @override
  State<MobileViewItemBottomSheet> createState() =>
      _MobileViewItemBottomSheetState();
}

/// 移动端视图项目底部弹出框的状态管理类
/// 
/// 负责管理：
/// 1. 弹窗内部视图状态的切换
/// 2. Toast提示的初始化和管理
/// 3. 各种操作的事件分发和处理
class _MobileViewItemBottomSheetState extends State<MobileViewItemBottomSheet> {
  /// 当前弹窗显示的类型，控制显示不同的UI内容
  MobileBottomSheetType type = MobileBottomSheetType.view;
  /// Toast提示实例，用于显示操作结果反馈
  final fToast = FToast();

  /// 组件初始化方法
  /// 
  /// 主要作用：
  /// 1. 设置初始的弹窗类型
  /// 2. 初始化Toast组件，用于操作反馈
  @override
  void initState() {
    super.initState();

    // 使用外部传入的默认类型，提供灵活性
    type = widget.defaultType;
    // 初始化Toast，使用全局应用上下文
    fToast.init(AppGlobals.context);
  }

  /// 构建弹窗内容
  /// 
  /// 根据当前状态显示不同UI：
  /// - view: 显示操作列表
  /// - rename: 显示重命名输入框
  @override
  Widget build(BuildContext context) {
    switch (type) {
      case MobileBottomSheetType.view:
        // 显示操作列表界面
        return MobileViewItemBottomSheetBody(
          actions: widget.actions,
          isFavorite: widget.view.isFavorite,
          // 处理各种操作的回调
          onAction: (action) {
            switch (action) {
              // 重命名操作：切换到重命名输入模式
              case MobileViewItemBottomSheetBodyAction.rename:
                setState(() {
                  type = MobileBottomSheetType.rename;
                });
                break;
              // 复制操作：关闭弹窗后执行复制并显示成功提示
              case MobileViewItemBottomSheetBodyAction.duplicate:
                Navigator.pop(context);
                context.read<ViewBloc>().add(const ViewEvent.duplicate());
                showToastNotification(
                  message: LocaleKeys.button_duplicateSuccessfully.tr(),
                );
                break;
              // 分享操作：当前未实现，只关闭弹窗
              case MobileViewItemBottomSheetBodyAction.share:
                // TODO: 待实现分享功能
                Navigator.pop(context);
                break;
              // 删除操作：直接删除，不显示确认对话框
              case MobileViewItemBottomSheetBodyAction.delete:
                Navigator.pop(context);
                context.read<ViewBloc>().add(const ViewEvent.delete());
                break;
              // 收藏相关操作：切换收藏状态并显示相应提示
              case MobileViewItemBottomSheetBodyAction.addToFavorites:
              case MobileViewItemBottomSheetBodyAction.removeFromFavorites:
                Navigator.pop(context);
                context
                    .read<FavoriteBloc>()
                    .add(FavoriteEvent.toggle(widget.view));
                // 根据当前状态显示不同的成功消息
                showToastNotification(
                  message: !widget.view.isFavorite
                      ? LocaleKeys.button_favoriteSuccessfully.tr()
                      : LocaleKeys.button_unfavoriteSuccessfully.tr(),
                );
                break;
              // 从最近访问中移除：需要二次确认
              case MobileViewItemBottomSheetBodyAction.removeFromRecent:
                _removeFromRecent(context);
                break;
              // 分割线：不需要处理
              case MobileViewItemBottomSheetBodyAction.divider:
                break;
            }
          },
        );
      case MobileBottomSheetType.rename:
        // 显示重命名输入界面
        return MobileBottomSheetRenameWidget(
          name: widget.view.name,
          onRename: (name) {
            // 只有名称发生改变时才执行重命名操作
            if (name != widget.view.name) {
              context.read<ViewBloc>().add(ViewEvent.rename(name));
            }
            Navigator.pop(context);
          },
        );
    }
  }

  /// 从最近访问列表中移除视图
  /// 
  /// 设计思想：
  /// 1. 先关闭弹窗，然后显示确认对话框，防止界面重叠
  /// 2. 通过确认对话框防止用户误操作，提升用户体验
  /// 3. 使用RecentViewsBloc处理业务逻辑，保持架构一致性
  /// 
  /// 参数：
  /// - [context] 组件上下文，用于访问BLoC和关闭弹窗
  Future<void> _removeFromRecent(BuildContext context) async {
    // 获取当前视图ID
    final viewId = context.read<ViewBloc>().view.id;
    // 获取最近访问管理的BLoC实例
    final recentViewsBloc = context.read<RecentViewsBloc>();
    // 先关闭当前弹窗，为确认对话框让路
    Navigator.pop(context);

    // 显示确认对话框，等待用户确认
    await _showConfirmDialog(
      onDelete: () {
        // 用户确认后，执行移除操作
        recentViewsBloc.add(RecentViewsEvent.removeRecentViews([viewId]));
      },
    );
  }

  /// 显示确认删除对话框
  /// 
  /// 设计特点：
  /// 1. 使用Cupertino风格的对话框，符合移动端设计规范
  /// 2. 明确区分取消和删除按钮的视觉样式（蓝色vs红色）
  /// 3. 在用户确认后立即显示成功提示，提供及时反馈
  /// 
  /// 参数：
  /// - [onDelete] 用户确认删除时的回调函数
  Future<void> _showConfirmDialog({required VoidCallback onDelete}) async {
    await showFlowyCupertinoConfirmDialog(
      // 对话框标题，使用国际化文本
      title: LocaleKeys.sideBar_removePageFromRecent.tr(),
      // 取消按钮：使用系统蓝色，表示安全操作
      leftButton: FlowyText(
        LocaleKeys.button_cancel.tr(),
        fontSize: 17.0,           // iOS标准对话框按钮字体大小
        figmaLineHeight: 24.0,    // 设计稿规定的行高
        fontWeight: FontWeight.w500, // 中等粗细，突出默认选项
        color: const Color(0xFF007AFF), // iOS系统蓝色
      ),
      // 删除按钮：使用红色，表示危险操作
      rightButton: FlowyText(
        LocaleKeys.button_delete.tr(),
        fontSize: 17.0,
        figmaLineHeight: 24.0,
        fontWeight: FontWeight.w400, // 正常粗细，与取消按钮区分
        color: const Color(0xFFFE0220), // 红色，表示危险操作
      ),
      // 点击删除按钮的处理逻辑
      onRightButtonPressed: (context) {
        // 执行删除回调
        onDelete();

        // 关闭确认对话框
        Navigator.pop(context);

        // 显示成功提示，给用户及时反馈
        showToastNotification(
          message: LocaleKeys.sideBar_removeSuccess.tr(),
        );
      },
    );
  }
}
