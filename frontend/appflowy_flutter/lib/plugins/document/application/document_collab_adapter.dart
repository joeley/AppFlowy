/*
 * 文档协作适配器
 * 
 * 设计理念：
 * 负责处理文档的协作同步功能，将远程文档变更同步到本地编辑器。
 * 支持多种同步策略，包括强制重载、增量差分和远程选区显示。
 * 
 * 核心功能：
 * 1. 文档同步：支持三种同步版本（V1/V2/V3）
 * 2. 差分算法：计算并应用文档差异
 * 3. 远程选区：显示其他用户的光标和选区
 * 4. 冲突解决：处理本地和远程编辑冲突
 * 
 * 同步策略：
 * - V1：强制重载（开发调试用）
 * - V2：事件流同步（未完全实现）
 * - V3：差分同步（生产环境主要方式）
 * 
 * 使用场景：
 * - 多用户实时协作编辑
 * - 文档版本同步
 * - 离线编辑后的合并
 * - 协作者状态显示
 */

import 'dart:convert';

import 'package:appflowy/plugins/document/application/document_awareness_metadata.dart';
import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy/plugins/document/application/document_diff.dart';
import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/shared/list_extension.dart';
import 'package:appflowy/startup/tasks/device_info_task.dart';
import 'package:appflowy/util/color_generator/color_generator.dart';
import 'package:appflowy/util/json_print.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-document/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/*
 * 文档协作适配器类
 * 
 * 职责：
 * 1. 管理文档的协作同步
 * 2. 处理远程文档变更
 * 3. 显示协作者的选区
 * 4. 解决编辑冲突
 */
class DocumentCollabAdapter {
  DocumentCollabAdapter(
    this.editorState,
    this.docId,
  );

  final EditorState editorState;  /* 编辑器状态 */
  final String docId;              /* 文档ID */
  final DocumentDiff diff = const DocumentDiff();  /* 差分计算器 */

  final _service = DocumentService();  /* 文档服务 */

  /*
   * 同步版本1 - 强制重载
   * 
   * 功能：
   * 从服务器完全重新加载文档，忽略本地更改。
   * 
   * 使用场景：
   * - 开发调试时使用
   * - 需要强制同步远程版本
   * - 本地文档损坏时的恢复
   * 
   * 注意：会丢失本地未保存的更改
   */
  Future<EditorState?> syncV1() async {
    /* 从服务器获取最新文档 */
    final result = await _service.getDocument(documentId: docId);
    /* 转换为Document对象 */
    final document = result.fold((s) => s.toDocument(), (f) => null);
    if (document == null) {
      return null;
    }
    /* 创建新的编辑器状态 */
    return EditorState(document: document);
  }

  /*
   * 同步版本2 - 事件流同步
   * 
   * 功能：
   * 将yrs的文档事件转换为编辑器操作并应用。
   * 
   * 处理流程：
   * 1. 接收远程文档事件
   * 2. 解析事件类型（插入/更新/删除）
   * 3. 转换为本地操作
   * 4. 应用到编辑器状态
   * 
   * 状态：未完全实现，仅支持更新操作
   */
  Future<void> syncV2(DocEventPB docEvent) async {
    /* 调试：打印事件内容 */
    prettyPrintJson(docEvent.toProto3Json());

    /* 创建事务批量处理操作 */
    final transaction = editorState.transaction;

    /* 遍历所有事件 */
    for (final event in docEvent.events) {
      for (final blockEvent in event.event) {
        /* 根据命令类型处理 */
        switch (blockEvent.command) {
          case DeltaTypePB.Inserted:
            /* TODO: 实现插入逻辑 */
            break;
          case DeltaTypePB.Updated:
            /* 处理更新事件 */
            await _syncUpdated(blockEvent, transaction);
            break;
          case DeltaTypePB.Removed:
            /* TODO: 实现删除逻辑 */
            break;
          default:
        }
      }
    }

    /* 应用事务，标记为远程操作 */
    await editorState.apply(transaction, isRemote: true);
  }

