/* AppFlowy后端SDK主包 */
import 'package:appflowy_backend/appflowy_backend.dart';
/* Rust后端通信调度器 */
import 'package:appflowy_backend/dispatch/dispatch.dart';
/* 错误类型定义 */
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
/* 用户Profile协议缓冲区类型 */
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
/* 用户设置协议缓冲区类型 */
import 'package:appflowy_backend/protobuf/flowy-user/user_setting.pb.dart';
/* 结果类型封装 */
import 'package:appflowy_result/appflowy_result.dart';

/**
 * 用户设置后端服务
 * 
 * 专门处理用户个人偏好设置的服务类，包括：
 * - 外观设置（主题、字体、颜色等）
 * - 日期时间设置（格式、时区等）
 * - 通知设置（推送偏好、提醒等）
 * - 其他用户个性化配置
 * 
 * 设计特点：
 * 1. **单一职责**：专注于用户设置管理，与认证服务分离
 * 2. **类型安全**：使用Protocol Buffer确保数据类型安全
 * 3. **错误处理**：统一的错误处理和异常管理
 * 4. **异步操作**：所有方法都是异步的，避免UI阻塞
 * 
 * 与其他服务的关系：
 * - 依赖UserBackendService获取用户基本信息
 * - 为UI层提供设置相关的数据和操作
 * - 与AuthService协作确保用户已登录
 * 
 * 这种分层架构的好处：
 * - 职责清晰，易于维护
 * - 可单独测试设置功能
 * - 支持设置的独立缓存和同步
 */
class UserSettingsBackendService {
  /**
   * 常量构造函数
   * 
   * 使用const构造函数因为这个服务类是无状态的，
   * 所有状态都存储在后端，前端只负责调用API
   */
  const UserSettingsBackendService();

  /**
   * 获取用户外观设置
   * 
   * 获取用户的个性化外观配置，包括主题、字体大小、颜色方案等。
   * 这些设置影响整个应用的视觉呈现。
   * 
   * @return Future<AppearanceSettingsPB> 外观设置对象
   *         包含：
   *         - 主题模式（亮色/暗色/跟随系统）
   *         - 字体设置（字体家族、大小）
   *         - 颜色配置（主色调、强调色等）
   *         - UI密度设置（紧凑/标准/宽松）
   * 
   * @throws FlowySDKException 当外观设置为空时抛出异常
   * 
   * 使用场景：
   * - 应用启动时加载用户偏好
   * - 设置页面显示当前配置
   * - 主题切换功能
   */
  Future<AppearanceSettingsPB> getAppearanceSetting() async {
    // 调用后端事件获取外观设置
    final result = await UserEventGetAppearanceSetting().send();

    /* 使用fold方法处理FlowyResult类型的返回值
     * 成功时直接返回设置对象
     * 失败时抛出SDK异常而不是返回错误对象
     * 这样可以让调用者使用标准的try-catch处理异常
     */
    return result.fold(
      (AppearanceSettingsPB setting) => setting,
      (error) =>
          throw FlowySDKException(ExceptionType.AppearanceSettingsIsEmpty),
    );
  }

  /**
   * 获取用户完整设置信息
   * 
   * 获取用户的所有设置信息，这是一个综合性的设置对象，
   * 包含用户的各类偏好和配置信息。
   * 
   * @return FlowyResult<UserSettingPB, FlowyError>
   *         成功：包含完整用户设置的对象
   *               可能包含：语言设置、时区、通知偏好等
   *         失败：错误信息（网络错误、权限错误等）
   * 
   * 与getAppearanceSetting的区别：
   * - 这个方法返回更全面的设置信息
   * - 使用FlowyResult类型，调用者需要手动处理成功/失败情况
   * - 不会抛出异常，错误通过Result类型返回
   * 
   * 适用场景：
   * - 需要一次性获取多种设置时
   * - 设置备份和恢复功能
   * - 设置的批量操作
   */
  Future<FlowyResult<UserSettingPB, FlowyError>> getUserSetting() {
    return UserEventGetUserSetting().send();
  }

  /**
   * 设置用户外观配置
   * 
   * 更新用户的外观偏好设置，更改会立即生效并同步到服务器。
   * 
   * @param setting 新的外观设置对象
   *                包含要更新的所有外观相关配置
   * @return FlowyResult<void, FlowyError>
   *         成功：void（无返回值，表示设置成功）
   *         失败：错误信息（验证失败、网络错误等）
   * 
   * 设置流程：
   * 1. 验证设置参数的有效性
   * 2. 发送到后端进行保存
   * 3. 后端验证并持久化设置
   * 4. 返回操作结果
   * 
   * 注意事项：
   * - 设置会立即生效，UI应该相应更新
   * - 网络错误时设置可能不会同步到服务器
   * - 某些设置可能需要重启应用才能完全生效
   */
  Future<FlowyResult<void, FlowyError>> setAppearanceSetting(
    AppearanceSettingsPB setting,
  ) {
    return UserEventSetAppearanceSetting(setting).send();
  }

