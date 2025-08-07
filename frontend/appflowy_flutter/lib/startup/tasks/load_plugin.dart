// AI聊天插件
import 'package:appflowy/plugins/ai_chat/chat.dart';
// 数据库视图插件：日历视图
import 'package:appflowy/plugins/database/calendar/calendar.dart';
// 数据库视图插件：看板视图
import 'package:appflowy/plugins/database/board/board.dart';
// 数据库视图插件：表格视图
import 'package:appflowy/plugins/database/grid/grid.dart';
// 数据库文档插件
import 'package:appflowy/plugins/database_document/database_document_plugin.dart';
// 插件系统基础设施
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
// 空白页插件
import 'package:appflowy/plugins/blank/blank.dart';
// 文档编辑器插件
import 'package:appflowy/plugins/document/document.dart';
// 回收站插件
import 'package:appflowy/plugins/trash/trash.dart';

/**
 * 插件加载任务
 * 
 * AppFlowy采用插件化架构，每个功能模块都是一个独立的插件
 * 
 * 插件系统的优势：
 * 1. 模块化：每个功能独立开发、测试
 * 2. 可扩展：轻松添加新功能
 * 3. 解耦合：插件之间相互独立
 * 4. 按需加载：未来可实现动态加载
 * 
 * 核心插件包括：
 * - Document：富文本文档编辑器
 * - Grid：电子表格/数据库表格
 * - Board：看板视图（类似Trello）
 * - Calendar：日历视图
 * - AI Chat：AI对话功能
 * - Trash：回收站
 * 
 * 这个设计类似于VSCode的扩展系统或Eclipse的插件架构
 */
class PluginLoadTask extends LaunchTask {
  const PluginLoadTask();

  @override
  LaunchTaskType get type => LaunchTaskType.dataProcessing;

  /**
   * 初始化并注册所有插件
   * 
   * 插件注册顺序很重要，基础插件需要先注册
   * 每个插件都有自己的Builder和Config
   */
  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 空白页插件：提供一个空的视图容器
    registerPlugin(builder: BlankPluginBuilder(), config: BlankPluginConfig());
    
    // 回收站插件：管理已删除的文档
    registerPlugin(builder: TrashPluginBuilder(), config: TrashPluginConfig());
    
    // 文档编辑器插件：核心功能，富文本编辑
    // 支持Markdown、富文本格式、协同编辑等
    registerPlugin(builder: DocumentPluginBuilder());
    
    // === 数据库视图插件 ===
    // AppFlowy的数据库可以有多种视图展示方式
    
    // 表格视图：类似Excel的电子表格
    registerPlugin(builder: GridPluginBuilder(), config: GridPluginConfig());
    
    // 看板视图：类似Trello的卡片式布局
    registerPlugin(builder: BoardPluginBuilder(), config: BoardPluginConfig());
    
    // 日历视图：以日历形式展示数据
    registerPlugin(
      builder: CalendarPluginBuilder(),
      config: CalendarPluginConfig(),
    );
    
    // 数据库文档插件：将数据库嵌入到文档中
    // 实现文档和数据库的深度整合
    registerPlugin(
      builder: DatabaseDocumentPluginBuilder(),
      config: DatabaseDocumentPluginConfig(),
    );
    
    // 注意：这里重复注册了DatabaseDocumentPluginBuilder
    // 可能是个bug或者有特殊用途
    registerPlugin(
      builder: DatabaseDocumentPluginBuilder(),
      config: DatabaseDocumentPluginConfig(),
    );
    
    // AI聊天插件：集成AI对话功能
    // 可以进行智能问答、文本生成等
    registerPlugin(
      builder: AIChatPluginBuilder(),
      config: AIChatPluginConfig(),
    );
  }
}