  /*
   * 同步版本3 - 差分同步（主要方式）
   * 
   * 功能：
   * 计算本地和远程文档的差异，只应用变更部分。
   * 
   * 处理流程：
   * 1. 获取远程文档
   * 2. 计算差异操作
   * 3. 批量应用差异
   * 4. 验证同步结果
   * 
   * 优势：
   * - 最小化数据传输
   * - 保留本地未冲突的更改
   * - 支持智能合并
   */
  Future<void> syncV3({DocEventPB? docEvent}) async {
    /* 获取远程文档 */
    final result = await _service.getDocument(documentId: docId);
    final document = result.fold((s) => s.toDocument(), (f) => null);
    if (document == null) {
      return;
    }

    /* 计算文档差异 */
    final ops = diff.diffDocument(editorState.document, document);
    if (ops.isEmpty) {
      return;  /* 无差异，无需同步 */
    }

    /* 调试：打印差异操作 */
    if (enableDocumentInternalLog) {
      prettyPrintJson(ops.map((op) => op.toJson()).toList());
    }

    /* 批量应用差异操作 */
    final transaction = editorState.transaction;
    for (final op in ops) {
      transaction.add(op);
    }
    await editorState.apply(transaction, isRemote: true);

    /* 调试：验证同步结果 */
    if (enableDocumentInternalLog) {
      assert(() {
        final local = editorState.document.root.toJson();
        final remote = document.root.toJson();
        if (!const DeepCollectionEquality().equals(local, remote)) {
          Log.error('Invalid diff status');
          Log.error('Local: $local');
          Log.error('Remote: $remote');
          return false;
        }
        return true;
      }());
    }
  }

  /*
   * 强制重新加载文档
   * 
   * 功能：
   * 完全替换本地文档内容，但保留用户的光标位置。
   * 
   * 处理流程：
   * 1. 获取远程文档
   * 2. 保存当前选区
   * 3. 清空本地内容
   * 4. 插入远程内容
   * 5. 恢复选区位置
   * 
   * 使用场景：
   * - 文档严重不同步
   * - 需要强制覆盖本地版本
   * - 解决冲突失败后的恢复
   */
  Future<void> forceReload() async {
    /* 获取远程文档 */
    final result = await _service.getDocument(documentId: docId);
    final document = result.fold((s) => s.toDocument(), (f) => null);
    if (document == null) {
      return;
    }

    /* 保存当前选区位置 */
    final beforeSelection = editorState.selection;

    /* 清空当前文档 */
    final clear = editorState.transaction;
    clear.deleteNodes(editorState.document.root.children);
    await editorState.apply(clear, isRemote: true);

    /* 插入远程文档内容 */
    final insert = editorState.transaction;
    insert.insertNodes([0], document.root.children);
    await editorState.apply(insert, isRemote: true);

    /* 恢复选区位置 */
    editorState.selection = beforeSelection;
  }

  /*
   * 同步更新事件
   * 
   * 功能：
   * 处理远程的更新事件，将变更应用到本地节点。
   * 
   * 支持的更新类型：
   * 1. 文本Delta变更：富文本内容的增量更新
   * 2. 块级变更：整个块的属性或内容更新
   * 
   * 参数：
   * - payload：更新事件载荷
   * - transaction：当前事务
   */
  Future<void> _syncUpdated(
    BlockEventPayloadPB payload,
    Transaction transaction,
  ) async {
    assert(payload.command == DeltaTypePB.Updated);

    final path = payload.path;
    final id = payload.id;
    final value = jsonDecode(payload.value);

    /* 获取所有文档节点 */
    final nodes = NodeIterator(
      document: editorState.document,
      startNode: editorState.document.root,
    ).toList();

    /* 处理文本Delta变更 */
    if (path.isTextDeltaChangeset) {
      /* 查找目标节点 */
      /* ⚠️ 功能未完全实现 */
      final target = nodes.singleWhereOrNull((n) => n.id == id);
      if (target != null) {
        try {
          /* 解析并应用Delta */
          final delta = Delta.fromJson(jsonDecode(value));
          transaction.insertTextDelta(target, 0, delta);
        } catch (e) {
          Log.error('Failed to apply delta: $value, error: $e');
        }
      }
    } else if (path.isBlockChangeset) {
      /* 处理块级变更 */
      final target = nodes.singleWhereOrNull((n) => n.id == id);
      if (target != null) {
        try {
          /* 解析并更新节点属性 */
          final delta = jsonDecode(value['data'])['delta'];
          transaction.updateNode(target, {
            'delta': Delta.fromJson(delta).toJson(),
          });
        } catch (e) {
          Log.error('Failed to update $value, error: $e');
        }
      }
    }
  }

