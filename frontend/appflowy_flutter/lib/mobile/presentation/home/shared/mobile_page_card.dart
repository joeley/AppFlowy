import 'dart:io';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/mobile/application/recent/recent_view_bloc.dart';
import 'package:appflowy/mobile/presentation/base/animated_gesture.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/shared/appflowy_network_image.dart';
import 'package:appflowy/shared/flowy_gradient_colors.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/util/string_extension.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/date_time/date_format_ext.dart';
import 'package:appflowy/workspace/application/settings/date_time/time_format_ext.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:string_validator/string_validator.dart';
import 'package:time/time.dart';

/// 移动端页面卡片类型枚举
/// 
/// 用于区分最近访问和收藏页面的显示方式
enum MobilePageCardType {
  /// 最近访问的页面
  recent,
  /// 收藏的页面
  favorite;

  /// 获取最后操作提示文本
  String get lastOperationHintText => switch (this) {
        MobilePageCardType.recent => LocaleKeys.sideBar_lastViewed.tr(),    // 最后访问
        MobilePageCardType.favorite => LocaleKeys.sideBar_favoriteAt.tr(),  // 收藏时间
      };
}

/// 移动端页面卡片组件
/// 
/// 功能说明：
/// 1. 显示页面的基本信息（标题、图标、封面）
/// 2. 支持点击进入页面编辑
/// 3. 支持右滑显示快捷操作菜单
/// 4. 显示最后操作时间和作者信息
/// 
/// 设计思想：
/// - 左侧显示页面信息，右侧显示封面缩略图
/// - 支持多种封面类型（纯色、渐变、图片等）
/// - 通过BLoC管理页面状态和数据
class MobileViewPage extends StatelessWidget {
  const MobileViewPage({
    super.key,
    required this.view,
    this.timestamp,
    required this.type,
  });

