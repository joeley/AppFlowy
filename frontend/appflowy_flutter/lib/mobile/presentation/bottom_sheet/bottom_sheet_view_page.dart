/*
 * 移动端视图页面底部弹窗模块
 * 
 * 为AppFlowy移动端提供完整的视图操作底部弹窗系统
 * 包含视图的各种操作：重命名、收藏、复制、删除、发布等
 * 
 * 架构设计：
 * 1. **枚举驱动**：使用MobileViewBottomSheetBodyAction枚举定义所有操作类型
 * 2. **状态管理**：通过ViewPageBottomSheet管理弹窗的状态切换
 * 3. **权限控制**：基于用户权限和页面锁定状态控制操作可用性
 * 4. **模块化设计**：每个功能组件独立，易于维护和扩展
 */

import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/base/mobile_view_page_bloc.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_quick_action_button.dart';
import 'package:appflowy/plugins/shared/share/share_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/*
 * 移动端视图底部弹窗操作类型枚举
 * 
 * 定义了所有可能的视图操作类型
 * 通过枚举方式确保操作类型的类型安全和代码可维护性
 */
enum MobileViewBottomSheetBodyAction {
  undo,                 /* 撤销操作 */
  redo,                 /* 重做操作 */
  rename,               /* 重命名视图 */
  duplicate,            /* 复制视图 */
  delete,               /* 删除视图 */
  addToFavorites,       /* 添加到收藏 */
  removeFromFavorites,  /* 从收藏中移除 */
  helpCenter,           /* 帮助中心 */
  publish,              /* 发布页面 */
  unpublish,            /* 取消发布 */
  copyPublishLink,      /* 复制发布链接 */
  visitSite,            /* 访问网站 */
  copyShareLink,        /* 复制分享链接 */
  updatePathName,       /* 更新路径名称 */
  lockPage;             /* 锁定/解锁页面 */

  /* 在锁定视图中禁用的操作列表
   * 当页面被锁定时，这些操作将不可用 */
  static const disableInLockedView = [
    undo,
    redo,
    rename,
    delete,
  ];
}

/*
 * 移动端视图底部弹窗操作参数类
 * 
 * 定义操作回调函数中传递的参数键名
 * 用于在操作执行时传递额外的上下文信息
 */
class MobileViewBottomSheetBodyActionArguments {
  /* 页面锁定状态的参数键
   * 用于lockPage操作传递锁定状态 */
  static const isLockedKey = 'is_locked';
}

/*
 * 移动端视图底部弹窗操作回调函数类型定义
 * 
 * 统一的操作回调接口，支持传递额外参数
 * 
 * @param action 执行的操作类型
 * @param arguments 可选的参数映射，用于传递操作相关的上下文数据
 *                  例如：lockPage操作会传递isLocked状态值
 */
typedef MobileViewBottomSheetBodyActionCallback = void Function(
  MobileViewBottomSheetBodyAction action,
  {
  Map<String, dynamic>? arguments,
});

/*
 * 视图页面底部弹窗主组件
 * 
 * 管理视图操作底部弹窗的状态切换，支持多种视图操作模式：
 * 1. 视图操作模式：显示各种操作按钮（重命名、删除、收藏等）
 * 2. 重命名模式：显示重命名输入框
 * 
 * 设计思想：
 * - **状态驱动UI**：根据type状态渲染不同的UI界面
 * - **操作代理模式**：统一处理操作回调，内部路由到具体处理逻辑
 * - **组件解耦**：操作逻辑和UI展示分离，提高代码可维护性
 */
class ViewPageBottomSheet extends StatefulWidget {
  const ViewPageBottomSheet({
    super.key,
    required this.view,
    required this.onAction,
    required this.onRename,
  });

  final ViewPB view;                                      /* 当前操作的视图对象 */
  final MobileViewBottomSheetBodyActionCallback onAction; /* 操作回调函数 */
  final void Function(String name) onRename;              /* 重命名回调函数 */

  @override
  State<ViewPageBottomSheet> createState() => _ViewPageBottomSheetState();
}

/*
 * 视图页面底部弹窗状态管理类
 * 
 * 管理弹窗的不同显示模式，实现状态驱动的UI切换
 */
class _ViewPageBottomSheetState extends State<ViewPageBottomSheet> {
  /* 当前弹窗类型，默认显示视图操作界面 */
  MobileBottomSheetType type = MobileBottomSheetType.view;

