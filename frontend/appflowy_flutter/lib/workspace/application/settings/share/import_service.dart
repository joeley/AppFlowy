import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

/// 导入数据载体 - 封装导入数据的基本信息
/// 
/// 用于在前端传递导入数据的参数
class ImportPayload {
  ImportPayload({
    required this.name,
    required this.data,
    required this.layout,
  });

  final String name; // 导入项的名称
  final List<int> data; // 导入的二进制数据
  final ViewLayoutPB layout; // 视图布局类型（文档、表格、看板等）
}

/// 导入后端服务 - 负责处理数据导入功能
/// 
/// 主要功能：
/// 1. 导入页面数据（支持多种格式）
/// 2. 导入ZIP压缩文件
/// 
/// 设计思想：
/// - 通过Rust后端处理复杂的数据解析和转换
/// - 支持批量导入，提高效率
/// - 统一错误处理，确保数据完整性
class ImportBackendService {
  /// 导入页面数据
  /// 
  /// 功能说明：
  /// 将外部数据导入到指定的父视图下
  /// 支持多种格式：Markdown、Notion、纯文本等
  /// 
  /// 参数：
  /// - [parentViewId]: 父视图ID，导入的页面将成为其子页面
  /// - [values]: 导入项列表，每个项包含数据和元信息
  /// 
  /// 返回：成功导入的视图列表或错误信息
  static Future<FlowyResult<RepeatedViewPB, FlowyError>> importPages(
    String parentViewId,
    List<ImportItemPayloadPB> values,
  ) async {
    // 构建导入请求
    final request = ImportPayloadPB(
      parentViewId: parentViewId,
      items: values,
    );

    // 调用后端导入接口
    return FolderEventImportData(request).send();
  }

  /// 导入ZIP文件
  /// 
  /// 功能说明：
  /// 处理ZIP压缩文件的导入
  /// ZIP文件可能包含多个文档和目录结构
  /// 通常用于批量导入或备份恢复
  /// 
  /// 参数：
  /// - [values]: ZIP文件列表
  /// 
  /// 返回：成功或错误信息
  static Future<FlowyResult<void, FlowyError>> importZipFiles(
    List<ImportZipPB> values,
  ) async {
    // 逐个处理ZIP文件
    for (final value in values) {
      final result = await FolderEventImportZipFile(value).send();
      // 如果任何一个文件导入失败，立即返回错误
      if (result.isFailure) {
        return result;
      }
    }
    // 所有文件都成功导入
    return FlowyResult.success(null);
  }
}
