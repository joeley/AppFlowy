import 'dart:convert';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';

/// 文档导出类型枚举
enum DocumentExportType {
  json,     // JSON格式 - 完整保留文档结构
  markdown, // Markdown格式 - 通用标记语言
  text,     // 纯文本 - 仅保留文字内容
  html,     // HTML格式 - 网页格式
}

/// 文档导出器 - 负责将文档导出为不同格式
/// 
/// 主要功能：
/// 1. 支持多种导出格式（JSON、Markdown、HTML等）
/// 2. 保持文档结构和格式
/// 3. 支持导出到文件或字符串
/// 
/// 设计思想：
/// - 通过DocumentService获取文档数据
/// - 根据导出类型选择相应的转换器
/// - 支持直接导出到文件路径（Markdown）
class DocumentExporter {
  const DocumentExporter(
    this.view, // 要导出的视图
  );

  final ViewPB view; // 视图对象，包含文档ID

  /// 导出文档
  /// 
  /// 参数：
  /// - [type]: 导出格式类型
  /// - [path]: 可选的文件路径，仅Markdown支持
  /// 
  /// 返回：
  /// - 成功：导出的文档内容字符串
  /// - 失败：FlowyError错误信息
  Future<FlowyResult<String, FlowyError>> export(
    DocumentExportType type, {
    String? path, // 可选的导出路径
  }) async {
    // 获取文档服务
    final documentService = DocumentService();
    // 打开文档获取数据
    final result = await documentService.openDocument(documentId: view.id);
    return result.fold(
      (r) async {
        // 将protobuf数据转换为Document对象
        final document = r.toDocument();
        if (document == null) {
          // 文档转换失败
          return FlowyResult.failure(
            FlowyError(
              msg: LocaleKeys.settings_files_exportFileFail.tr(),
            ),
          );
        }
        // 根据不同的导出类型进行处理
        switch (type) {
          case DocumentExportType.json:
            // JSON格式：直接序列化document对象
            return FlowyResult.success(jsonEncode(document));
          case DocumentExportType.markdown:
            // Markdown格式：支持导出到文件或返回字符串
            if (path != null) {
              // 导出到指定文件路径
              await customDocumentToMarkdown(document, path: path);
              return FlowyResult.success(''); // 返回空字符串表示成功
            } else {
              // 返回Markdown字符串
              return FlowyResult.success(
                await customDocumentToMarkdown(document),
              );
            }
          case DocumentExportType.text:
            // 纯文本格式：暂未实现
            throw UnimplementedError();
          case DocumentExportType.html:
            // HTML格式：转换为HTML字符串
            final html = documentToHTML(
              document,
            );
            return FlowyResult.success(html);
        }
      },
      (error) => FlowyResult.failure(error), // 打开文档失败
    );
  }
}
