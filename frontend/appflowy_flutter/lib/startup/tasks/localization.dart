// 国际化库
import 'package:easy_localization/easy_localization.dart';

import '../startup.dart';

/// 国际化初始化任务
/// 
/// 负责初始化应用的多语言支持
/// 
/// AppFlowy支持30+种语言，这个任务确保：
/// 1. 语言资源正确加载
/// 2. 本地化服务就绪
/// 3. 日期、时间、数字格式化准备就绪
/// 
/// 这个任务必须在UI初始化之前执行
/// 因为UI中的文本需要根据用户语言设置显示
/// 
/// 类似于Android的Resources系统或iOS的NSLocalizedString
class InitLocalizationTask extends LaunchTask {
  const InitLocalizationTask();

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 确保EasyLocalization初始化完成
    // 这会加载语言文件并准备翻译系统
    await EasyLocalization.ensureInitialized();
    
    // 禁用构建模式下的日志输出
    // 避免在生产环境产生不必要的日志
    EasyLocalization.logger.enableBuildModes = [];
  }
}