  /*
   * 更新远程选区显示
   * 
   * 功能：
   * 显示其他协作者的光标位置和选区，实现实时协作可视化。
   * 
   * 处理流程：
   * 1. 解析协作者状态信息
   * 2. 过滤重复和本机用户
   * 3. 创建远程选区对象
   * 4. 渲染用户名标签
   * 
   * 特性：
   * - 按时间戳去重
   * - 为每个用户生成唯一颜色
   * - 显示用户名标签
   * - 区分光标和选区样式
   */
  Future<void> updateRemoteSelection(
    String userId,
    DocumentAwarenessStatesPB states,
  ) async {
    final List<RemoteSelection> remoteSelections = [];
    final deviceId = ApplicationInfo.deviceId;
    
    /* 按时间戳降序排序并去重 */
    final values = states.value.values
        .sorted(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        ) /* 降序排列，最新的在前 */
        .unique(
          (e) => Object.hashAll([e.user.uid, e.user.deviceId]),
        );
    
    for (final state in values) {
      /* 仅处理版本1的状态 */
      if (state.version != 1 || state.metadata.isEmpty) {
        continue;
      }
      
      final uid = state.user.uid.toString();
      final did = state.user.deviceId;

      /* 解析元数据 */
      DocumentAwarenessMetadata metadata;
      try {
        metadata = DocumentAwarenessMetadata.fromJson(
          jsonDecode(state.metadata),
        );
      } catch (e) {
        Log.error('Failed to parse metadata: $e, ${state.metadata}');
        continue;
      }
      
      /* 获取选区颜色 */
      final selectionColor = metadata.selectionColor.tryToColor();
      final cursorColor = metadata.cursorColor.tryToColor();
      
      /* 过滤本机用户和无效颜色 */
      if ((uid == userId && did == deviceId) ||
          (cursorColor == null || selectionColor == null)) {
        continue;
      }
      
      /* 构建选区对象 */
      final start = state.selection.start;
      final end = state.selection.end;
      final selection = Selection(
        start: Position(
          path: start.path.toIntList(),
          offset: start.offset.toInt(),
        ),
        end: Position(
          path: end.path.toIntList(),
          offset: end.offset.toInt(),
        ),
      );
      
      /* 生成用户标识颜色 */
      final color = ColorGenerator(uid + did).toColor();
      
      /* 创建远程选区对象 */
      final remoteSelection = RemoteSelection(
        id: uid,
        selection: selection,
        selectionColor: selectionColor,
        cursorColor: cursorColor,
        builder: (_, __, rect) {
          /* 构建用户名标签 */
          return Positioned(
            top: rect.top - 14,  /* 标签位于选区上方 */
            left: selection.isCollapsed ? rect.right : rect.left,
            child: ColoredBox(
              color: color,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2.0,
                  vertical: 1.0,
                ),
                child: FlowyText(
                  metadata.userName,
                  color: Colors.black,
                  fontSize: 12.0,
                ),
              ),
            ),
          );
        },
      );
      remoteSelections.add(remoteSelection);
    }

    /* 更新编辑器的远程选区 */
    editorState.remoteSelections.value = remoteSelections;
  }
}

/*
 * Int64列表扩展
 * 将protobuf的Int64列表转换为Dart int列表
 */
extension on List<Int64> {
  List<int> toIntList() {
    return map((e) => e.toInt()).toList();
  }
}

/*
 * 路径扩展
 * 识别不同类型的变更路径
 */
extension on List<String> {
  /* 检查是否为文本Delta变更路径 */
  bool get isTextDeltaChangeset {
    return length == 3 && this[0] == 'meta' && this[1] == 'text_map';
  }

  /* 检查是否为块级变更路径 */
  bool get isBlockChangeset {
    return length == 2 && this[0] == 'blocks';
  }
}