  @override
  Widget build(BuildContext context) {
    /* 根据当前类型渲染不同的UI组件 */
    switch (type) {
      case MobileBottomSheetType.view:
        /* 视图操作模式：显示所有可用的操作按钮 */
        return MobileViewBottomSheetBody(
          view: widget.view,
          onAction: (action, {arguments}) {
            switch (action) {
              case MobileViewBottomSheetBodyAction.rename:
                /* 特殊处理重命名操作：切换到重命名模式 
                 * 而不是直接关闭弹窗 */
                setState(() {
                  type = MobileBottomSheetType.rename;
                });
                break;
              default:
                /* 其他操作直接传递给父组件处理 */
                widget.onAction(action, arguments: arguments);
            }
          },
        );

      case MobileBottomSheetType.rename:
        /* 重命名模式：显示文本输入框供用户修改名称 */
        return MobileBottomSheetRenameWidget(
          name: widget.view.name,
          onRename: (name) {
            /* 重命名完成后直接调用回调并关闭弹窗 */
            widget.onRename(name);
          },
        );
    }
  }
}

/*
 * 移动端视图底部弹窗主体内容组件
 * 
 * 展示视图的所有可用操作按钮，根据用户权限和视图状态动态调整可用功能
 * 
 * 功能特性：
 * 1. **权限感知**：根据用户编辑权限控制操作可用性
 * 2. **状态响应**：根据收藏状态、发布状态等动态调整按钮文本和图标
 * 3. **条件渲染**：根据视图类型和工作区类型显示对应功能
 * 4. **分组布局**：按功能类型分组排列，用分割线分隔
 */
class MobileViewBottomSheetBody extends StatelessWidget {
  const MobileViewBottomSheetBody({
    super.key,
    required this.view,
    required this.onAction,
  });

  final ViewPB view;                                      /* 当前操作的视图 */
  final MobileViewBottomSheetBodyActionCallback onAction; /* 操作回调函数 */

