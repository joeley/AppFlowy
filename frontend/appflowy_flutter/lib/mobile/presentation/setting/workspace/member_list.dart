// 移动端工作区成员列表组件文件
// 管理工作区成员的显示和操作，支持成员权限管理和删除功能
// 使用BLoC模式管理成员状态，支持滑动操作和权限检查
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/shared/af_role_pb_extension.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/members/workspace_member_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:universal_platform/universal_platform.dart';

/// 移动端成员列表组件
/// 
/// 设计思想：
/// 1. 使用列表形式显示所有工作区成员信息
/// 2. 支持按权限展示不同的操作选项，确保安全性
/// 3. 采用SlidableAutoCloseBehavior实现滑动操作，提供原生移动端体验
/// 4. 使用SeparatedColumn实现带分隔的列表布局
/// 
/// 主要特性：
/// - 显示成员名称和角色信息
/// - 支持滑动操作（仅对有权限的用户）
/// - 支持成员删除功能（不能删除自己）
/// - 适配桌面端和移动端不同的布局样式
/// 
/// 权限管理：
/// - 通过myRole参数检查当前用户的权限
/// - 只有有权限的用户才能看到删除选项
/// - 不能删除自己的账号
class MobileMemberList extends StatelessWidget {
  /// 构造函数
  /// 
  /// [members] 工作区成员列表，包含所有成员的基本信息
  /// [myRole] 当前用户的角色权限，用于判断操作权限
  /// [userProfile] 当前用户的个人资料，用于防止删除自己
  const MobileMemberList({
    super.key,
    required this.members,
    required this.myRole,
    required this.userProfile,
  });

  final List<WorkspaceMemberPB> members; // 工作区成员列表数据
  final AFRolePB myRole; // 当前用户的角色权限，用于权限检查
  final UserProfilePB userProfile; // 当前用户信息，用于防止自我删除

