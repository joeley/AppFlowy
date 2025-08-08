import 'package:appflowy/shared/feature_flags.dart';
import 'package:flutter/foundation.dart';

import '../startup.dart';

/*
 * 特性开关任务
 * 
 * 管理应用程序的功能特性开关
 * 
 * 主要用途：
 * 1. A/B测试
 * 2. 渐进式发布新功能
 * 3. 紧急关闭有问题的功能
 * 4. 按用户级别启用功能
 * 
 * 设计理念：
 * - 允许在不发布新版本的情况下控制功能
 * - 降低新功能发布的风险
 * - 支持灵活的功能管理策略
 */

class FeatureFlagTask extends LaunchTask {
  const FeatureFlagTask();

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    /* 特性开关仅在调试模式下初始化
     * 
     * 原因：
     * 1. 生产环境通过远程配置管理
     * 2. 避免用户直接操作特性开关
     * 3. 开发环境需要快速切换特性
     * 
     * 注意：注释中提到的“快捷键管理器”可能是过时的
     * 实际上这里是初始化特性开关系统
     */
    if (!kDebugMode) {
      return;
    }

    /* 初始化特性开关系统
     * 加载默认配置和本地覆盖设置
     */
    await FeatureFlag.initialize();
  }
}
