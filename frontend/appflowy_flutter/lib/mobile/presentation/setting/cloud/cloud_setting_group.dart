// 移动端云设置组组件文件
// 管理云服务配置，支持不同类型的云服务接入（AppFlowy Cloud、自建服务等）
// 通过异步获取身份验证类型，动态显示当前使用的云服务
import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/mobile/presentation/setting/cloud/appflowy_cloud_page.dart';
import 'package:appflowy/mobile/presentation/setting/widgets/mobile_setting_group_widget.dart';
import 'package:appflowy/mobile/presentation/setting/widgets/mobile_setting_item_widget.dart';
import 'package:appflowy/mobile/presentation/setting/widgets/mobile_setting_trailing.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/setting_cloud.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 移动端云设置组组件
/// 
/// 设计思想：
/// 1. 使用FutureBuilder处理异步加载云服务配置信息
/// 2. 支持多种身份验证类型（AppFlowy Cloud、自建服务等）
/// 3. 采用MobileSettingGroup组件统一样式，保持设置页面一致性
/// 4. 通过路由导航到专门的云设置页面
/// 
/// 功能特性：
/// - 异步获取并显示当前云服务类型
/// - 支持点击进入详细配置页面
/// - 提供默认值处理，确保程序稳定性
/// 
/// 架构设计：
/// - 通过cloud_env模块获取环境配置
/// - 使用go_router进行页面路由管理
/// - 依赖setting_cloud模块的工具函数
class CloudSettingGroup extends StatelessWidget {
  /// 构造函数
  /// 
  /// 不需要额外参数，所有配置信息通过异步方式获取
  const CloudSettingGroup({
    super.key,
  });

  /// 构建云设置组UI
  /// 
  /// 使用FutureBuilder处理异步数据加载：
  /// 1. 异步获取当前身份验证类型
  /// 2. 根据类型生成相应的显示名称
  /// 3. 构建设置组UI，包含云服务器设置项
  /// 
  /// 错误处理：
  /// - 当获取身份验证类型失败时，使用AppFlowy Cloud作为默认值
  /// - 确保在网络错误或配置错误情况下程序依然可用
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getAuthenticatorType(), // 异步获取身份验证类型
      builder: (context, snapshot) {
        // 处理异步结果，提供默认值保证程序稳定性
        final cloudType = snapshot.data ?? AuthenticatorType.appflowyCloud;
        final name = titleFromCloudType(cloudType); // 根据类型获取显示名称
        
        return MobileSettingGroup(
          groupTitle: 'Cloud settings', // 云设置组标题
          settingItemList: [
            MobileSettingItem(
              name: 'Cloud server', // 云服务器设置项标题
              trailing: MobileSettingTrailing(
                text: name, // 显示当前云服务类型名称
              ),
              onTap: () => context.push(AppFlowyCloudPage.routeName), // 跳转到云设置详情页面
            ),
          ],
        );
      },
    );
  }
}