  /// 页面视图数据
  final ViewPB view;
  /// 时间戳（最后访问或收藏时间）
  final Int64? timestamp;
  /// 卡片类型（最近访问或收藏）
  final MobilePageCardType type;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 创建页面视图BLoC，不加载子页面
        BlocProvider<ViewBloc>(
          create: (context) => ViewBloc(view: view, shouldLoadChildViews: false)
            ..add(const ViewEvent.initial()),
        ),
        // 创建最近访问视图BLoC，管理页面的最近访问状态
        BlocProvider(
          create: (context) =>
              RecentViewBloc(view: view)..add(const RecentViewEvent.initial()),
        ),
      ],
      child: BlocBuilder<RecentViewBloc, RecentViewState>(
        builder: (context, state) {
          return Slidable(
            // 右滑显示的快捷操作面板
            endActionPane: buildEndActionPane(
              context,
              [
                MobilePaneActionType.more,  // 更多操作
                // 根据当前收藏状态显示不同操作
                context.watch<ViewBloc>().state.view.isFavorite
                    ? MobilePaneActionType.removeFromFavorites  // 取消收藏
                    : MobilePaneActionType.addToFavorites,     // 添加收藏
              ],
              cardType: type,
              spaceRatio: 4,  // 动作面板宽度比例
            ),
            child: AnimatedGestureDetector(
              // 点击进入页面编辑
              onTapUp: () => context.pushView(
                view,
                // 支持的图标选择器标签类型
                tabs: [
                  PickerTabType.emoji,   // Emoji标签
                  PickerTabType.icon,    // 图标标签
                  PickerTabType.custom,  // 自定义标签
                ].map((e) => e.name).toList(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 左侧间距
                  const HSpace(HomeSpaceViewSizes.mHorizontalPadding),
                  // 页面描述信息（标题、作者、时间）
                  Expanded(child: _buildDescription(context, state)),
                  const HSpace(20.0),
                  // 页面封面缩略图
                  SizedBox(
                    width: 84,
                    height: 60,
                    child: _buildCover(context, state),
                  ),
                  // 右侧间距
                  const HSpace(HomeSpaceViewSizes.mHorizontalPadding),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建页面描述信息区域
  /// 
  /// 包含页面标题、作者和最后访问时间
  Widget _buildDescription(BuildContext context, RecentViewState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 页面图标和标题
        _buildTitle(context, state),
        const VSpace(12.0),
        // 作者和最后访问时间
        _buildNameAndLastViewed(context, state),
      ],
    );
  }

  /// 构建作者和最后访问时间信息
  /// 
  /// 根据是否支持头像显示决定布局方式
  Widget _buildNameAndLastViewed(BuildContext context, RecentViewState state) {
    // 检查是否支持显示用户头像（图标是否为URL）
    final supportAvatar = isURL(state.icon.emoji);
    if (!supportAvatar) {
      // 不支持头像时只显示最后访问时间
      return _buildLastViewed(context);
    }
    // 支持头像时显示完整信息
    return Row(
      children: [
        _buildAvatar(context, state),        // 用户头像
        Flexible(child: _buildAuthor(context, state)),  // 作者名称
        // 分隔符
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3.0),
          child: FlowySvg(FlowySvgs.dot_s),
        ),
        _buildLastViewed(context),           // 最后访问时间
      ],
    );
  }

  /// 构建用户头像
  /// 
  /// 只有当页面作者是当前用户且有效的头像URL时才显示
  Widget _buildAvatar(BuildContext context, RecentViewState state) {
    final userProfile = Provider.of<UserProfilePB?>(context);
    final iconUrl = userProfile?.iconUrl;
    // 检查各项条件：头像非空、是当前用户创建、是有效URL
    if (iconUrl == null ||
        iconUrl.isEmpty ||
        view.createdBy != userProfile?.id ||
        !isURL(iconUrl)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2, right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),  // 圆角裁剪
        child: SizedBox.square(
          dimension: 16.0,  // 16x16尺寸的头像
          child: FlowyNetworkImage(
            url: iconUrl,
          ),
        ),
      ),
    );
  }

  /// 构建页面封面缩略图
  /// 
  /// 支持多种封面类型，包括纯色、渐变、图片等
  Widget _buildCover(BuildContext context, RecentViewState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),  // 圆角裁剪
      child: _ViewCover(
        layout: view.layout,                      // 页面布局类型
        coverTypeV1: state.coverTypeV1,           // 旧版封面类型
        coverTypeV2: state.coverTypeV2,           // 新版封面类型
        value: state.coverValue,                  // 封面值（颜色、图片URL等）
      ),
    );
  }

  /// 构建页面标题
  /// 
  /// 包括页面图标和标题文本，支持多行显示和文本省略
  Widget _buildTitle(BuildContext context, RecentViewState state) {
    final name = state.name;
    final icon = state.icon;
    return RichText(
      maxLines: 3,                         // 最多显示3行
      overflow: TextOverflow.ellipsis,     // 超出省略显示
      text: TextSpan(
        children: [
          // 如果有图标则显示图标
          if (icon.isNotEmpty) ...[
            WidgetSpan(
              child: SizedBox(
                width: 20,
                child: RawEmojiIconWidget(
                  emoji: icon,
                  emojiSize: 18.0,
                ),
              ),
            ),
            const WidgetSpan(child: HSpace(8.0)),  // 图标和文本间的间距
          ],
          // 页面标题文本
          TextSpan(
            text: name.orDefault(
              LocaleKeys.menuAppHeader_defaultNewPageName.tr(),  // 默认名称
            ),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,  // 半粗体
                  height: 1.3,                 // 行高
                ),
          ),
        ],
      ),
    );
  }

  /// 构建作者信息
  /// 
  /// 目前空实现，预留为未来显示作者名称
  Widget _buildAuthor(BuildContext context, RecentViewState state) {
    return FlowyText.regular(
      // TODO: 显示实际的作者名称
      // view.createdBy.toString(),
      '',  // 目前为空
      fontSize: 12.0,
      color: Theme.of(context).hintColor,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建最后访问时间
  /// 
  /// 根据主题模式调整文本颜色，支持智能时间格式化
  Widget _buildLastViewed(BuildContext context) {
    // 根据主题模式设置文本颜色
    final textColor = Theme.of(context).isLightMode
        ? const Color(0x7F171717)                    // 浅色模式：半透明黑色
        : Colors.white.withValues(alpha: 0.45);      // 深色模式：半透明白色
    
    if (timestamp == null) {
      return const SizedBox.shrink();
    }
    
    // 格式化时间戳（秒级转毫秒级）
    final date = _formatTimestamp(
      context,
      timestamp!.toInt() * 1000,
    );
    return FlowyText.regular(
      date,
      fontSize: 13.0,
      color: textColor,
    );
  }

  /// 格式化时间戳
  /// 
  /// 根据时间间隔智能地显示不同的时间格式：
  /// - 刚刚（1分钟内）
  /// - 几分钟前（1小时内）
  /// - 今天的具体时间
  /// - 其他日期
  String _formatTimestamp(BuildContext context, int timestamp) {
    final now = DateTime.now();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(dateTime);
    final String date;

    // 从外观设置中获取日期和时间格式
    final dateFormate =
        context.read<AppearanceSettingsCubit>().state.dateFormat;
    final timeFormate =
        context.read<AppearanceSettingsCubit>().state.timeFormat;

    if (difference.inMinutes < 1) {
      // 不到1分钟：显示“刚刚”
      date = LocaleKeys.sideBar_justNow.tr();
    } else if (difference.inHours < 1 && dateTime.isToday) {
      // 不到1小时且是今天：显示“几分钟前”
      date = LocaleKeys.sideBar_minutesAgo
          .tr(namedArgs: {'count': difference.inMinutes.toString()});
    } else if (difference.inHours >= 1 && dateTime.isToday) {
      // 超过1小时但是今天：显示具体时间
      date = timeFormate.formatTime(dateTime);
    } else {
      // 其他日期：显示日期
      date = dateFormate.formatDate(dateTime, false);
    }

    // 如果超过1小时，加上操作类型提示文本
    if (difference.inHours >= 1) {
      return '${type.lastOperationHintText} $date';
    }

    return date;
  }
}

/// 页面封面显示组件
/// 
/// 功能说明：
/// 1. 支持多种封面类型（V1和V2版本）
/// 2. 根据页面布局类型显示不同默认占位图
/// 3. 支持纯色、渐变、图片等多种封面形式
/// 
/// 设计思想：
/// - 优先使用V2版本格式，向下兼容V1版本
/// - 为不同页面类型提供默认颜色和图标
class _ViewCover extends StatelessWidget {
  const _ViewCover({
    required this.layout,
    required this.coverTypeV1,
    this.coverTypeV2,
    this.value,
  });

  /// 页面布局类型（文档、表格、看板等）
  final ViewLayoutPB layout;
  /// V1版本封面类型
  final CoverType coverTypeV1;
  /// V2版本封面类型（可选）
  final PageStyleCoverImageType? coverTypeV2;
  /// 封面值（颜色值、图片URL等）
  final String? value;

  @override
  Widget build(BuildContext context) {
    // 构建默认占位图
    final placeholder = _buildPlaceholder(context);
    final value = this.value;
    
    // 如果没有封面值，显示默认占位图
    if (value == null) {
      return placeholder;
    }
    
    // 优先使用V2版本格式
    if (coverTypeV2 != null) {
      return _buildCoverV2(context, value, placeholder);
    }
    
    // 向下兼容V1版本格式
    return _buildCoverV1(context, value, placeholder);
  }

  /// 构建默认占位图
  /// 
  /// 根据页面类型和主题模式显示不同的占位图标和颜色
  Widget _buildPlaceholder(BuildContext context) {
    final isLightMode = Theme.of(context).isLightMode;
    // 使用switch表达式根据页面类型返回对应的图标和颜色
    final (svg, color) = switch (layout) {
      ViewLayoutPB.Document => (          // 文档类型
          FlowySvgs.m_document_thumbnail_m,
          isLightMode ? const Color(0xCCEDFBFF) : const Color(0x33658B90)  // 蓝色系
        ),
      ViewLayoutPB.Grid => (              // 表格类型
          FlowySvgs.m_grid_thumbnail_m,
          isLightMode ? const Color(0xFFF5F4FF) : const Color(0x338B80AD)  // 紫色系
        ),
      ViewLayoutPB.Board => (             // 看板类型
          FlowySvgs.m_board_thumbnail_m,
          isLightMode ? const Color(0x7FE0FDD9) : const Color(0x3372936B),  // 绿色系
        ),
      ViewLayoutPB.Calendar => (          // 日历类型
          FlowySvgs.m_calendar_thumbnail_m,
          isLightMode ? const Color(0xFFFFF7F0) : const Color(0x33A68B77)  // 橙色系
        ),
      ViewLayoutPB.Chat => (              // 聊天类型
          FlowySvgs.m_chat_thumbnail_m,
          isLightMode ? const Color(0x66FFE6FD) : const Color(0x33987195)  // 粉色系
        ),
      _ => (                               // 默认情况
          FlowySvgs.m_document_thumbnail_m,
          isLightMode ? Colors.black : Colors.white
        )
    };
    return ColoredBox(
      color: color,
      child: Center(
        child: FlowySvg(
          svg,
          blendMode: null,  // 不使用混合模式
        ),
      ),
    );
  }

  Widget _buildCoverV2(BuildContext context, String value, Widget placeholder) {
    final type = coverTypeV2;
    if (type == null) {
      return placeholder;
    }
    if (type == PageStyleCoverImageType.customImage ||
        type == PageStyleCoverImageType.unsplashImage) {
      final userProfilePB = Provider.of<UserProfilePB?>(context);
      return FlowyNetworkImage(
        url: value,
        userProfilePB: userProfilePB,
      );
    }

    if (type == PageStyleCoverImageType.builtInImage) {
      return Image.asset(
        PageStyleCoverImageType.builtInImagePath(value),
        fit: BoxFit.cover,
      );
    }

    if (type == PageStyleCoverImageType.pureColor) {
      final color = value.coverColor(context);
      if (color != null) {
        return ColoredBox(
          color: color,
        );
      }
    }

    if (type == PageStyleCoverImageType.gradientColor) {
      return Container(
        decoration: BoxDecoration(
          gradient: FlowyGradientColor.fromId(value).linear,
        ),
      );
    }

    if (type == PageStyleCoverImageType.localImage) {
      return Image.file(
        File(value),
        fit: BoxFit.cover,
      );
    }

    return placeholder;
  }

  Widget _buildCoverV1(BuildContext context, String value, Widget placeholder) {
    switch (coverTypeV1) {
      case CoverType.file:
        if (isURL(value)) {
          final userProfilePB = Provider.of<UserProfilePB?>(context);
          return FlowyNetworkImage(
            url: value,
            userProfilePB: userProfilePB,
          );
        }
        final imageFile = File(value);
        if (!imageFile.existsSync()) {
          return placeholder;
        }
        return Image.file(
          imageFile,
        );
      case CoverType.asset:
        return Image.asset(
          value,
          fit: BoxFit.cover,
        );
      case CoverType.color:
        final color = value.tryToColor() ?? Colors.white;
        return Container(
          color: color,
        );
      case CoverType.none:
        return placeholder;
    }
  }
}
