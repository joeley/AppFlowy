/*
 * 数据库计算功能服务层
 * 
 * 设计理念：
 * 计算功能允许用户对列数据进行统计分析，类似 Excel 的聚合函数。
 * 支持求和、平均值、最大值、最小值、计数等多种计算类型。
 * 
 * 使用场景：
 * - 表格底部显示列的统计信息
 * - 看板视图中显示每个分组的统计数据
 * - 数据分析和报表生成
 * 
 * 架构说明：
 * 服务层封装了与后端的通信，提供计算的增删改查接口。
 * 计算结果会实时更新，当数据变化时自动重新计算。
 */

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';

/*
 * 计算功能后端服务
 * 
 * 职责：
 * 1. 获取视图的所有计算配置
 * 2. 更新字段的计算类型
 * 3. 删除不需要的计算
 * 
 * 设计特点：
 * - 每个字段可以有多个计算
 * - 计算与视图关联，不同视图可以有不同的计算配置
 * - 支持批量获取和单个更新
 */
class CalculationsBackendService {
  const CalculationsBackendService({required this.viewId});

  final String viewId;

  /*
   * 获取所有计算配置
   * 
   * 功能说明：
   * 在打开视图时调用，获取该视图的所有计算配置。
   * 返回的数据包含每个字段的计算类型和计算结果。
   * 
   * 返回值：
   * - 成功：RepeatedCalculationsPB 包含所有计算配置
   * - 失败：FlowyError 错误信息
   */

  Future<FlowyResult<RepeatedCalculationsPB, FlowyError>>
      getCalculations() async {
    final payload = DatabaseViewIdPB()..value = viewId;

    return DatabaseEventGetAllCalculations(payload).send();
  }

  /*
   * 更新或创建计算
   * 
   * 参数：
   * - fieldId：字段ID，指定要计算的列
   * - type：计算类型（求和、平均值、最大值等）
   * - calculationId：可选，已有计算的ID（更新时使用）
   * 
   * 使用说明：
   * - 如果提供 calculationId，则更新现有计算
   * - 如果不提供，则为该字段创建新计算
   * 
   * 计算类型示例：
   * - Sum：求和（适用于数字字段）
   * - Average：平均值
   * - Count：计数（非空单元格数量）
   * - CountEmpty：空单元格数量
   */
  Future<void> updateCalculation(
    String fieldId,
    CalculationType type, {
    String? calculationId,
  }) async {
    // 构建更新请求负载
    final payload = UpdateCalculationChangesetPB()
      ..viewId = viewId          // 视图ID
      ..fieldId = fieldId        // 要计算的字段
      ..calculationType = type;  // 计算类型

    // 如果是更新现有计算，添加计算ID
    if (calculationId != null) {
      payload.calculationId = calculationId;
    }

    // 发送更新请求到后端
    await DatabaseEventUpdateCalculation(payload).send();
  }

  /*
   * 删除计算
   * 
   * 参数：
   * - fieldId：字段ID
   * - calculationId：要删除的计算ID
   * 
   * 使用场景：
   * 用户取消某个字段的统计计算时调用。
   * 删除后，该字段将不再显示统计信息。
   */
  Future<void> removeCalculation(
    String fieldId,
    String calculationId,
  ) async {
    // 构建删除请求
    final payload = RemoveCalculationChangesetPB()
      ..viewId = viewId              // 视图ID
      ..fieldId = fieldId            // 字段ID
      ..calculationId = calculationId; // 要删除的计算ID

    // 发送删除请求
    await DatabaseEventRemoveCalculation(payload).send();
  }
}
