// 导入Dart IO库，用于平台信息获取
import 'dart:io';

// 导入Flutter核心UI库
import 'package:flutter/material.dart';

// 导入应用自定义的URL启动器工具
import 'package:appflowy/core/helpers/url_launcher.dart';
// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入包信息获取库，用于获取应用版本等信息
import 'package:package_info_plus/package_info_plus.dart';

// 状态容器类型枚举
// 定义了两种主要的状态容器类型
enum _FlowyMobileStateContainerType {
  info,   // 信息状态（如空状态、提示信息等）
  error,  // 错误状态（显示错误信息和操作按钮）
}

/**
 * AppFlowy移动端状态容器组件
 * 
 * 设计思想：
 * 1. 统一的状态展示容器，用于显示信息状态和错误状态
 * 2. 错误状态提供用户反馈机制，增强用户体验
 * 3. 采用工厂构造函数模式，简化不同状态的创建
 * 
 * 功能特点：
 * - 支持两种状态：信息状态（空状态、提示等）和错误状态
 * - 错误状态包含两个操作按钮：报告问题和联系Discord
 * - 自动获取应用版本和平台信息用于错误报告
 * - 居中显示，提供良好的视觉体验
 */
class FlowyMobileStateContainer extends StatelessWidget {
  // 错误状态构造函数
  // 用于创建显示错误信息的状态容器，包含错误消息和操作按钮
  const FlowyMobileStateContainer.error({
    this.emoji,           // 可选的表情符号
    required this.title,  // 必需的错误标题
    this.description,     // 可选的错误描述
    required this.errorMsg, // 必需的错误消息（用于bug报告）
    super.key,
  }) : _stateType = _FlowyMobileStateContainerType.error;

  // 信息状态构造函数
  // 用于创建显示信息内容的状态容器，如空状态、提示信息等
  const FlowyMobileStateContainer.info({
    this.emoji,           // 可选的表情符号
    required this.title,  // 必需的信息标题
    this.description,     // 可选的信息描述
    super.key,
  })  : errorMsg = null,  // 信息状态不需要错误消息
        _stateType = _FlowyMobileStateContainerType.info;

  final String? emoji;        // 表情符号，用于增强视觉表达
  final String title;         // 主标题文本
  final String? description;  // 描述文本，提供更多详细信息
  final String? errorMsg;     // 错误消息，仅在错误状态下使用
  final _FlowyMobileStateContainerType _stateType; // 内部状态类型标识

  @override
  Widget build(BuildContext context) {
    // 获取当前主题，用于统一的视觉风格
    final theme = Theme.of(context);

    // 创建全屏展开的容器，内容居中显示
    return SizedBox.expand(
      child: Padding(
        // 设置合适的内边距，确保内容不贴边
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
        child: Column(
          // 垂直居中对齐所有内容
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 显示表情符号，如果未提供则使用默认值
            Text(
              emoji ??
                  // 错误状态默认显示UFO表情，信息状态默认为空
                  (_stateType == _FlowyMobileStateContainerType.error
                      ? '🛸'  // UFO表情象征"出错了"
                      : ''),
              style: const TextStyle(fontSize: 40), // 大尺寸表情符号
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8), // 表情符号和标题之间的间距
            // 显示主标题
            Text(
              title,
              style: theme.textTheme.labelLarge, // 使用主题的大标签样式
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4), // 标题和描述之间的小间距
            // 显示描述文本
            Text(
              description ?? '', // 如果没有描述则显示空字符串
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor, // 使用提示色，降低视觉重要性
              ),
              textAlign: TextAlign.center,
            ),
            // 仅在错误状态下显示操作按钮
            if (_stateType == _FlowyMobileStateContainerType.error) ...[
              const SizedBox(height: 8), // 描述和按钮之间的间距
              // 使用FutureBuilder异步获取应用包信息
              FutureBuilder(
                future: PackageInfo.fromPlatform(), // 获取应用版本信息
                builder: (context, snapshot) {
                  // 创建按钮列，按钮宽度拉伸到最大
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // "报告问题"按钮
                      OutlinedButton(
                        onPressed: () {
                          // 获取应用版本信息
                          final String? version = snapshot.data?.version;
                          // 获取操作系统信息
                          final String os = Platform.operatingSystem;
                          // 构建GitHub issue URL，预填充版本、操作系统和错误信息
                          afLaunchUrlString(
                            'https://github.com/AppFlowy-IO/AppFlowy/issues/new?assignees=&labels=&projects=&template=bug_report.yaml&title=[Bug]%20Mobile:%20&version=$version&os=$os&context=Error%20log:%20$errorMsg',
                          );
                        },
                        child: Text(
                          LocaleKeys.workspace_errorActions_reportIssue.tr(),
                        ),
                      ),
                      // "联系我们"按钮，跳转到Discord社区
                      OutlinedButton(
                        onPressed: () =>
                            afLaunchUrlString('https://discord.gg/JucBXeU2FE'),
                        child: Text(
                          LocaleKeys.workspace_errorActions_reachOut.tr(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
