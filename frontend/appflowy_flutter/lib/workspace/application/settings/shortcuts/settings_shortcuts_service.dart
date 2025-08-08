import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/application_data_storage.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'shortcuts_model.dart';

/// 快捷键设置服务 - 负责快捷键配置的持久化存储
/// 
/// 主要功能：
/// 1. 保存快捷键配置到JSON文件
/// 2. 从文件加载自定义快捷键
/// 3. 更新快捷键命令
/// 4. 重置为默认快捷键
/// 
/// 设计思想：
/// - 使用JSON文件存储快捷键配置，方便读写和调试
/// - 支持自定义文件路径（主要用于测试）
/// - 默认存储在应用数据目录下的shortcuts/shortcuts.json
class SettingsShortcutService {
  /// 构造函数
  /// 
  /// 参数：
  /// - [file]: 可选的文件对象，用于指定快捷键存储文件
  ///   如果不提供，将使用默认的文档目录
  ///   通常只在测试时传入自定义文件
  SettingsShortcutService({
    File? file,
  }) {
    _initializeService(file);
  }

  late final File _file; // 快捷键配置文件
  final _initCompleter = Completer<void>(); // 初始化完成信号

  /// 保存所有快捷键到文件
  /// 
  /// 参数：
  /// - [commandShortcuts]: 快捷键事件列表
  /// 
  /// 处理流程：
  /// 1. 将CommandShortcutEvent列表转换为CommandShortcutModel列表
  /// 2. 创建EditorShortcuts对象
  /// 3. 序列化为JSON并写入文件
  Future<void> saveAllShortcuts(
    List<CommandShortcutEvent> commandShortcuts,
  ) async {
    // 转换为可序列化的模型
    final shortcuts = EditorShortcuts(
      commandShortcuts: commandShortcuts.toCommandShortcutModelList(),
    );

    // 写入JSON文件，flush:true确保立即写入磁盘
    await _file.writeAsString(
      jsonEncode(shortcuts.toJson()),
      flush: true,
    );
  }

  /// 获取自定义快捷键
  /// 
  /// 返回：
  /// - 如果文件为空，返回空列表
  /// - 如果文件存在快捷键配置，返回解析后的快捷键列表
  Future<List<CommandShortcutModel>> getCustomizeShortcuts() async {
    await _initCompleter.future; // 等待初始化完成
    final shortcutsInJson = await _file.readAsString(); // 读取JSON文件内容

    if (shortcutsInJson.isEmpty) {
      return [];
    } else {
      return getShortcutsFromJson(shortcutsInJson);
    }
  }

  /// 从JSON字符串提取快捷键
  /// 
  /// 功能说明：
  /// 解析保存的JSON文件，提取其中的快捷键配置
  /// 保存的文件中包含[List<CommandShortcutModel>]
  /// 这个列表需要转换为List<CommandShortcutEvent>以供应用使用
  List<CommandShortcutModel> getShortcutsFromJson(String savedJson) {
    final shortcuts = EditorShortcuts.fromJson(jsonDecode(savedJson));
    return shortcuts.commandShortcuts;
  }

  /// 更新快捷键命令
  /// 
  /// 功能说明：
  /// 将自定义快捷键应用到默认快捷键列表中
  /// 只更新那些键名相同但命令不同的快捷键
  /// 
  /// 参数：
  /// - [commandShortcuts]: 默认快捷键事件列表
  /// - [customizeShortcuts]: 用户自定义的快捷键列表
  Future<void> updateCommandShortcuts(
    List<CommandShortcutEvent> commandShortcuts,
    List<CommandShortcutModel> customizeShortcuts,
  ) async {
    for (final shortcut in customizeShortcuts) {
      // 查找键名相同但命令不同的快捷键
      final shortcutEvent = commandShortcuts.firstWhereOrNull(
        (s) => s.key == shortcut.key && s.command != shortcut.command,
      );
      // 如果找到，更新其命令
      shortcutEvent?.updateCommand(command: shortcut.command);
    }
  }

  /// 重置为默认快捷键
  /// 清除所有自定义设置，恢复为系统默认快捷键
  Future<void> resetToDefaultShortcuts() async {
    await _initCompleter.future;
    await saveAllShortcuts(defaultCommandShortcutEvents);
  }

  /// 初始化服务
  /// 
  /// 功能说明：
  /// 访问AppFlowy文档目录中的shortcuts.json文件
  /// 如果文件不存在，则创建新文件
  Future<void> _initializeService(File? file) async {
    _file = file ?? await _defaultShortcutFile(); // 使用传入的文件或默认文件
    _initCompleter.complete(); // 标记初始化完成
  }

  /// 获取默认的快捷键存储文件
  /// 
  /// 返回：
  /// 路径为: {AppFlowy数据目录}/shortcuts/shortcuts.json
  Future<File> _defaultShortcutFile() async {
    final path = await getIt<ApplicationDataStorage>().getPath(); // 获取应用数据目录
    return File(
      p.join(path, 'shortcuts', 'shortcuts.json'),
    )..createSync(recursive: true); // 创建文件和目录（如果不存在）
  }
}

/// List<CommandShortcutEvent>扩展
/// 提供快捷键事件列表的转换功能
extension on List<CommandShortcutEvent> {
  /// 转换为模型列表
  /// 
  /// 功能说明：
  /// 将CommandShortcutEvent列表转换为CommandShortcutModel列表
  /// 这是保存快捷键配置到JSON文件所必需的
  List<CommandShortcutModel> toCommandShortcutModelList() =>
      map((e) => CommandShortcutModel.fromCommandEvent(e)).toList();
}
