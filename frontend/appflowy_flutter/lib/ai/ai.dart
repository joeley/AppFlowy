/// AI模块统一导出文件
/// 
/// 本文件作为AI功能模块的统一入口，导出所有AI相关的服务、状态管理和UI组件
/// 使用方式：其他模块只需import 'package:appflowy/ai/ai.dart'即可访问所有AI功能
/// 
/// 模块架构：
/// - service层：提供AI核心服务、实体定义、状态管理
/// - widgets层：提供AI相关的UI组件和交互界面

// ============= AI服务层 =============
// AI核心实体定义：包含提示词、模型类型、格式化配置等数据结构
export 'service/ai_entities.dart';
// 提示词输入状态管理：处理用户输入的提示词内容和相关交互
export 'service/ai_prompt_input_bloc.dart';
// 提示词选择器状态管理：管理预定义提示词的选择和展示
export 'service/ai_prompt_selector_cubit.dart';
// AI服务核心接口：与后端AI服务的通信接口
export 'service/appflowy_ai_service.dart';
// AI错误处理：定义和处理AI相关的错误类型
export 'service/error.dart';
// AI模型状态通知器：监听和通知AI模型的状态变化
export 'service/ai_model_state_notifier.dart';
// 模型选择状态管理：管理AI模型的选择（如GPT、Claude等）
export 'service/select_model_bloc.dart';
// 视图选择器状态管理：管理AI可访问的文档视图选择
export 'service/view_selector_cubit.dart';

// ============= AI UI组件层 =============
// 通用加载指示器：显示AI处理中的加载状态
export 'widgets/loading_indicator.dart';
// 视图选择器组件：用于选择AI可访问的文档视图
export 'widgets/view_selector.dart';

// ============= 提示词输入组件 =============
// 动作按钮组：包含发送、取消等操作按钮
export 'widgets/prompt_input/action_buttons.dart';
// 桌面端提示词输入主组件：桌面端的完整输入界面
export 'widgets/prompt_input/desktop_prompt_input.dart';
// 文件附件列表：显示和管理附加的文件
export 'widgets/prompt_input/file_attachment_list.dart';
// 布局定义：定义提示词输入界面的布局常量
export 'widgets/prompt_input/layout_define.dart';
// 移动端页面提及底部弹窗：移动端的@提及页面选择器
export 'widgets/prompt_input/mention_page_bottom_sheet.dart';
// 页面提及菜单：桌面端的@提及页面下拉菜单
export 'widgets/prompt_input/mention_page_menu.dart';
// 提示词输入文本控制器：管理输入框的文本内容和格式
export 'widgets/prompt_input/prompt_input_text_controller.dart';
// 预定义格式按钮：选择输出格式（文本、图片、表格等）
export 'widgets/prompt_input/predefined_format_buttons.dart';
// 移动端数据源选择底部弹窗：移动端的数据源选择器
export 'widgets/prompt_input/select_sources_bottom_sheet.dart';
// 数据源选择菜单：选择AI可访问的数据源
export 'widgets/prompt_input/select_sources_menu.dart';
// 模型选择菜单：选择使用的AI模型
export 'widgets/prompt_input/select_model_menu.dart';
// 发送按钮：触发AI请求的发送按钮
export 'widgets/prompt_input/send_button.dart';