  @override
  Widget build(BuildContext context) {
    /* 获取视图的收藏状态 */
    final isFavorite = view.isFavorite;
    /* 监听页面访问级别状态，确定当前用户是否有编辑权限 */
    final isEditable =
        context.watch<PageAccessLevelBloc?>()?.state.isEditable ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /* === 基础编辑操作区域 === */
        /* 重命名按钮：只有可编辑状态下才启用 */
        MobileQuickActionButton(
          text: LocaleKeys.button_rename.tr(),
          icon: FlowySvgs.view_item_rename_s,
          iconSize: const Size.square(18),
          enable: isEditable,  /* 根据编辑权限控制是否可用 */
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.rename,
          ),
        ),
        _divider(),
        /* 收藏按钮：根据当前收藏状态显示不同的文本和图标 */
        MobileQuickActionButton(
          text: isFavorite
              ? LocaleKeys.button_removeFromFavorites.tr()  /* 已收藏时显示移除 */
              : LocaleKeys.button_addToFavorites.tr(),      /* 未收藏时显示添加 */
          icon: isFavorite ? FlowySvgs.unfavorite_s : FlowySvgs.favorite_s,
          iconSize: const Size.square(18),
          onTap: () => onAction(
            isFavorite
                ? MobileViewBottomSheetBodyAction.removeFromFavorites
                : MobileViewBottomSheetBodyAction.addToFavorites,
          ),
        ),
        _divider(),
        /* === 高级功能区域 === */
        /* 页面锁定功能：仅在数据库视图和文档视图中可用 */
        if (view.layout.isDatabaseView || view.layout.isDocumentView) ...[
          /* 页面锁定控制按钮：带有开关控件的特殊按钮 */
          MobileQuickActionButton(
            text: LocaleKeys.disclosureAction_lockPage.tr(),
            icon: FlowySvgs.lock_page_s,
            iconSize: const Size.square(18),
            /* 右侧显示开关控件，用于直观显示和控制锁定状态 */
            rightIconBuilder: (context) => _LockPageRightIconBuilder(
              onAction: onAction,
            ),
            onTap: () {
              /* 获取当前锁定状态 */
              final isLocked =
                  context.read<PageAccessLevelBloc?>()?.state.isLocked ?? false;
              /* 触发锁定/解锁操作，传递当前状态作为参数 */
              onAction(
                MobileViewBottomSheetBodyAction.lockPage,
                arguments: {
                  MobileViewBottomSheetBodyActionArguments.isLockedKey:
                      isLocked,
                },
              );
            },
          ),
          _divider(),
        ],
        /* === 内容操作区域 === */
        /* 复制视图功能 */
        MobileQuickActionButton(
          text: LocaleKeys.button_duplicate.tr(),
          icon: FlowySvgs.duplicate_s,
          iconSize: const Size.square(18),
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.duplicate,
          ),
        ),
        _divider(),
        /* 复制分享链接功能 */
        MobileQuickActionButton(
          text: LocaleKeys.shareAction_copyLink.tr(),
          icon: FlowySvgs.m_copy_link_s,
          iconSize: const Size.square(18),
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.copyShareLink,
          ),
        ),
        _divider(),
        /* 发布相关操作：根据工作区类型和发布状态动态生成 */
        ..._buildPublishActions(context),

        /* === 危险操作区域 === */
        /* 删除按钮：使用错误色彩强调危险性，只有可编辑状态下才启用 */
        MobileQuickActionButton(
          text: LocaleKeys.button_delete.tr(),
          textColor: Theme.of(context).colorScheme.error,  /* 错误颜色文本 */
          icon: FlowySvgs.trash_s,
          iconColor: Theme.of(context).colorScheme.error,  /* 错误颜色图标 */
          iconSize: const Size.square(18),
          enable: isEditable,  /* 根据编辑权限控制是否可用 */
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.delete,
          ),
        ),
        _divider(),
      ],
    );
  }

  /*
   * 构建发布相关操作按钮
   * 
   * 根据用户工作区类型和页面发布状态动态生成相应的操作按钮
   * 发布功能仅在AppFlowy Cloud工作区中可用
   * 
   * @param context 构建上下文
   * @return 发布操作按钮列表
   */
  List<Widget> _buildPublishActions(BuildContext context) {
    final userProfile = context.read<MobileViewPageBloc>().state.userProfilePB;
    /* 发布功能仅在AppFlowy Cloud（服务器工作区）中可用
     * 本地工作区不支持发布功能 */
    if (userProfile == null ||
        userProfile.workspaceType != WorkspaceTypePB.ServerW) {
      return [];
    }

    /* 监听分享状态，获取当前页面是否已发布 */
    final isPublished = context.watch<ShareBloc>().state.isPublished;
    
    if (isPublished) {
      /* 已发布状态：显示发布管理相关操作 */
      return [
        /* 更新发布路径名称 */
        MobileQuickActionButton(
          text: LocaleKeys.shareAction_updatePathName.tr(),
          icon: FlowySvgs.view_item_rename_s,
          iconSize: const Size.square(18),
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.updatePathName,
          ),
        ),
        _divider(),
        /* 访问已发布的网站 */
        MobileQuickActionButton(
          text: LocaleKeys.shareAction_visitSite.tr(),
          icon: FlowySvgs.m_visit_site_s,
          iconSize: const Size.square(18),
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.visitSite,
          ),
        ),
        _divider(),
        /* 取消发布 */
        MobileQuickActionButton(
          text: LocaleKeys.shareAction_unPublish.tr(),
          icon: FlowySvgs.m_unpublish_s,
          iconSize: const Size.square(18),
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.unpublish,
          ),
        ),
        _divider(),
        _divider(),
      ];
    } else {
      /* 未发布状态：只显示发布按钮 */
      return [
        MobileQuickActionButton(
          text: LocaleKeys.shareAction_publish.tr(),
          icon: FlowySvgs.m_publish_s,
          onTap: () => onAction(
            MobileViewBottomSheetBodyAction.publish,
          ),
        ),
        _divider(),
      ];
    }
  }

  /* 创建统一样式的分割线 */
  Widget _divider() => const MobileQuickActionDivider();
}

/*
 * 页面锁定开关组件
 * 
 * 为页面锁定功能提供直观的开关控件
 * 使用Cupertino风格的开关，提供更好的用户体验
 * 
 * 设计思想：
 * - **状态同步**：开关状态与页面编辑权限状态保持同步
 * - **即时反馈**：用户操作开关时立即触发状态变更
 * - **视觉一致性**：使用系统主色作为激活状态颜色
 */
class _LockPageRightIconBuilder extends StatelessWidget {
  const _LockPageRightIconBuilder({
    required this.onAction,
  });

  final MobileViewBottomSheetBodyActionCallback onAction; /* 操作回调函数 */

  @override
  Widget build(BuildContext context) {
    /* 监听页面访问级别状态，获取当前编辑权限 */
    final isEditable =
        context.watch<PageAccessLevelBloc?>()?.state.isEditable ?? false;
        
    return SizedBox(
      width: 46,   /* 固定开关宽度 */
      height: 30,  /* 固定开关高度 */
      child: FittedBox(
        fit: BoxFit.fill,  /* 填充整个容器 */
        child: CupertinoSwitch(
          value: isEditable,  /* 开关状态对应编辑权限状态 */
          activeTrackColor: Theme.of(context).colorScheme.primary,  /* 使用主题主色 */
          onChanged: (value) {
            /* 开关状态变化时触发锁定/解锁操作 */
            onAction(
              MobileViewBottomSheetBodyAction.lockPage,
              arguments: {
                MobileViewBottomSheetBodyActionArguments.isLockedKey: value,
              },
            );
          },
        ),
      ),
    );
  }
}
