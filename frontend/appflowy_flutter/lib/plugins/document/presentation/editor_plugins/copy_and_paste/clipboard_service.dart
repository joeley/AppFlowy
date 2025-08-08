/*
 * 剪贴板服务
 * 
 * 设计理念：
 * 提供强大的剪贴板管理功能，支持多种数据格式的复制粘贴。
 * 保留应用内复制的完整格式，同时支持跨应用的数据交换。
 * 
 * 核心功能：
 * 1. 应用内格式保留
 * 2. 多格式数据支持
 * 3. 表格特殊处理
 * 4. 图片剪贴板
 * 
 * 支持的数据格式：
 * - 纯文本
 * - HTML富文本
 * - 应用内JSON
 * - 表格JSON
 * - 图片数据
 * 
 * 使用场景：
 * - 文档内容复制
 * - 跨文档粘贴
 * - 外部内容导入
 * - 表格行列操作
 */

import 'dart:async';
import 'dart:convert';

import 'package:appflowy_backend/log.dart';
import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';

/*
 * 应用内JSON格式
 * 
 * 功能：
 * 用于应用内复制粘贴，保留完整的节点格式。
 * 存储编辑器节点的JSON表示。
 */
const inAppJsonFormat = CustomValueFormat<String>(
  applicationId: 'io.appflowy.InAppJsonType',
  onDecode: _defaultDecode,
  onEncode: _defaultEncode,
);

/*
 * 表格JSON格式
 * 
 * 功能：
 * 专门用于表格节点的行或列复制。
 * 保留表格结构信息。
 */
const tableJsonFormat = CustomValueFormat<String>(
  applicationId: 'io.appflowy.TableJsonType',
  onDecode: _defaultDecode,
  onEncode: _defaultEncode,
);

/*
 * 剪贴板服务数据
 * 
 * 功能：
 * 封装剪贴板中的多种数据格式。
 * 
 * 数据类型：
 * 1. 纯文本 - 基础文本内容
 * 2. HTML - 富文本格式
 * 3. 图片 - 二进制图片数据
 * 4. 应用内JSON - 保留完整格式
 * 5. 表格JSON - 表格特殊处理
 */
class ClipboardServiceData {
  const ClipboardServiceData({
    this.plainText,
    this.html,
    this.image,
    this.inAppJson,
    this.tableJson,
  });

  /*
   * 纯文本内容
   * 
   * 用途：
   * 粘贴普通文本，去除所有格式。
   */
  final String? plainText;

  /*
   * HTML内容
   * 
   * 用途：
   * 粘贴来自浏览器或其他应用的富文本内容。
   * 例如：从浏览器复制的网页内容。
   */
  final String? html;

  /*
   * 图片数据
   * 
   * 用途：
   * 粘贴图片内容。
   * 格式：(图片类型, 二进制数据)
   * 例如：从截图工具或其他应用复制的图片。
   */
  final (String, Uint8List?)? image;

  /*
   * 应用内JSON
   * 
   * 用途：
   * 应用内粘贴，保留完整的编辑器节点结构。
   * 例如：从文档A复制到文档B。
   */
  final String? inAppJson;

  /*
   * 表格JSON
   * 
   * 用途：
   * 仅用于表格行或列的复制。
   * 注意：不要用于其他场景。
   */
  final String? tableJson;
}

/*
 * 剪贴板服务类
 * 
 * 职责：
 * 1. 读取剪贴板数据
 * 2. 写入剪贴板数据
 * 3. 格式转换和适配
 * 4. 测试模拟支持
 */
class ClipboardService {
  static ClipboardServiceData? _mockData;  /* 测试模拟数据 */

  /*
   * 设置模拟数据（测试用）
   */
  @visibleForTesting
  static void mockSetData(ClipboardServiceData? data) {
    _mockData = data;
  }

