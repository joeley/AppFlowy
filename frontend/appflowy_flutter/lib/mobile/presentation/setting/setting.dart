/// 移动端设置模块的统一导出文件
/// 
/// 设计思想：
/// 1. 作为设置模块的对外接口，统一管理所有设置相关组件的导出
/// 2. 遵循Flutter的模块化设计原则，将相关功能组织在一起
/// 3. 简化对外接口，使得其他模块只需要import一个文件即可访问所有设置功能
/// 4. 提高代码的可维护性，新增或修改设置组件时只需在此处更新导出
///
/// 模块组织结构：
/// - about/: 关于页面相关组件，包含应用信息、版本号等
/// - appearance/: 外观设置组，包含主题、颜色、布局等设置
/// - font/: 字体设置，包含字体大小、字体类型等配置
/// - language_setting_group: 语言设置组，支持多语言切换
/// - notifications_setting_group: 通知设置组，管理通知相关的首选项
/// - personal_info/: 个人信息设置，包含用户资料、账户管理等
/// - support_setting_group: 支持设置组，包含帮助、反馈、联系方式等
/// - widgets/: 设置模块中的通用UI组件，如设置项、分组头部等

// 导出关于页面相关组件
export 'about/about.dart';
// 导出外观设置组，包含主题和视觉样式设置
export 'appearance/appearance_setting_group.dart';
// 导出字体设置组，管理字体相关的配置
export 'font/font_setting.dart';
// 导出语言设置组，支持多语言切换功能
export 'language_setting_group.dart';
// 导出通知设置组，管理推送通知和提醒设置
export 'notifications_setting_group.dart';
// 导出个人信息设置组，包含用户资料管理
export 'personal_info/personal_info.dart';
// 导出支持设置组，提供帮助和支持相关功能
export 'support_setting_group.dart';
// 导出设置模块的通用UI组件
export 'widgets/widgets.dart';
