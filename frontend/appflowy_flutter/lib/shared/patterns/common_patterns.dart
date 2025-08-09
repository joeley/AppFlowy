/// 通用正则表达式模式库
/// 
/// 提供应用中常用的正则表达式模式，用于字符串匹配和验证。
/// 覆盖URL验证、文件路径、媒体文件、文本格式等多种场景。

/// 尾随零模式
/// 
/// 用于匹配和移除数字末尾的无意义零
/// 例如: 1.200 -> 1.2, 100.000 -> 100
const _trailingZerosPattern = r'^(\d+(?:\.\d*?[1-9](?=0|\b))?)\.?0*$';
final trailingZerosRegex = RegExp(_trailingZerosPattern);

/// 通用超链接模式
/// 
/// 匹配HTTP/HTTPS协议的URL
/// 支持www前缀（可选）和路径参数
const _hrefPattern =
    r'https?://(?:www\.)?[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(?:/[^\s]*)?';
final hrefRegex = RegExp(_hrefPattern);

/// 图片URL模式
/// 
/// 匹配图片文件的URL，支持以下特性：
/// - HTTP和HTTPS协议
/// - 查询参数支持
/// - 限定图片扩展名：.png, .jpg, .jpeg, .gif, .webm, .webp, .bmp
const _imgUrlPattern =
    r'(https?:\/\/)([^\s(["<,>/]*)(\/)[^\s[",><]*(.png|.jpg|.jpeg|.gif|.webm|.webp|.bmp)(\?[^\s[",><]*)?';
final imgUrlRegex = RegExp(_imgUrlPattern);

/// Markdown单行图片模式
/// 
/// 匹配Markdown格式的图片语法
/// 格式：![alt text](image_url)
const _singleLineMarkdownImagePattern = "^!\\[.*\\]\\(($_hrefPattern)\\)\$";
final singleLineMarkdownImageRegex = RegExp(_singleLineMarkdownImagePattern);

/// 视频URL模式
/// 
/// 匹配视频文件的URL，支持以下特性：
/// - HTTP和HTTPS协议
/// - 查询参数支持
/// - 限定视频扩展名：.mp4, .mov, .avi, .webm, .flv, .m4v, .mpeg, .h264
const _videoUrlPattern =
    r'(https?:\/\/)([^\s(["<,>/]*)(\/)[^\s[",><]*(.mp4|.mov|.avi|.webm|.flv|.m4v|.mpeg|.h264)(\?[^\s[",><]*)?';
final videoUrlRegex = RegExp(_videoUrlPattern);

/// YouTube URL模式
/// 
/// 匹配YouTube视频链接
/// 支持youtube.com和短链接youtu.be
const _youtubeUrlPattern = r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/';
final youtubeUrlRegex = RegExp(_youtubeUrlPattern);

/// AppFlowy Cloud URL模式
/// 
/// 匹配AppFlowy云服务的URL
/// 格式：https://[subdomain].appflowy.cloud/[path]
const _appflowyCloudUrlPattern = r'^(https:\/\/)(.*)(\.appflowy\.cloud\/)(.*)';
final appflowyCloudUrlRegex = RegExp(_appflowyCloudUrlPattern);

/// 驼峰命名模式
/// 
/// 用于识别驼峰命名中的大写字母位置
/// 用于将驼峰命名转换为其他格式（如下划线命名）
const _camelCasePattern = '(?<=[a-z])[A-Z]';
final camelCaseRegex = RegExp(_camelCasePattern);

/// macOS卷路径模式
/// 
/// 匹配macOS系统中的外部卷路径
/// 格式：/Volumes/[volume_name]
const _macOSVolumesPattern = '^/Volumes/[^/]+';
final macOSVolumesRegex = RegExp(_macOSVolumesPattern);

/// AppFlowy分享页面链接模式
/// 
/// 匹配AppFlowy的分享页面链接
/// 格式：https://appflowy.com/app/[workspace_id]/[page_id]?blockId=[block_id]
/// blockId参数可选，用于定位到特定块
const appflowySharePageLinkPattern =
    r'^https://appflowy\.com/app/([^/]+)/([^?]+)(?:\?blockId=(.+))?$';
final appflowySharePageLinkRegex = RegExp(appflowySharePageLinkPattern);

/// 数字列表模式
/// 
/// 匹配数字列表项的开头
/// 格式：1. 2. 3. 等
const _numberedListPattern = r'^(\d+)\.';
final numberedListRegex = RegExp(_numberedListPattern);

/// 本地路径模式
/// 
/// 匹配各种本地文件路径格式：
/// - file:// 协议
/// - Unix绝对路径 (/)
/// - Windows路径 (\ 或 C:\)
/// - 相对路径 (./ 或 ../)
const _localPathPattern = r'^(file:\/\/|\/|\\|[a-zA-Z]:[/\\]|\.{1,2}[/\\])';
final localPathRegex = RegExp(_localPathPattern, caseSensitive: false);

/// 单词模式
/// 
/// 匹配非空白字符序列
/// 用于分词和单词统计
const _wordPattern = r"\S+";
final wordRegex = RegExp(_wordPattern);

/// Apple Notes HTML模式
/// 
/// 识别从Apple Notes复制的HTML内容
/// 通过特定的meta标签识别
const _appleNotesPattern =
    r'<meta\s+name="Generator"\s+content="Cocoa HTML Writer"\s*>\s*<meta\s+name="CocoaVersion"\s+content="\d+"\s*>';
final appleNotesRegex = RegExp(_appleNotesPattern);