  /// 构建成员列表UI
  /// 
  /// UI结构：
  /// 1. 最外层使用SingleChildScrollView支持滚动
  /// 2. SlidableAutoCloseBehavior实现自动关闭滑动面板
  /// 3. SeparatedColumn实现带分隔的列表布局
  /// 4. 显示“Joined”标题后跟随所有成员项
  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context); // 获取当前主题配置
    return SingleChildScrollView( // 支持垂直滚动，适应长列表
      child: SlidableAutoCloseBehavior( // 自动关闭滑动面板，提升用户体验
        child: SeparatedColumn( // 带分隔的列表布局
          crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
          separatorBuilder: () => SizedBox.shrink(), // 使用空组件作为分隔符，不显示额外空间
          children: [
            // 成员列表标题
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0, // 水平内边距
                vertical: 8.0, // 垂直内边距
              ),
              child: Text(
                'Joined', // 固定文本：“已加入”
                style: theme.textStyle.heading4.enhanced( // 使用heading4样式
                  color: theme.textColorScheme.primary, // 主文本颜色
                ),
              ),
            ),
            // 展开所有成员项，传递必要的参数
            ...members.map(
              (member) => _MemberItem(
                member: member, // 成员信息
                myRole: myRole, // 当前用户权限
                userProfile: userProfile, // 当前用户资料
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 成员项内部组件
/// 
/// 设计思想：
/// 1. 作为私有组件，专门用于显示单个成员信息
/// 2. 支持桌面端和移动端的不同布局适配
/// 3. 实现条件性滑动操作，只有有权限的用户才能看到删除选项
/// 4. 使用震动反馈增强交互体验
/// 
/// 主要特性：
/// - 根据平台适配不同的布局样式
/// - 支持滑动删除操作（移动端）
/// - 权限检查：不能删除自己，只有有权限的用户才能删除其他人
/// - 震动反馈和底部弹窗确认
class _MemberItem extends StatelessWidget {
  /// 构造函数
  /// 
  /// [member] 要显示的成员信息
  /// [myRole] 当前用户的角色权限
  /// [userProfile] 当前用户资料，用于防止自我删除
  const _MemberItem({
    required this.member,
    required this.myRole,
    required this.userProfile,
  });

  final WorkspaceMemberPB member; // 成员信息，包含名称、邮箱、角色等
  final AFRolePB myRole; // 当前用户权限，用于判断是否可以删除成员
  final UserProfilePB userProfile; // 当前用户资料，防止删除自己

  /// 构建成员项UI
  /// 
  /// UI构建流程：
  /// 1. 先检查权限，判断是否可以删除此成员
  /// 2. 根据平台类型构建不同的布局样式
  /// 3. 添加统一的内边距容器
  /// 4. 有权限时添加滑动删除功能
  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context); // 获取主题配置
    // 权限检查：当前用户有删除权限且不是要删除自己
    final canDelete = myRole.canDelete && member.email != userProfile.email;

    Widget child;

    // 根据平台类型适配不同的布局样式
    if (UniversalPlatform.isDesktop) {
      // 桌面端布局：名称和角色各占一半宽度，角色右对齐
      child = Row(
        children: [
          Expanded(
            child: Text(
              member.name, // 成员名称
              style: theme.textStyle.heading4.standard(
                color: theme.textColorScheme.primary, // 主文本颜色
              ),
            ),
          ),
          Expanded(
            child: Text(
              member.role.description, // 角色描述
              style: theme.textStyle.heading4.standard(
                color: theme.textColorScheme.secondary, // 次要文本颜色
              ),
              textAlign: TextAlign.end, // 右对齐
            ),
          ),
        ],
      );
    } else {
      // 移动端布局：名称占用剩余空间，角色固定宽度右对齐
      child = Row(
        children: [
          Expanded(
            child: Text(
              member.name, // 成员名称
              style: theme.textStyle.heading4.standard(
                color: theme.textColorScheme.primary, // 主文本颜色
              ),
              overflow: TextOverflow.ellipsis, // 长名称显示省略号
            ),
          ),
          Text(
            member.role.description, // 角色描述
            style: theme.textStyle.heading4.standard(
              color: theme.textColorScheme.secondary, // 次要文本颜色
            ),
            textAlign: TextAlign.end, // 右对齐
          ),
        ],
      );
    }

    // 添加统一的内边距容器
    child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.xl, // 水平大间距
        vertical: theme.spacing.l, // 垂直中等间距
      ),
      child: child,
    );

    // 如果有权限删除，添加滑动操作功能
    if (canDelete) {
      child = Slidable(
        key: ValueKey(member.email), // 使用邮箱作为唯一标识
        endActionPane: ActionPane( // 右侧滑动操作面板
          extentRatio: 1 / 6.0, // 操作面板宽度比例（1/6屏幕宽度）
          motion: const ScrollMotion(), // 滚动动画效果
          children: [
            CustomSlidableAction(
              backgroundColor: const Color(0xE5515563), // 灰色背景
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10), // 左上圆角
                bottomLeft: Radius.circular(10), // 左下圆角
              ),
              onPressed: (context) {
                HapticFeedback.mediumImpact(); // 中等强度震动反馈
                _showDeleteMenu(context); // 显示删除确认菜单
              },
              padding: EdgeInsets.zero, // 清零内边距
              child: const FlowySvg(
                FlowySvgs.three_dots_s, // 三点图标
                size: Size.square(24), // 24x24像素
                color: Colors.white, // 白色图标
              ),
            ),
          ],
        ),
        child: child, // 被滑动的内容
      );
    }

    return child;
  }

  /// 显示删除成员确认菜单
  /// 
  /// 交互设计：
  /// 1. 使用底部弹窗显示确认选项，符合移动端习惯
  /// 2. 使用错误颜色和垃圾筒图标强调删除操作的危险性
  /// 3. 点击后立即执行删除并关闭弹窗
  /// 
  /// 数据流：
  /// 1. 从上下文获取WorkspaceMemberBloc实例
  /// 2. 发送删除成员事件
  /// 3. 关闭弹窗返回上一级页面
  /// 
  /// [context] 构建上下文，用于获取BLoC和显示弹窗
  void _showDeleteMenu(BuildContext context) {
    // 获取成员管理BLoC实例
    final workspaceMemberBloc = context.read<WorkspaceMemberBloc>();
    
    // 显示移动端底部弹窗
    showMobileBottomSheet(
      context,
      showDragHandle: true, // 显示拖拽手柄
      showDivider: false, // 不显示分割线
      useRootNavigator: true, // 使用根导航器，确保弹窗显示在最顶层
      backgroundColor: Theme.of(context).colorScheme.surface, // 使用系统表面颜色
      builder: (context) {
        // 构建删除选项
        return FlowyOptionTile.text(
          text: LocaleKeys.settings_appearance_members_removeFromWorkspace.tr(), // 本地化文本：“从工作区中移除”
          height: 52.0, // 选项高度
          textColor: Theme.of(context).colorScheme.error, // 使用错误颜色（通常为红色）
          leftIcon: FlowySvg(
            FlowySvgs.trash_s, // 垃圾筒图标
            size: const Size.square(18), // 18x18像素
            color: Theme.of(context).colorScheme.error, // 与文本同色
          ),
          showTopBorder: false, // 不显示顶部边框
          showBottomBorder: false, // 不显示底部边框
          onTap: () {
            // 执行删除操作
            workspaceMemberBloc.add(
              WorkspaceMemberEvent.removeWorkspaceMemberByEmail(
                member.email, // 使用邮箱标识要删除的成员
              ),
            );
            Navigator.of(context).pop(); // 关闭弹窗
          },
        );
      },
    );
  }
}
