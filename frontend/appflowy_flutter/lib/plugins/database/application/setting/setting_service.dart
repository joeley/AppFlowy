/*
 * 数据库设置服务层
 * 
 * 设计理念：
 * 提供数据库视图设置的后端服务接口。
 * 获取和管理视图的各种设置选项。
 * 
 * 设置内容：
 * - 过滤器配置
 * - 排序规则
 * - 分组设置
 * - 布局特定设置
 * 
 * 使用场景：
 * 在打开视图时获取保存的设置，
 * 恢复用户的个性化配置。
 */

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/database_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/setting_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

/*
 * 设置后端服务
 * 
 * 负责与后端通信，获取数据库视图的设置信息。
 */
class SettingBackendService {
  const SettingBackendService({required this.viewId});

  final String viewId;

  /*
   * 获取视图设置
   * 
   * 功能说明：
   * 从后端获取指定视图的所有设置信息。
   * 包括过滤器、排序、分组等配置。
   * 
   * 返回值：
   * - 成功：DatabaseViewSettingPB 包含所有设置
   * - 失败：FlowyError 错误信息
   */
  Future<FlowyResult<DatabaseViewSettingPB, FlowyError>> getSetting() {
    final payload = DatabaseViewIdPB.create()..value = viewId;
    return DatabaseEventGetDatabaseSetting(payload).send();
  }
}
