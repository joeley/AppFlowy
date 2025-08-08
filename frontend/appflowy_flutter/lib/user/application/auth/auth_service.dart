/* Protocol Buffer相关的引入
 * Protocol Buffers是Google开发的序列化格式
 * 在AppFlowy中用于与Rust后端通信
 */
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

/**
 * 认证服务映射键类
 * 
 * 定义了认证过程中使用的常量键名
 * 这种模式的好处：
 * 1. 避免魔法字符串
 * 2. 提供编译时检查
 * 3. 便于维护和重构
 */
class AuthServiceMapKeys {
  /* 私有构造函数，防止实例化
   * 这个类只用作静态常量容器，类似于Java的工具类
   */
  const AuthServiceMapKeys._();

  /// 邮箱字段键
  static const String email = 'email';
  /// 设备ID字段键 - 用于标识唯一设备
  static const String deviceId = 'device_id';
  /// 登录URL字段键 - OAuth等场景使用
  static const String signInURL = 'sign_in_url';
}

/**
 * 认证服务抽象接口
 * 
 * 这是AppFlowy用户认证系统的核心抽象层，定义了所有认证相关操作。
 * 
 * 设计模式说明：
 * 1. **策略模式**：不同的认证方式（本地、云端、OAuth）有不同的实现类
 * 2. **接口隔离**：将认证功能从具体实现中分离
 * 3. **依赖反转**：UI层依赖于抽象接口，而非具体实现
 * 
 * 支持的认证方式：
 * - 邮箱密码登录
 * - OAuth第三方登录（GitHub、Google等）  
 * - 游客模式
 * - 魔法链接（无密码登录）
 * - 验证码登录
 */
abstract class AuthService {
  /**
   * 邮箱密码登录
   * 
   * 这是最传统的登录方式，用户输入邮箱和密码进行认证。
   * 
   * @param email 用户邮箱地址
   * @param password 用户密码（明文，加密由后端处理）
   * @param params 可选的额外参数，用于扩展功能
   *               例如：device_id、remember_me等
   * 
   * @return FlowyResult<GotrueTokenResponsePB, FlowyError>
   *         成功：返回Gotrue令牌响应（包含访问令牌、刷新令牌等）
   *         失败：返回错误信息（邮箱格式错误、密码错误等）
   * 
   * 实现细节：
   * - 密码在传输前会被加密
   * - 成功后返回JWT令牌用于后续API调用
   * - 支持设备记住功能
   */
  Future<FlowyResult<GotrueTokenResponsePB, FlowyError>>
      signInWithEmailPassword({
    required String email,
    required String password,
    Map<String, String> params,
  });

  /**
   * 用户注册
   * 
   * 创建新的用户账户，需要提供用户基本信息。
   * 
   * @param name 用户显示名称
   * @param email 用户邮箱地址（作为唯一标识）
   * @param password 用户密码（需符合密码强度要求）
   * @param params 可选的额外参数
   *               可能包括：邀请码、推荐人ID等
   * 
   * @return FlowyResult<UserProfilePB, FlowyError>
   *         成功：返回新创建的用户Profile信息
   *         失败：返回错误信息（邮箱已存在、密码强度不够等）
   * 
   * 注册流程：
   * 1. 验证邮箱格式和唯一性
   * 2. 验证密码强度
   * 3. 创建用户账户
   * 4. 发送验证邮件（可选）
   * 5. 返回用户Profile
   */
  Future<FlowyResult<UserProfilePB, FlowyError>> signUp({
    required String name,
    required String email,
    required String password,
    Map<String, String> params,
  });

  /**
   * OAuth第三方登录注册
   * 
   * 通过第三方OAuth提供商进行用户注册/登录。
   * 这是现代应用常用的社交登录方式。
   * 
   * @param platform 第三方平台名称
   *                 支持：'github', 'google', 'discord', 'apple'
   * @param params 可选的额外参数
   *               可能包括：redirect_url、scope等OAuth参数
   * 
   * @return FlowyResult<UserProfilePB, FlowyError>
   *         成功：返回用户Profile信息
   *         失败：返回错误信息（OAuth授权失败、平台不支持等）
   * 
   * OAuth流程：
   * 1. 重定向到第三方授权页面
   * 2. 用户在第三方平台授权
   * 3. 获取授权码并换取访问令牌
   * 4. 获取用户信息
   * 5. 创建或更新本地用户账户
   */
  Future<FlowyResult<UserProfilePB, FlowyError>> signUpWithOAuth({
    required String platform,
    Map<String, String> params,
  });

