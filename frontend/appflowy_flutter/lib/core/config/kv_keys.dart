/* 
 * AppFlowy键值存储常量定义类
 *
 * 作用：
 * - 集中管理所有SharedPreferences的键名常量
 * - 避免字符串硬编码和键名冲突
 * - 提供统一的命名规范和文档
 * 
 * 设计原则：
 * - 使用常量类模式，防止实例化（私有构造函数）
 * - 所有键都有统一前缀，避免与其他插件冲突
 * - 键名采用camelCase命名约定，与Dart风格保持一致
 * - 每个键都有详细的注释说明其用途和数据格式
 */
class KVKeys {
  // 私有构造函数，防止类被实例化
  // 这是一个纯静态工具类，不应该被实例化
  const KVKeys._();

  /* 全局键名前缀
   * 用途：防止与Flutter生态系统中的其他包或插件产生键名冲突
   * 格式：采用反向域名格式，确保全局唯一性
   */
  static const String prefix = 'io.appflowy.appflowy_flutter';

  /* === 文件系统和路径相关配置 === */
  
  /* 应用数据存储路径配置键
   * 
   * 存储内容：AppFlowy数据目录的完整路径
   * 数据格式：字符串路径，例如：
   *   - Windows: "C:\Users\<用户名>\AppData\Roaming\AppFlowyDataDoNotRename"
   *   - macOS: "/Users/<用户名>/Library/Application Support/AppFlowyDataDoNotRename"  
   *   - Linux: "/home/<用户名>/.config/AppFlowyDataDoNotRename"
   * 
   * 重要性：这是AppFlowy最关键的配置项之一
   * - 决定了用户数据、文档、数据库的存储位置
   * - 支持用户自定义数据存储路径
   * - 路径变更会影响所有用户数据的访问
   */
  static const String pathLocation = '$prefix.path_location';

  /* === 桌面应用窗口状态配置 === */
  
  /* 窗口尺寸配置键
   * 
   * 存储内容：应用窗口的宽度和高度信息
   * 数据格式：JSON字符串，包含以下字段：
   *   - height: double类型，窗口高度（像素）
   *   - width: double类型，窗口宽度（像素）
   * 示例值：'{"height": 600.0, "width": 800.0}'
   * 
   * 用途：
   * - 桌面应用启动时恢复用户的窗口尺寸偏好
   * - 提供一致的用户体验，避免每次启动都重新调整窗口大小
   * - 支持不同屏幕分辨率下的自适应显示
   */
  static const String windowSize = 'windowSize';

  /* 窗口位置配置键
   * 
   * 存储内容：应用窗口在屏幕上的位置坐标
   * 数据格式：JSON字符串，包含以下字段：
   *   - dx: double类型，窗口左上角的X坐标（像素）
   *   - dy: double类型，窗口左上角的Y坐标（像素）
   * 示例值：'{"dx": 100.0, "dy": 50.0}'
   * 
   * 用途：
   * - 应用启动时恢复用户的窗口位置偏好
   * - 处理多显示器场景，确保窗口在可见区域内
   * - 提供更好的工作流程连续性
   */
  static const String windowPosition = 'windowPosition';

  /* 窗口最大化状态配置键
   * 
   * 存储内容：应用窗口的最大化状态
   * 数据格式：JSON字符串，包含布尔值字段：
   *   - windowMaximized: boolean类型，true表示最大化，false表示正常窗口
   * 示例值：'{"windowMaximized": true}'
   * 
   * 用途：
   * - 记住用户的窗口状态偏好（最大化或正常窗口）
   * - 应用重启时自动恢复窗口状态
   * - 提供一致的多会话体验
   */
  static const String windowMaximized = 'windowMaximized';

  /* === 文档编辑器外观配置 === */
  
  /* 文档字体大小配置键
   * 
   * 存储内容：文档编辑器的字体大小设置
   * 数据格式：字符串形式的数字，例如："16.0"
   * 取值范围：通常在12.0-24.0像素之间
   * 
   * 影响范围：
   * - 文档正文的字体大小
   * - 影响文档的阅读体验和可访问性
   * - 与系统字体缩放设置协同工作
   */
  static const String kDocumentAppearanceFontSize =
      'kDocumentAppearanceFontSize';
      
  /* 文档字体族配置键
   * 
   * 存储内容：文档编辑器使用的字体族名称
   * 数据格式：字符串，例如："Roboto"、"SF Pro"、"Noto Sans"
   * 
   * 支持的字体类型：
   * - 系统内置字体
   * - Google Fonts字体族
   * - 用户安装的自定义字体
   * 
   * 影响范围：文档内容的字体渲染和视觉效果
   */
  static const String kDocumentAppearanceFontFamily =
      'kDocumentAppearanceFontFamily';
      
