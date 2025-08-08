import 'dart:convert';

import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-document/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:nanoid/nanoid.dart';

/// 指示文件来源于AppFlowy文档
const appflowySource = "appflowy";

/// 从消息元数据中提取文件列表
/// 
/// 参数：
/// - [map]: 消息元数据Map
/// 
/// 返回：ChatFile列表
List<ChatFile> fileListFromMessageMetadata(
  Map<String, dynamic>? map,
) {
  final List<ChatFile> metadata = [];
  if (map != null) {
    for (final entry in map.entries) {
      if (entry.value is ChatFile) {
        metadata.add(entry.value);
      }
    }
  }

  return metadata;
}

/// 从JSON字符串解析聊天文件列表
/// 
/// 支持解析单个文件对象或文件数组
/// 
/// 参数：
/// - [s]: JSON格式的元数据字符串
/// 
/// 返回：ChatFile列表
List<ChatFile> chatFilesFromMetadataString(String? s) {
  if (s == null || s.isEmpty || s == "null") {
    return [];
  }

  final metadataJson = jsonDecode(s);
  if (metadataJson is Map<String, dynamic>) {
    // 单个文件对象
    final file = chatFileFromMap(metadataJson);
    if (file != null) {
      return [file];
    } else {
      return [];
    }
  } else if (metadataJson is List) {
    // 文件数组
    return metadataJson
        .map((e) => e as Map<String, dynamic>)
        .map(chatFileFromMap)
        .where((file) => file != null)
        .cast<ChatFile>()
        .toList();
  } else {
    Log.error("Invalid metadata: $metadataJson");
    return [];
  }
}

/// 从Map创建ChatFile对象
/// 
/// 参数：
/// - [map]: 包含文件信息的Map
/// 
/// 返回：ChatFile对象，解析失败返回null
ChatFile? chatFileFromMap(Map<String, dynamic>? map) {
  if (map == null) return null;

  final filePath = map['source'] as String?; // 文件路径
  final fileName = map['name'] as String?; // 文件名

  if (filePath == null || fileName == null) {
    return null;
  }
  return ChatFile.fromFilePath(filePath);
}

/// 元数据集合
/// 
/// 包含消息引用源和AI处理进度
class MetadataCollection {
  MetadataCollection({
    required this.sources, // 引用源列表
    this.progress, // AI处理进度
  });
  final List<ChatMessageRefSource> sources;
  final AIChatProgress? progress;
}

/// 解析元数据字符串
/// 
/// 解析JSON格式的元数据，提取引用源和进度信息
/// 
/// 参数：
/// - [s]: JSON格式的元数据字符串
/// 
/// 返回：MetadataCollection对象
MetadataCollection parseMetadata(String? s) {
  if (s == null || s.trim().isEmpty || s.toLowerCase() == "null") {
    return MetadataCollection(sources: []);
  }

  final List<ChatMessageRefSource> metadata = [];
  AIChatProgress? progress;

  try {
    final dynamic decodedJson = jsonDecode(s);
    if (decodedJson == null) {
      return MetadataCollection(sources: []);
    }

    // 处理Map格式的元数据
    void processMap(Map<String, dynamic> map) {
      if (map.containsKey("step") && map["step"] != null) {
        // AI处理进度
        progress = AIChatProgress.fromJson(map);
      } else if (map.containsKey("id") && map["id"] != null) {
        // 消息引用源
        metadata.add(ChatMessageRefSource.fromJson(map));
      } else {
        Log.info("Unsupported metadata format: $map");
      }
    }

    if (decodedJson is Map<String, dynamic>) {
      processMap(decodedJson);
    } else if (decodedJson is List) {
      for (final element in decodedJson) {
        if (element is Map<String, dynamic>) {
          processMap(element);
        } else {
          Log.error("Invalid metadata element: $element");
        }
      }
    } else {
      Log.error("Invalid metadata format: $decodedJson");
    }
  } catch (e, stacktrace) {
    Log.error("Failed to parse metadata: $e, input: $s");
    Log.debug(stacktrace.toString());
  }

  return MetadataCollection(sources: metadata, progress: progress);
}

/// 将元数据转换为Protobuf格式
/// 
/// 将Map格式的元数据转换为后端可识别的ChatMessageMetaPB格式
/// 
/// 参数：
/// - [map]: 元数据Map
/// 
/// 返回：ChatMessageMetaPB列表
Future<List<ChatMessageMetaPB>> metadataPBFromMetadata(
  Map<String, dynamic>? map,
) async {
  if (map == null) return [];

  final List<ChatMessageMetaPB> metadata = [];

  for (final value in map.values) {
    switch (value) {
      // 处理文档视图
      case ViewPB _ when value.layout.isDocumentView:
        final payload = OpenDocumentPayloadPB(documentId: value.id);
        await DocumentEventGetDocumentText(payload).send().fold(
          (pb) {
            metadata.add(
              ChatMessageMetaPB(
                id: value.id,
                name: value.name,
                data: pb.text, // 文档文本内容
                loaderType: ContextLoaderTypePB.Txt,
                source: appflowySource,
              ),
            );
          },
          (err) => Log.error('Failed to get document text: $err'),
        );
        break;
      case ChatFile(
          filePath: final filePath,
          fileName: final fileName,
          fileType: final fileType,
        ):
        metadata.add(
          ChatMessageMetaPB(
            id: nanoid(8),
            name: fileName,
            data: filePath,
            loaderType: fileType,
            source: filePath,
          ),
        );
        break;
    }
  }

  return metadata;
}

/// 从消息元数据中提取聊天文件
/// 
/// 遍历元数据Map，提取所有ChatFile类型的值
/// 
/// 参数：
/// - [map]: 消息元数据Map
/// 
/// 返回：ChatFile列表
List<ChatFile> chatFilesFromMessageMetadata(
  Map<String, dynamic>? map,
) {
  final List<ChatFile> metadata = [];
  if (map != null) {
    for (final entry in map.entries) {
      if (entry.value is ChatFile) {
        metadata.add(entry.value);
      }
    }
  }

  return metadata;
}
