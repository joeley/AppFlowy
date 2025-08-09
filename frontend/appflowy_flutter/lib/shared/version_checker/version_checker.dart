import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/startup/tasks/device_info_task.dart';
import 'package:appflowy_backend/log.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:universal_platform/universal_platform.dart';
import 'package:xml/xml.dart' as xml;

/// 全局版本检查器实例
final versionChecker = VersionChecker();

/// 版本检查器
/// 
/// 使用Appcast XML源来检查应用更新。
/// 支持跨平台的更新检查和自动更新功能。
/// 
/// 主要功能：
/// 1. **更新检查**：从XML源获取最新版本信息
/// 2. **平台适配**：Windows/macOS支持自动更新，Linux打开下载页面
/// 3. **版本解析**：解析Sparkle格式的Appcast XML
/// 4. **关键更新**：支持标记关键更新
/// 
/// 技术细节：
/// - 使用Sparkle框架的Appcast XML格式
/// - Windows/macOS使用auto_updater包
/// - Linux通过浏览器下载
class VersionChecker {
  factory VersionChecker() => _instance;

  VersionChecker._internal();
  
  /// Appcast XML源URL
  String? _feedUrl;

  /// 单例实例
  static final VersionChecker _instance = VersionChecker._internal();

  /// 设置Appcast XML源URL
  /// 
  /// 配置更新检查的数据源
  /// Windows和macOS平台会同时配置自动更新器
  void setFeedUrl(String url) {
    _feedUrl = url;

    if (UniversalPlatform.isWindows || UniversalPlatform.isMacOS) {
      // 配置自动更新器的源URL
      autoUpdater.setFeedURL(url);
      // 禁用自动检查（由应用控制检查时机）
      autoUpdater.setScheduledCheckInterval(0);
    }
  }

  /// 检查更新信息
  /// 
  /// 获取并解析Appcast XML，返回当前平台的更新信息
  /// 
  /// 返回值：
  /// - AppcastItem: 包含版本信息的更新项
  /// - null: 如果没有更新或检查失败
  Future<AppcastItem?> checkForUpdateInformation() async {
    if (_feedUrl == null) {
      Log.error('Feed URL is not set');
      return null;
    }

    try {
      // 获取XML源
      final response = await http.get(Uri.parse(_feedUrl!));
      if (response.statusCode != 200) {
        Log.info('Failed to fetch appcast XML: ${response.statusCode}');
        return null;
      }

      // 解析XML文档
      final document = xml.XmlDocument.parse(response.body);
      final items = document.findAllElements('item');

      // 转换为AppcastItem对象并筛选当前平台的更新
      return items
          .map(_parseAppcastItem)
          .nonNulls
          .firstWhereOrNull((e) => e.os == ApplicationInfo.os);
    } catch (e) {
      Log.info('Failed to check for updates: $e');
    }

    return null;
  }

  /// 触发更新检查
  /// 
  /// 根据平台执行不同的更新策略：
  /// - Windows/macOS: 触发自动更新器检查
  /// - Linux: 打开官网下载页面
  Future<void> checkForUpdate() async {
    if (UniversalPlatform.isLinux) {
      // Linux平台：在浏览器中打开下载页面
      await afLaunchUrlString('https://appflowy.com/download');
    } else {
      // Windows/macOS：使用自动更新器
      await autoUpdater.checkForUpdates();
    }
  }

  /// 解析Appcast项
  /// 
  /// 从XML元素中提取版本信息
  /// 支持Sparkle框架的XML格式
  /// 
  /// XML结构示例：
  /// ```xml
  /// <item>
  ///   <title>Version 2.0</title>
  ///   <sparkle:shortVersionString>2.0</sparkle:shortVersionString>
  ///   <releaseNotesLink>https://...</releaseNotesLink>
  ///   <pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate>
  ///   <enclosure url="https://..." sparkle:os="windows" sparkle:criticalUpdate="true"/>
  /// </item>
  /// ```
  AppcastItem? _parseAppcastItem(xml.XmlElement item) {
    final enclosure = item.findElements('enclosure').firstOrNull;
    return AppcastItem.fromJson({
      // 版本标题
      'title': item.findElements('title').firstOrNull?.innerText,
      // 版本号
      'versionString': item
          .findElements('sparkle:shortVersionString')
          .firstOrNull
          ?.innerText,
      // 显示版本号
      'displayVersionString': item
          .findElements('sparkle:shortVersionString')
          .firstOrNull
          ?.innerText,
      // 发布说明URL
      'releaseNotesUrl':
          item.findElements('releaseNotesLink').firstOrNull?.innerText,
      // 发布日期
      'pubDate': item.findElements('pubDate').firstOrNull?.innerText,
      // 下载URL
      'fileURL': enclosure?.getAttribute('url') ?? '',
      // 操作系统
      'os': enclosure?.getAttribute('sparkle:os') ?? '',
      // 是否为关键更新
      'criticalUpdate':
          enclosure?.getAttribute('sparkle:criticalUpdate') ?? false,
    });
  }
}
