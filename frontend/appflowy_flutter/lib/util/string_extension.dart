/*
 * 字符串扩展工具
 * 
 * 设计理念：
 * 为String类型添加各种实用的扩展方法。
 * 提供文件名编码、颜色解析、图标处理等功能。
 * 
 * 核心功能：
 * 1. 文件名安全编码
 * 2. 文件大小获取
 * 3. URL类型检测
 * 4. 颜色解析
 * 5. 图标识别
 * 6. 文本统计
 * 
 * 使用场景：
 * - 文件系统操作
 * - UI颜色处理
 * - 图标管理
 * - 文本分析
 */

import 'dart:io';

import 'package:appflowy/shared/icon_emoji_picker/icon.dart';
import 'package:appflowy/shared/icon_emoji_picker/icon_picker.dart';
import 'package:appflowy/shared/patterns/common_patterns.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Icon;

/*
 * 字符串基本扩展
 * 
 * 为所有String类型添加实用方法。
 */
extension StringExtension on String {
  /* 文件系统不允许的特殊字符 */
  static const _specialCharacters = r'\/:*?"<>| ';

  /*
   * 转换为合法文件名
   * 
   * 功能：
   * 将字符串编码为安全的文件名。
   * 替换所有文件系统不允许的特殊字符。
   * 
   * 处理规则：
   * - \/:*?"<>| 和空格 替换为下划线
   * - 保留其他所有字符
   * 
   * 使用场景：
   * - 保存用户输入为文件名
   * - 导出文件命名
   * - 创建目录名称
   * 
   * 示例：
   * "My File/Name?".toFileName() => "My_File_Name_"
   */
  String toFileName() {
    final buffer = StringBuffer();
    /* 遍历每个字符 */
    for (final character in characters) {
      /* 检查是否为特殊字符 */
      if (_specialCharacters.contains(character)) {
        buffer.write('_');  /* 替换为下划线 */
      } else {
        buffer.write(character);  /* 保留原字符 */
      }
    }
    return buffer.toString();
  }

  /*
   * 获取文件大小
   * 
   * 功能：
   * 将字符串作为文件路径，获取文件大小。
   * 
   * 返回值：
   * - int：文件大小（字节）
   * - null：文件不存在
   * 
   * 注意：此方法与file_extension.dart中的同名方法重复
   */
  int? get fileSize {
    final file = File(this);
    if (file.existsSync()) {
      return file.lengthSync();
    }
    return null;
  }

  /*
   * 检查是否为AppFlowy云URL
   * 
   * 功能：
   * 使用正则表达式检查字符串是否为AppFlowy云服务URL。
   * 
   * 使用场景：
   * - 识别云端链接
   * - 区分本地和云端资源
   * - URL路由处理
   */
  bool get isAppFlowyCloudUrl => appflowyCloudUrlRegex.hasMatch(this);

  /*
   * 获取封面颜色
   * 
   * 功能：
   * 将字符串解析为颜色值，专用于封面颜色。
   * 
   * 解析顺序：
   * 1. 尝试作为Tint ID解析（预定义颜色）
   * 2. 如果失败，尝试作为十六进制颜色解析
   * 
   * 参数：
   * - context：用于获取主题颜色
   * 
   * 返回值：
   * - Color：解析成功的颜色
   * - null：解析失败
   * 
   * 使用限制：
   * 仅用于封面颜色处理
   */
  Color? coverColor(BuildContext context) {
    /* 先尝试Tint ID，失败后尝试十六进制 */
    return FlowyTint.fromId(this)?.color(context) ?? tryToColor();
  }

  /*
   * 返回自身或默认值
   * 
   * 功能：
   * 如果字符串为空，返回默认值，否则返回自身。
   * 
   * 使用场景：
   * - 处理用户输入
   * - 配置项默认值
   * - 显示文本备用
   * 
   * 示例：
   * "".orDefault("未命名") => "未命名"
   * "test".orDefault("未命名") => "test"
   */
  String orDefault(String defaultValue) {
    return isEmpty ? defaultValue : this;
  }
}

/*
 * 可空字符串扩展
 * 
 * 为可空字符串类型添加安全处理方法。
 */
extension NullableStringExtension on String? {
  /*
   * 返回自身或默认值（可空版本）
   * 
   * 功能：
   * 处理可空字符串，在null或空字符串时返回默认值。
   * 
   * 判断逻辑：
   * 1. 如果为null，返回默认值
   * 2. 如果为空字符串，返回默认值
   * 3. 否则返回原值
   * 
   * 示例：
   * null.orDefault("默认") => "默认"
   * "".orDefault("默认") => "默认"
   * "test".orDefault("默认") => "test"
   */
  String orDefault(String defaultValue) {
    return this?.isEmpty ?? true ? defaultValue : this ?? '';
  }
}

/*
 * 图标扩展
 * 
 * 为字符串添加图标解析功能。
 * 将"group/icon"格式的字符串解析为图标对象。
 */
extension IconExtension on String {
  /*
   * 解析图标
   * 
   * 功能：
   * 将"group/icon"格式的字符串解析为图标对象。
   * 
   * 格式要求：
   * - 必须包含正好一个"/"
   * - 前部分为图标组名
   * - 后部分为图标名
   * 
   * 返回值：
   * - Icon：解析成功的图标对象
   * - null：格式不正确
   * 
   * 示例：
   * "emoji/smile".icon => Icon(名称="smile", 组="emoji")
   * "invalid".icon => null
   */
  Icon? get icon {
    /* 按"/"分割字符串 */
    final values = split('/');
    /* 检查格式是否正确（必须有且只有一个"/"） */
    if (values.length != 2) {
      return null;
    }
    /* 创建图标组 */
    final iconGroup = IconGroup(name: values.first, icons: []);
    /* 调试模式下验证图标存在性 */
    if (kDebugMode) {
      /* 确保图标组存在 */
      assert(kIconGroups!.any((group) => group.name == values.first));
      /* 确保图标在组内存在 */
      assert(
        kIconGroups!
            .firstWhere((group) => group.name == values.first)
            .icons
            .any((icon) => icon.name == values.last),
      );
    }
    /* 创建并返回图标对象 */
    return Icon(
      content: values.last,
      name: values.last,
      keywords: [],
    )..iconGroup = iconGroup;
  }
}

/*
 * 计数器扩展
 * 
 * 为字符串添加文本统计功能。
 */
extension CounterExtension on String {
  /*
   * 获取文本统计信息
   * 
   * 功能：
   * 统计字符串中的单词数和字符数。
   * 
   * 统计内容：
   * 1. 单词数：使用正则表达式匹配单词
   * 2. 字符数：使用runes统计Unicode字符
   * 
   * 使用场景：
   * - 文章字数统计
   * - 编辑器状态栏
   * - 内容长度限制
   * 
   * 注意事项：
   * - runes正确处理Unicode字符（包括表情符号）
   * - wordRegex需要适配不同语言
   * 
   * 返回值：
   * Counters对象，包含单词数和字符数
   */
  Counters getCounter() {
    /* 统计单词数 */
    final wordCount = wordRegex.allMatches(this).length;
    /* 统计字符数（支持Unicode） */
    final charCount = runes.length;
    /* 返回统计结果 */
    return Counters(wordCount: wordCount, charCount: charCount);
  }
}