  /**
   * 获取用户日期时间设置
   * 
   * 获取用户偏好的日期时间格式和显示设置，
   * 这影响整个应用中日期和时间的显示方式。
   * 
   * @return Future<DateTimeSettingsPB> 日期时间设置对象
   *         包含：
   *         - 日期格式（YYYY-MM-DD、MM/DD/YYYY等）
   *         - 时间格式（12小时制/24小时制）
   *         - 时区设置
   *         - 首周日设置（周一/周日开始）
   *         - 日期分隔符偏好
   * 
   * @throws FlowySDKException 当日期时间设置为空时抛出异常
   * 
   * 使用场景：
   * - 日历组件的日期显示
   * - 文档创建/修改时间显示
   * - 提醒和截止日期格式化
   * - 数据导出时的日期格式
   */
  Future<DateTimeSettingsPB> getDateTimeSettings() async {
    final result = await UserEventGetDateTimeSettings().send();

    return result.fold(
      (DateTimeSettingsPB setting) => setting,
      (error) =>
          throw FlowySDKException(ExceptionType.AppearanceSettingsIsEmpty),
    );
  }

  /**
   * 设置用户日期时间偏好
   * 
   * 更新用户的日期时间格式设置，影响全局的日期时间显示。
   * 
   * @param settings 新的日期时间设置对象
   * @return FlowyResult<void, FlowyError>
   *         成功：void（设置更新成功）
   *         失败：错误信息（格式无效、网络错误等）
   * 
   * 设置影响：
   * - 立即影响所有日期时间的显示
   * - 可能影响已存在数据的显示格式
   * - 不会改变数据的存储格式（只影响显示）
   * 
   * 验证规则：
   * - 时区必须是有效的IANA时区标识
   * - 日期格式必须是支持的格式之一
   * - 设置之间必须兼容（如某些地区的格式约定）
   */
  Future<FlowyResult<void, FlowyError>> setDateTimeSettings(
    DateTimeSettingsPB settings,
  ) async {
    return UserEventSetDateTimeSettings(settings).send();
  }

  /**
   * 设置用户通知偏好
   * 
   * 配置用户的通知接收偏好，包括推送通知、邮件提醒等。
   * 这些设置直接影响用户接收到的通知类型和频率。
   * 
   * @param settings 通知设置对象
   *                 包含各种通知开关和偏好
   * @return FlowyResult<void, FlowyError>
   *         成功：void（通知设置更新成功）
   *         失败：错误信息（权限不足、设置冲突等）
   * 
   * 通知类型可能包括：
   * - 文档评论和协作通知
   * - 任务和截止日期提醒
   * - 系统更新和维护通知
   * - 工作区邀请和成员变更
   * 
   * 隐私和权限：
   * - 某些通知可能需要系统权限
   * - 用户可以精细控制每种通知类型
   * - 设置会影响推送服务的订阅状态
   */
  Future<FlowyResult<void, FlowyError>> setNotificationSettings(
    NotificationSettingsPB settings,
  ) async {
    return UserEventSetNotificationSettings(settings).send();
  }

  /**
   * 获取用户通知设置
   * 
   * 获取用户当前的通知偏好配置，用于在设置界面显示或决定是否发送通知。
   * 
   * @return Future<NotificationSettingsPB> 通知设置对象
   *         包含：
   *         - 推送通知开关（总开关和分类开关）
   *         - 邮件通知偏好
   *         - 通知时间段设置（免打扰时间）
   *         - 通知声音和震动设置
   *         - 各种事件的通知级别
   * 
   * @throws FlowySDKException 当通知设置为空时抛出异常
   * 
   * 使用场景：
   * - 设置页面显示当前通知状态
   * - 发送通知前检查用户偏好
   * - 通知权限管理
   * - 用户体验个性化
   * 
   * 注意事项：
   * - 设置可能受系统权限限制
   * - 某些通知类型可能被管理员强制开启/关闭
   * - 不同平台的通知行为可能有差异
   */
  Future<NotificationSettingsPB> getNotificationSettings() async {
    final result = await UserEventGetNotificationSettings().send();

    return result.fold(
      (NotificationSettingsPB setting) => setting,
      (error) =>
          throw FlowySDKException(ExceptionType.AppearanceSettingsIsEmpty),
    );
  }
}
