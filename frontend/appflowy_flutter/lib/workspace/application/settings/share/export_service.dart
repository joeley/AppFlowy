import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/database_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/share_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

/// 后端导出服务 - 负责数据库视图的导出功能
/// 
/// 主要功能：
/// 1. 导出数据库为CSV格式
/// 2. 导出数据库原始数据
/// 
/// 设计思想：
/// - 通过Rust后端处理导出逻辑，确保数据完整性
/// - 支持多种导出格式，满足不同使用场景
/// - 使用静态方法，无需实例化对象
class BackendExportService {
  /// 导出数据库为CSV格式
  /// 
  /// CSV格式特点：
  /// - 通用格式，可被Excel、Google Sheets等软件打开
  /// - 文本格式，便于分享和处理
  /// - 可能丢失部分格式信息（如颜色、字体等）
  /// 
  /// 参数：
  /// - [viewId]: 数据库视图ID
  /// 
  /// 返回：导出的数据或错误信息
  static Future<FlowyResult<DatabaseExportDataPB, FlowyError>>
      exportDatabaseAsCSV(
    String viewId,
  ) async {
    // 构建请求参数
    final payload = DatabaseViewIdPB.create()..value = viewId;
    // 调用后端导出CSV接口
    return DatabaseEventExportCSV(payload).send();
  }

  /// 导出数据库原始数据
  /// 
  /// 原始数据格式特点：
  /// - 保留所有数据结构和元信息
  /// - 可用于备份和迁移
  /// - 可以完整恢复数据库状态
  /// - 通常为JSON或专有格式
  /// 
  /// 参数：
  /// - [viewId]: 数据库视图ID
  /// 
  /// 返回：导出的原始数据或错误信息
  static Future<FlowyResult<DatabaseExportDataPB, FlowyError>>
      exportDatabaseAsRawData(
    String viewId,
  ) async {
    // 构建请求参数
    final payload = DatabaseViewIdPB.create()..value = viewId;
    // 调用后端导出原始数据接口
    return DatabaseEventExportRawDatabaseData(payload).send();
  }
}