  /*
   * 写入剪贴板数据
   * 
   * 功能：
   * 将多种格式的数据同时写入系统剪贴板。
   * 
   * 处理流程：
   * 1. 提取各种格式数据
   * 2. 构建数据写入项
   * 3. 添加各种格式
   * 4. 写入系统剪贴板
   * 
   * 支持的图片格式：
   * - PNG
   * - JPEG
   * - GIF
   */
  Future<void> setData(ClipboardServiceData data) async {
    final plainText = data.plainText;
    final html = data.html;
    final inAppJson = data.inAppJson;
    final image = data.image;
    final tableJson = data.tableJson;

    final item = DataWriterItem();
    
    /* 添加纯文本 */
    if (plainText != null) {
      item.add(Formats.plainText(plainText));
    }
    
    /* 添加HTML */
    if (html != null) {
      item.add(Formats.htmlText(html));
    }
    
    /* 添加应用内JSON */
    if (inAppJson != null) {
      item.add(inAppJsonFormat(inAppJson));
    }
    
    /* 添加表格JSON */
    if (tableJson != null) {
      item.add(tableJsonFormat(tableJson));
    }
    
    /* 添加图片数据 */
    if (image != null && image.$2?.isNotEmpty == true) {
      switch (image.$1) {
        case 'png':
          item.add(Formats.png(image.$2!));
          break;
        case 'jpeg':
          item.add(Formats.jpeg(image.$2!));
          break;
        case 'gif':
          item.add(Formats.gif(image.$2!));
          break;
        default:
          throw Exception('unsupported image format: ${image.$1}');
      }
    }
    
    /* 写入系统剪贴板 */
    await SystemClipboard.instance?.write([item]);
  }

  /*
   * 写入纯文本
   * 
   * 功能：
   * 快捷方法，仅写入纯文本到剪贴板。
   */
  Future<void> setPlainText(String text) async {
    await SystemClipboard.instance?.write([
      DataWriterItem()..add(Formats.plainText(text)),
    ]);
  }

  /*
   * 读取剪贴板数据
   * 
   * 功能：
   * 从系统剪贴板读取所有可用格式的数据。
   * 
   * 处理流程：
   * 1. 检查模拟数据（测试用）
   * 2. 读取系统剪贴板
   * 3. 打印可用格式
   * 4. 读取各种格式数据
   * 5. 检测图片格式
   * 
   * 支持的图片格式优先级：
   * 1. PNG
   * 2. JPEG
   * 3. GIF
   * 4. WebP
   */
  Future<ClipboardServiceData> getData() async {
    /* 返回模拟数据（测试用） */
    if (_mockData != null) {
      return _mockData!;
    }

    final reader = await SystemClipboard.instance?.read();

    if (reader == null) {
      return const ClipboardServiceData();
    }

    /* 打印可用格式（调试用） */
    for (final item in reader.items) {
      final availableFormats = await item.rawReader!.getAvailableFormats();
      Log.info('availableFormats: $availableFormats');
    }

    /* 读取各种格式数据 */
    final plainText = await reader.readValue(Formats.plainText);
    final html = await reader.readValue(Formats.htmlText);
    final inAppJson = await reader.readValue(inAppJsonFormat);
    final tableJson = await reader.readValue(tableJsonFormat);
    final uri = await reader.readValue(Formats.uri);
    
    /* 检测并读取图片 */
    (String, Uint8List?)? image;
    if (reader.canProvide(Formats.png)) {
      image = ('png', await reader.readFile(Formats.png));
    } else if (reader.canProvide(Formats.jpeg)) {
      image = ('jpeg', await reader.readFile(Formats.jpeg));
    } else if (reader.canProvide(Formats.gif)) {
      image = ('gif', await reader.readFile(Formats.gif));
    } else if (reader.canProvide(Formats.webp)) {
      image = ('webp', await reader.readFile(Formats.webp));
    }

    return ClipboardServiceData(
      plainText: plainText ?? uri?.uri.toString(),
      html: html,
      image: image,
      inAppJson: inAppJson,
      tableJson: tableJson,
    );
  }
}

extension on DataReader {
  Future<Uint8List?>? readFile(FileFormat format) {
    final c = Completer<Uint8List?>();
    final progress = getFile(
      format,
      (file) async {
        try {
          final all = await file.readAll();
          c.complete(all);
        } catch (e) {
          c.completeError(e);
        }
      },
      onError: (e) {
        c.completeError(e);
      },
    );
    if (progress == null) {
      c.complete(null);
    }
    return c.future;
  }
}

/// The default decode function for the clipboard service.
Future<String?> _defaultDecode(Object value, String platformType) async {
  if (value is PlatformDataProvider) {
    final data = await value.getData(platformType);
    if (data is List<int>) {
      return utf8.decode(data, allowMalformed: true);
    }
    if (data is String) {
      return Uri.decodeFull(data);
    }
  }
  return null;
}

/// The default encode function for the clipboard service.
Future<Object> _defaultEncode(String value, String platformType) async {
  return utf8.encode(value);
}