  /**
   * 游客模式登录
   * 
   * 允许用户在不注册的情况下体验应用功能。
   * 这是降低用户使用门槛的重要功能。
   * 
   * @param params 可选的额外参数
   *               可能包括：device_id、session_duration等
   * 
   * @return FlowyResult<UserProfilePB, FlowyError>
   *         成功：返回默认的游客用户Profile
   *         失败：返回错误信息（系统错误等）
   * 
   * 游客模式特点：
   * - 使用固定的游客邮箱和密码
   * - 数据可能不持久化或有时间限制
   * - 功能可能有一定限制
   * - 可以随时升级为正式账户
   */
  Future<FlowyResult<UserProfilePB, FlowyError>> signUpAsGuest({
    Map<String, String> params,
  });

  /**
   * 魔法链接登录
   * 
   * 无密码登录方式，通过邮件发送登录链接。
   * 这是现代应用提升用户体验的重要功能。
   * 
   * @param email 用户邮箱地址
   * @param params 可选的额外参数
   *               可能包括：redirect_url、expiry_time等
   * 
   * @return FlowyResult<void, FlowyError>
   *         成功：void（邮件发送成功）
   *         失败：返回错误信息（邮箱不存在、发送失败等）
   * 
   * 魔法链接流程：
   * 1. 用户输入邮箱地址
   * 2. 系统生成带令牌的登录链接
   * 3. 发送邮件到用户邮箱
   * 4. 用户点击链接完成登录
   * 5. 系统验证令牌并建立会话
   * 
   * 优势：
   * - 无需记住密码
   * - 安全性高（令牌有时效性）
   * - 用户体验好
   */
  Future<FlowyResult<void, FlowyError>> signInWithMagicLink({
    required String email,
    Map<String, String> params,
  });

  /**
   * 验证码登录
   * 
   * 通过邮件发送的验证码进行登录认证。
   * 结合了安全性和便利性的登录方式。
   * 
   * @param email 用户邮箱地址
   * @param passcode 邮件中收到的验证码（通常是6位数字）
   * 
   * @return FlowyResult<GotrueTokenResponsePB, FlowyError>
   *         成功：返回Gotrue令牌响应
   *         失败：返回错误信息（验证码错误、已过期等）
   * 
   * 验证码流程：
   * 1. 用户输入邮箱并请求验证码
   * 2. 系统生成随机验证码
   * 3. 发送验证码到用户邮箱
   * 4. 用户输入验证码
   * 5. 系统验证码的正确性和时效性
   * 6. 返回认证令牌
   * 
   * 安全特性：
   * - 验证码有时效性（通常5-10分钟）
   * - 限制尝试次数
   * - 防止暴力破解
   */
  Future<FlowyResult<GotrueTokenResponsePB, FlowyError>> signInWithPasscode({
    required String email,
    required String passcode,
  });

  /**
   * 用户登出
   * 
   * 清除当前用户的认证状态和相关数据。
   * 这是安全和隐私保护的重要功能。
   * 
   * @return Future<void> 无返回值的异步操作
   * 
   * 登出操作包括：
   * 1. 清除本地存储的令牌
   * 2. 清除用户Session数据
   * 3. 清除内存中的用户信息
   * 4. 通知后端撤销令牌（可选）
   * 5. 重定向到登录页面
   * 
   * 注意事项：
   * - 登出是不可逆操作
   * - 需要重新登录才能访问受保护的功能
   * - 本地缓存数据可能会被清除
   */
  Future<void> signOut();

  /**
   * 获取当前用户信息
   * 
   * 从后端获取当前已认证用户的完整Profile信息。
   * 这是应用初始化和用户信息展示的基础方法。
   * 
   * @return FlowyResult<UserProfilePB, FlowyError>
   *         成功：返回用户Profile信息
   *               包括：用户ID、姓名、邮箱、头像URL、工作区信息等
   *         失败：返回错误信息（未登录、网络错误、令牌过期等）
   * 
   * UserProfilePB包含的信息：
   * - id: 用户唯一标识
   * - name: 用户显示名称  
   * - email: 用户邮箱
   * - iconUrl: 用户头像URL
   * - openaiKey: OpenAI API密钥（如果设置）
   * - workspaceId: 当前工作区ID
   * - authType: 认证类型（本地、云端等）
   * 
   * 使用场景：
   * - 应用启动时检查登录状态
   * - 用户信息页面展示
   * - 权限验证
   * - 工作区切换
   */
  Future<FlowyResult<UserProfilePB, FlowyError>> getUser();
}