  /* 文档默认文本方向配置键
   * 
   * 存储内容：文档的默认文本书写方向
   * 数据格式：枚举字符串，可能的值：
   *   - "ltr": 从左到右（Left-to-Right），用于英语、中文等
   *   - "rtl": 从右到左（Right-to-Left），用于阿拉伯语、希伯来语等
   * 
   * 用途：
   * - 支持多语言国际化
   * - 影响文本对齐、光标移动、选择行为
   * - 决定UI元素的布局方向
   */
  static const String kDocumentAppearanceDefaultTextDirection =
      'kDocumentAppearanceDefaultTextDirection';
      
  /* 文档光标颜色配置键
   * 
   * 存储内容：文档编辑器中光标（插入符）的颜色
   * 数据格式：16进制颜色字符串，例如："#FF0000FF"（ARGB格式）
   * 
   * 用途：
   * - 个性化编辑器外观
   * - 提高光标的可见性
   * - 与主题颜色保持一致性
   */
  static const String kDocumentAppearanceCursorColor =
      'kDocumentAppearanceCursorColor';
      
  /* 文档选择区域颜色配置键
   * 
   * 存储内容：文档中文本选择区域的背景颜色
   * 数据格式：16进制颜色字符串，例如："#3300FF00"（ARGB格式）
   * 
   * 用途：
   * - 突出显示选中的文本
   * - 提供清晰的视觉反馈
   * - 与整体主题色彩搭配
   */
  static const String kDocumentAppearanceSelectionColor =
      'kDocumentAppearanceSelectionColor';
      
  /* 文档宽度配置键
   * 
   * 存储内容：文档编辑器的显示宽度设置
   * 数据格式：字符串形式的数字，例如："800.0"
   * 
   * 用途：
   * - 控制文档内容的显示宽度
   * - 提供类似纸张的阅读体验
   * - 在宽屏显示器上避免过长的文本行
   * - 支持专注模式的阅读体验
   */
  static const String kDocumentAppearanceWidth = 'kDocumentAppearanceWidth';

  /* === 界面状态和布局配置 === */
  
  /* 展开视图状态配置键
   * 
   * 存储内容：侧边栏中各视图的展开/折叠状态
   * 数据格式：JSON字符串，键值对格式：
   *   - 键：viewId（字符串）- 视图的唯一标识符
   *   - 值：boolean - true表示展开，false表示折叠
   * 示例值：'{"view_123": true, "view_456": false}'
   * 
   * 用途：
   * - 记住用户对文档树结构的展开偏好
   * - 提供一致的导航体验
   * - 支持大型文档库的快速导航
   */
  static const String expandedViews = 'expandedViews';

  /* 展开文件夹状态配置键
   * 
   * 存储内容：侧边栏中各文件夹类别的展开/折叠状态
   * 数据格式：JSON字符串，键值对格式：
   *   - 键：文件夹类别枚举值（字符串）
   *   - 值：boolean - true表示展开，false表示折叠
   * 示例值：'{"recent": true, "favorites": false}'
   * 
   * 文件夹类别包括：
   * - 最近使用 (Recent)
   * - 收藏夹 (Favorites)  
   * - 工作空间 (Workspace)
   * - 回收站 (Trash)
   */
  static const String expandedFolders = 'expandedFolders';

  /* 创建文件时显示重命名对话框配置键
   * 
   * @deprecated 在版本0.7.6中已废弃
   * 
   * 存储内容：是否在创建新文件时显示重命名对话框
   * 数据格式：布尔值的字符串表示，"true"或"false"
   * 
   * 废弃原因：用户体验优化，改为更直观的交互方式
   * 替代方案：新的文件创建流程不再需要此配置
   */
  static const String showRenameDialogWhenCreatingNewFile =
      'showRenameDialogWhenCreatingNewFile';

  /* === 云服务和同步配置 === */
  
  /* 云服务类型配置键
   * 
   * 存储内容：当前使用的云服务提供商类型
   * 数据格式：枚举字符串，可能的值：
   *   - "local": 纯本地存储，不使用云同步
   *   - "supabase": 使用Supabase作为后端服务
   *   - "appflowy_cloud": 使用AppFlowy官方云服务
   * 
   * 影响范围：
   * - 数据同步策略
   * - 用户认证方式
   * - 协作功能的可用性
   */
  static const String kCloudType = 'kCloudType';
  
