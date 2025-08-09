/// AppFlowy移动端表示层(Presentation Layer)统一导出文件
/// 
/// 这个文件是AppFlowy移动端UI层的核心导出点，负责将整个表示层的关键组件统一对外暴露。
/// 采用了清晰的模块化架构设计，每个导出项对应一个主要的功能模块：
/// 
/// 设计思想：
/// 1. 单一入口原则：通过这个文件，其他模块只需导入presentation.dart即可访问所有UI组件
/// 2. 模块解耦：各个功能模块相互独立，通过统一导出实现松耦合
/// 3. 维护便利性：新增或修改UI模块时，只需在此处修改导出声明
/// 
/// 使用场景：
/// - 在路由配置中统一导入移动端页面组件
/// - 在主应用入口处批量导入移动端UI模块
/// - 为移动端UI测试提供统一的组件访问点

// 编辑器模块：提供文档编辑相关的移动端界面组件
export 'editor/mobile_editor_screen.dart';

// 首页模块：包含移动端主页、工作区、文件夹等核心导航界面
export 'home/home.dart';

// 底部导航栏：移动端主要的页面切换和导航组件
export 'mobile_bottom_navigation_bar.dart';

// 根占位页面：应用启动或加载时显示的占位界面
export 'root_placeholder_page.dart';

// 设置模块：用户偏好设置、应用配置等相关界面组件
export 'setting/setting.dart';
