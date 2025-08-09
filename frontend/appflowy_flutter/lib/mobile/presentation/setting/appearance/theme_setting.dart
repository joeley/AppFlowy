// 移动端主题设置组件文件
// 提供主题模式选择功能，支持系统、明亮、暗黑三种主题模式
// 使用BLoC模式管理主题状态，通过底部弹窗进行选择
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/setting/widgets/mobile_setting_trailing.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/util/theme_mode_extension.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../setting.dart';

/// 移动端主题设置组件
/// 
/// 设计思想：
/// 1. 使用BLoC模式管理主题状态，确保状态一致性和可预测性
/// 2. 通过监听AppearanceSettingsCubit实时获取和显示当前主题状态
/// 3. 使用底部弹窗（BottomSheet）提供原生移动端体验
/// 4. 采用选项列表形式，包含图标和文本，增强用户理解
/// 
/// 支持的主题模式：
/// - 系统：跟随系统主题设置
/// - 明亮：强制使用明亮主题
/// - 暗黑：强制使用暗黑主题
/// 
/// 交互流程：
/// 1. 显示当前主题模式在trailing位置
/// 2. 点击后弹出选择底部弹窗
/// 3. 选择新主题后立即应用并关闭弹窗
class ThemeSetting extends StatelessWidget {
  /// 构造函数
  /// 
  /// 不需要额外参数，所有状态通过BLoC获取
  const ThemeSetting({
    super.key,
  });

  /// 构建主题设置UI
  /// 
  /// UI结构：
  /// 1. 使用MobileSettingItem作为基础容器，保持与其他设置项一致性
  /// 2. 显示本地化的主题标签
  /// 3. trailing位置显示当前主题模式
  /// 4. 点击后弹出选择底部弹窗
  @override
  Widget build(BuildContext context) {
    // 监听AppearanceSettingsCubit状态变化，获取当前主题模式
    final themeMode = context.watch<AppearanceSettingsCubit>().state.themeMode;
    return MobileSettingItem(
      name: LocaleKeys.settings_appearance_themeMode_label.tr(), // 使用本地化文本：“主题模式”
      trailing: MobileSettingTrailing(
        text: themeMode.labelText, // 显示当前主题模式的文本描述
      ),
      onTap: () {
        // 显示主题选择底部弹窗
        showMobileBottomSheet(
          context,
          showHeader: true, // 显示标题栏
          showDragHandle: true, // 显示拖拽手柄，提高可用性
          showDivider: false, // 不显示分割线
          title: LocaleKeys.settings_appearance_themeMode_label.tr(), // 弹窗标题
          builder: (context) {
            // 在弹窗中重新获取当前主题模式，确保数据一致性
            final themeMode =
                context.read<AppearanceSettingsCubit>().state.themeMode;
            return Column(
              children: [
                // 系统主题选项
                FlowyOptionTile.checkbox(
                  text: LocaleKeys.settings_appearance_themeMode_system.tr(), // 本地化文本：“系统”
                  leftIcon: const FlowySvg(
                    FlowySvgs.m_theme_mode_system_s, // 系统主题图标
                  ),
                  isSelected: themeMode == ThemeMode.system, // 检查是否为当前选中的主题
                  onTap: () {
                    // 设置为系统主题并关闭弹窗
                    context
                        .read<AppearanceSettingsCubit>()
                        .setThemeMode(ThemeMode.system);
                    Navigator.pop(context); // 关闭弹窗
                  },
                ),
                // 明亮主题选项
                FlowyOptionTile.checkbox(
                  showTopBorder: false, // 不显示顶部边框，与上一个选项连接
                  text: LocaleKeys.settings_appearance_themeMode_light.tr(), // 本地化文本：“明亮”
                  leftIcon: const FlowySvg(
                    FlowySvgs.m_theme_mode_light_s, // 明亮主题图标
                  ),
                  isSelected: themeMode == ThemeMode.light, // 检查是否为当前选中的主题
                  onTap: () {
                    // 设置为明亮主题并关闭弹窗
                    context
                        .read<AppearanceSettingsCubit>()
                        .setThemeMode(ThemeMode.light);
                    Navigator.pop(context); // 关闭弹窗
                  },
                ),
                // 暗黑主题选项
                FlowyOptionTile.checkbox(
                  showTopBorder: false, // 不显示顶部边框
                  text: LocaleKeys.settings_appearance_themeMode_dark.tr(), // 本地化文本：“暗黑”
                  leftIcon: const FlowySvg(
                    FlowySvgs.m_theme_mode_dark_s, // 暗黑主题图标
                  ),
                  isSelected: themeMode == ThemeMode.dark, // 检查是否为当前选中的主题
                  onTap: () {
                    // 设置为暗黑主题并关闭弹窗
                    context
                        .read<AppearanceSettingsCubit>()
                        .setThemeMode(ThemeMode.dark);
                    Navigator.pop(context); // 关闭弹窗
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