  /* AppFlowy云服务基础URL配置键
   * 
   * 存储内容：AppFlowy云服务的API基础地址
   * 数据格式：URL字符串，例如："https://beta.appflowy.cloud"
   * 
   * 用途：
   * - 支持不同环境的云服务切换（生产、测试、自部署）
   * - 允许企业用户使用私有部署的云服务
   * - 提供灵活的服务端配置选项
   */
  static const String kAppflowyCloudBaseURL = 'kAppFlowyCloudBaseURL';
  
  /* AppFlowy分享域名配置键
   * 
   * 存储内容：文档分享功能使用的域名
   * 数据格式：域名字符串，例如："share.appflowy.io"
   * 
   * 用途：
   * - 生成公开分享链接
   * - 支持自定义分享域名
   * - 企业品牌定制需求
   */
  static const String kAppFlowyBaseShareDomain = 'kAppFlowyBaseShareDomain';
  
  /* 同步追踪功能开关配置键
   * 
   * 存储内容：是否启用数据同步的详细日志追踪
   * 数据格式：布尔值字符串，"true"或"false"
   * 
   * 用途：
   * - 调试同步问题时启用详细日志
   * - 性能分析和问题诊断
   * - 开发和测试环境的调试工具
   * 
   * 注意：生产环境应谨慎启用，可能影响性能
   */
  static const String kAppFlowyEnableSyncTrace = 'kAppFlowyEnableSyncTrace';

  /* === 显示和可访问性配置 === */
  
  /* 文本缩放系数配置键
   * 
   * 存储内容：全局文本大小的缩放倍数
   * 数据格式：double类型的字符串，例如："0.9"
   * 取值范围：0.8 - 1.0
   *   - 0.8: 最小缩放，文本较小但信息密度高
   *   - 1.0: 默认缩放，标准文本大小
   *   - >1.0: 不推荐，会导致文本过大且与图标不对齐
   * 
   * 影响范围：
   * - 整个应用的文本显示大小
   * - UI组件的文本渲染
   * - 提高视力有困难用户的可访问性
   * 
   * 设计考虑：
   * - 与系统文本缩放设置协同工作
   * - 保持UI布局的视觉平衡
   * - 支持不同屏幕尺寸和分辨率
   */
  static const String textScaleFactor = 'textScaleFactor';

  /* 功能开关配置键
   * 
   * 存储内容：应用的功能开关状态集合
   * 数据格式：JSON字符串，键值对格式：
   *   - 键：功能开关名称（字符串）
   *   - 值：boolean - true表示启用，false表示禁用
   * 示例值：'{"ai_assistant": true, "advanced_search": false}'
   * 
   * 用途：
   * - A/B测试和灰度发布
   * - 实验性功能的开关控制
   * - 用户自定义功能启用/禁用
   * - 不同版本功能的渐进式发布
   * 
   * 常见功能开关：
   * - AI助手功能
   * - 高级搜索
   * - 实时协作
   * - 新版编辑器
   * - 性能优化选项
   */
  static const String featureFlag = 'featureFlag';

  /* 通知图标显示配置键
   * 
   * 存储内容：是否在系统托盘/状态栏显示通知图标
   * 数据格式：布尔值字符串，"true"或"false"
   * 
   * 用途：
   * - 控制桌面应用的系统托盘图标显示
   * - 用户可选择是否显示通知提醒
   * - 提供简洁的桌面体验选项
   * 
   * 平台差异：
   * - Windows: 系统托盘图标
   * - macOS: 菜单栏图标
   * - Linux: 系统托盘图标
   * - 移动端: 不适用
   */
  static const String showNotificationIcon = 'showNotificationIcon';

  /* 最后打开的工作空间ID配置键
   * 
   * @deprecated 在版本0.5.5中已废弃
   * 
   * 存储内容：用户最后一次使用的工作空间唯一标识符
   * 数据格式：字符串形式的工作空间ID
   * 
   * 废弃原因：
   * - 工作空间管理机制重构
   * - 新的多工作空间架构不再需要此配置
   * - 改为使用更灵活的空间管理系统
   * 
   * 替代方案：使用lastOpenedSpaceId和相关的空间管理配置
   */
  @Deprecated('deprecated in version 0.5.5')
  static const String lastOpenedWorkspaceId = 'lastOpenedWorkspaceId';

  /* 界面缩放系数配置键
   * 
   * 存储内容：整个应用界面的缩放倍数
   * 数据格式：double类型的字符串，例如："1.2"
   * 
   * 与textScaleFactor的区别：
   * - scaleFactor: 影响整个UI界面的缩放（包括图标、间距、布局）
   * - textScaleFactor: 仅影响文本大小
   * 
   * 用途：
   * - 高DPI屏幕的适配
   * - 不同屏幕尺寸的界面优化
   * - 用户个人显示偏好设置
   * - 提升可访问性体验
   * 
   * 常见取值：
   * - 0.8: 紧凑模式
   * - 1.0: 标准大小
   * - 1.25: 中等放大
   * - 1.5: 大号显示
   */
  static const String scaleFactor = 'scaleFactor';

