// 导入相关依赖包
import 'dart:io';

import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/mobile/application/recent/recent_view_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/shared/appflowy_network_image.dart';
import 'package:appflowy/shared/flowy_gradient_colors.dart';
import 'package:appflowy/util/string_extension.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:string_validator/string_validator.dart';

/// 移动端最近访问页面卡片组件
/// 
/// 功能说明：
/// 1. 显示单个最近访问页面的缩略信息
/// 2. 支持点击进入页面编辑模式
/// 3. 动态显示页面封面、图标和标题
/// 4. 自动适配不同的封面类型和页面样式
/// 
/// 设计思想：
/// - 采用卡片式布局，上半部分显示封面，下半部分显示标题
/// - 左上角叠加显示页面图标，提供视觉层次感
/// - 通过BLoC管理页面状态，支持实时数据更新
/// - 封面支持多种类型：纯色、渐变、本地图片、网络图片等
class MobileRecentView extends StatelessWidget {
  const MobileRecentView({
    super.key,
    required this.view,
  });

  /// 页面视图数据，包含页面的基本信息
  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    // 获取当前主题配置
    final theme = Theme.of(context);

    // 提供最近访问页面的BLoC状态管理
    return BlocProvider<RecentViewBloc>(
      create: (context) => RecentViewBloc(view: view)
        ..add(
          const RecentViewEvent.initial(),  // 初始化加载页面数据
        ),
      child: BlocBuilder<RecentViewBloc, RecentViewState>(
        builder: (context, state) {
          return GestureDetector(
            // 点击卡片进入页面编辑模式
            onTap: () => context.pushView(view),
            child: Stack(
              children: [
                // 主卡片容器，带圆角和边框
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 上半部分：页面封面
                      Expanded(child: _buildCover(context, state)),
                      // 下半部分：页面标题
                      Expanded(child: _buildTitle(context, state)),
                    ],
                  ),
                ),
                // 左侧叠加的页面图标
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildIcon(context, state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建页面封面区域
  /// 
  /// 参数：
  /// - context: 构建上下文
  /// - state: 最近访问页面状态
  /// 
  /// 返回值：包含封面内容的Widget
  Widget _buildCover(BuildContext context, RecentViewState state) {
    return Padding(
      // 顶部和左右留出1px边距，避免圆角被遮挡
      padding: const EdgeInsets.only(top: 1.0, left: 1.0, right: 1.0),
      child: ClipRRect(
        // 只对顶部进行圆角裁剪，匹配卡片样式
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        // 封面内容组件，支持多种封面类型
        child: _RecentCover(
          coverTypeV1: state.coverTypeV1,   // 旧版封面类型
          coverTypeV2: state.coverTypeV2,   // 新版封面类型
          value: state.coverValue,          // 封面值（颜色、图片URL等）
        ),
      ),
    );
  }

  /// 构建页面标题区域
  /// 
  /// 使用Stack布局实现最少两行的显示效果
  /// 参数：
  /// - context: 构建上下文
  /// - state: 最近访问页面状态
  /// 
  /// 返回值：包含标题的Widget
  Widget _buildTitle(BuildContext context, RecentViewState state) {
    return Padding(
      // 标题区域内边距
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 2),
      // 技巧：由于Text组件不支持minLines属性，使用Stack实现最少两行显示
      // 参考：https://github.com/flutter/flutter/issues/31134
      child: Stack(
        children: [
          // 实际的页面标题文本
          FlowyText.medium(
            view.name,
            fontSize: 16.0,
            maxLines: 2,                      // 最多显示2行
            overflow: TextOverflow.ellipsis,   // 超出部分省略显示
          ),
          // 隐藏的占位文本，确保至少占据两行高度
          const FlowyText(
            "\n\n",
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  /// 构建页面图标
  /// 
  /// 根据状态显示emoji图标或默认图标
  /// 参数：
  /// - context: 构建上下文
  /// - state: 最近访问页面状态
  /// 
  /// 返回值：页面图标Widget
  Widget _buildIcon(BuildContext context, RecentViewState state) {
    return Padding(
      // 图标左侧内边距
      padding: const EdgeInsets.only(left: 8.0),
      child: state.icon.isNotEmpty
          // 如果有自定义图标则显示emoji
          ? RawEmojiIconWidget(emoji: state.icon, emojiSize: 30)
          // 否则显示页面类型的默认图标
          : SizedBox.square(
              dimension: 32.0,
              child: view.defaultIcon(),
            ),
    );
  }
}

/// 最近访问页面封面组件
/// 
/// 功能说明：
/// 1. 支持V1和V2两个版本的封面格式
/// 2. 处理多种封面类型：纯色、渐变、本地图片、网络图片等
/// 3. 提供默认占位图以处理无封面的情况
/// 
/// 设计思想：
/// - 优先使用V2版本格式，向下兼容V1版本
/// - 统一的占位图设计，保持视觉一致性
/// - 错误处理机制，确保在封面加载失败时有备选方案
class _RecentCover extends StatelessWidget {
  const _RecentCover({
    required this.coverTypeV1,
    this.coverTypeV2,
    this.value,
  });

  /// V1版本的封面类型
  final CoverType coverTypeV1;
  /// V2版本的封面类型（可选）
  final PageStyleCoverImageType? coverTypeV2;
  /// 封面值（颜色代码、图片URL、文件路径等）
  final String? value;

  @override
  Widget build(BuildContext context) {
    // 默认占位图，使用半透明的表面变色
    final placeholder = Container(
      // TODO: 使用随机颜色，后续可考虑更好的占位图设计
      color:
          Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
    );
    final value = this.value;
    // 如果没有封面值，返回默认占位图
    if (value == null) {
      return placeholder;
    }
    // 优先使用V2版本格式构建封面
    if (coverTypeV2 != null) {
      return _buildCoverV2(context, value, placeholder);
    }
    // 回退到V1版本格式
    return _buildCoverV1(context, value, placeholder);
  }

  /// 构建V2版本格式的封面
  /// 
  /// V2版本支持更多封面类型，是当前推荐的格式
  /// 参数：
  /// - context: 构建上下文
  /// - value: 封面值
  /// - placeholder: 默认占位图
  /// 
  /// 返回值：封面Widget
  Widget _buildCoverV2(BuildContext context, String value, Widget placeholder) {
    final type = coverTypeV2;
    // 如果封面类型为空，返回占位图
    if (type == null) {
      return placeholder;
    }
    // 处理自定义图片和Unsplash图片（网络图片）
    if (type == PageStyleCoverImageType.customImage ||
        type == PageStyleCoverImageType.unsplashImage) {
      final userProfilePB = Provider.of<UserProfilePB?>(context);
      return FlowyNetworkImage(
        url: value,
        userProfilePB: userProfilePB,  // 用于认证的用户配置
      );
    }

    // 处理内置图片资源
    if (type == PageStyleCoverImageType.builtInImage) {
      return Image.asset(
        PageStyleCoverImageType.builtInImagePath(value),
        fit: BoxFit.cover,  // 覆盖填充，保持纵横比
      );
    }

    // 处理纯色封面
    if (type == PageStyleCoverImageType.pureColor) {
      final color = value.coverColor(context);  // 解析颜色值
      if (color != null) {
        return ColoredBox(
          color: color,
        );
      }
    }

    // 处理渐变色封面
    if (type == PageStyleCoverImageType.gradientColor) {
      return Container(
        decoration: BoxDecoration(
          // 根据ID获取对应的线性渐变
          gradient: FlowyGradientColor.fromId(value).linear,
        ),
      );
    }

    // 处理本地图片文件
    if (type == PageStyleCoverImageType.localImage) {
      return Image.file(
        File(value),
        fit: BoxFit.cover,  // 覆盖填充，保持纵横比
      );
    }

    return placeholder;
  }

  /// 构建V1版本格式的封面
  /// 
  /// V1版本是旧格式，主要用于向下兼容
  /// 参数：
  /// - context: 构建上下文
  /// - value: 封面值
  /// - placeholder: 默认占位图
  /// 
  /// 返回值：封面Widget
  Widget _buildCoverV1(BuildContext context, String value, Widget placeholder) {
    switch (coverTypeV1) {
      // 文件类型封面（可能是本地文件或网络URL）
      case CoverType.file:
        // 如果是URL则作为网络图片加载
        if (isURL(value)) {
          final userProfilePB = Provider.of<UserProfilePB?>(context);
          return FlowyNetworkImage(
            url: value,
            userProfilePB: userProfilePB,
          );
        }
        // 否则作为本地文件处理
        final imageFile = File(value);
        // 检查文件是否存在
        if (!imageFile.existsSync()) {
          return placeholder;
        }
        return Image.file(
          imageFile,
        );
      // 应用资源文件类型
      case CoverType.asset:
        return Image.asset(
          value,
          fit: BoxFit.cover,
        );
      // 颜色类型封面
      case CoverType.color:
        final color = value.tryToColor() ?? Colors.white;
        return Container(
          color: color,
        );
      // 无封面类型
      case CoverType.none:
        return placeholder;
    }
  }
}