  /* === 空间和导航状态配置 === */
  
  /* 最后打开的空间页签配置键
   * 
   * 存储内容：用户最后查看的空间页签索引
   * 数据格式：整数的字符串表示，例如："1"
   * 
   * 空间类型对应的索引：
   *   - 0: 收藏夹 (Favorites)
   *   - 1: 最近使用 (Recent)
   *   - 2: 工作空间 (Workspace)
   *   - 3: 其他自定义空间
   * 
   * 用途：
   * - 应用启动时自动打开用户上次浏览的空间
   * - 提供连续的用户体验
   * - 保持工作流的上下文
   */
  static const String lastOpenedSpace = 'lastOpenedSpace';

  /* 空间页签顺序配置键
   * 
   * 存储内容：侧边栏中空间页签的排列顺序
   * 数据格式：JSON数组字符串，包含页签索引的顺序
   * 示例值："[2, 0, 1]" - 表示工作空间、收藏夹、最近使用的顺序
   * 
   * 用途：
   * - 用户可以自定义空间页签的顺序
   * - 支持拖放重新排列
   * - 根据使用习惯优化界面布局
   * - 个性化工作空间组织
   */
  static const String spaceOrder = 'spaceOrder';

  /* 最后打开的空间ID配置键
   * 
   * 存储内容：用户最后浏览的具体空间的唯一标识符
   * 数据格式：字符串形式的空间ID，例如："space_abc123"
   * 
   * 与lastOpenedSpace的区别：
   * - lastOpenedSpace: 记录空间页签的类型（收藏夹、最近等）
   * - lastOpenedSpaceId: 记录具体的空间实例（空间A、空间B等）
   * 
   * 用途：
   * - 在多空间环境中记录用户的当前工作上下文
   * - 应用重启时自动恢复到上次使用的空间
   * - 支持空间间的快速切换
   */
  static const String lastOpenedSpaceId = 'lastOpenedSpaceId';

  /* 空间升级标记配置键
   * 
   * 存储内容：标记用户是否已经升级到新的空间系统
   * 数据格式：布尔值字符串，"true"或"false"
   * 版本标识：060 表示版本0.6.0的空间升级
   * 
   * 用途：
   * - 防止重复执行数据升级操作
   * - 版本迁移时的状态跟踪
   * - 确保用户数据的兼容性
   * - 在新版本中显示相应的引导信息
   */
  static const String hasUpgradedSpace = 'hasUpgradedSpace060';

  /* 最近使用图标配置键
   * 
   * 存储内容：用户最近使用的图标列表
   * 数据格式：RecentIcons类型的JSON字符串
   * 包含信息：
   *   - 图标的Unicode编码或文件路径
   *   - 使用频次和时间戳
   *   - 图标类型（emoji、系统图标等）
   * 
   * 用途：
   * - 在图标选择器中优先显示常用图标
   * - 提高图标选择的效率和便利性
   * - 个性化用户界面体验
   * - 快速访问常用的视觉元素
   */
  static const String recentIcons = 'kRecentIcons';

  /* 紧凑模式启用的视图ID配置键
   * 
   * 存储内容：启用紧凑显示模式的视图或数据库的ID列表
   * 数据格式：JSON数组字符串，包含ID列表
   * 示例值："[\"node_123\", \"db_456\"]"
   * 
   * 紧凑模式特性：
   * - 减少文档和数据库视图的行间距
   * - 在有限空间内显示更多内容
   * - 提高信息密度和浏览效率
   * 
   * 用途：
   * - 用户可以针对不同的文档和数据库设置不同的显示密度
   * - 在小屏幕或分屏工作时提高空间利用率
   * - 个性化的阅读和编辑体验
   */
  static const String compactModeIds = 'compactModeIds';

  /* === 用户行为和交互状态 === */
  
  /* 升级到Pro版本按钮点击状态配置键
   * 
   * 版本：v0.9.4
   * 存储内容：用户是否已经点击过升级到Pro版本的按钮
   * 数据格式：布尔值字符串，"true"或"false"
   * 
   * 用途：
   * - 跟踪用户对付费功能的兴趣程度
   * - 优化产品推广和营销策略
   * - 避免重复展示升级提示
   * - 用户转换漏斗分析
   * 
   * 数据隐私：
   * - 仅记录点击行为，不包含个人敏感信息
   * - 用于本地交互优化，不会上传到服务器
   */
  static const String hasClickedUpgradeToProButton =
      'hasClickedUpgradeToProButton';
}
