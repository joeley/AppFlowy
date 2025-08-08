/*
 * 计算类型扩展
 * 
 * 设计理念：
 * 为 CalculationType 枚举添加显示标签的扩展方法。
 * 支持国际化，根据用户语言显示不同的标签文本。
 * 
 * 计算类型说明：
 * - Average：平均值 - 计算所有非空数值的平均值
 * - Max：最大值 - 找出最大的数值
 * - Median：中位数 - 排序后位于中间的值
 * - Min：最小值 - 找出最小的数值
 * - Sum：总和 - 计算所有数值的总和
 * - Count：计数 - 统计非空单元格数量
 * - CountEmpty：空值计数 - 统计空单元格数量
 * - CountNonEmpty：非空计数 - 统计有值的单元格数量
 */

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';

/*
 * 计算类型标签扩展
 * 
 * 为每种计算类型提供可读的标签文本。
 * 支持完整标签和简短标签两种显示模式。
 */
extension CalcTypeLabel on CalculationType {
  /*
   * 获取完整标签
   * 
   * 用于在设置界面、选择列表等地方显示完整名称。
   * 使用 switch 表达式确保所有类型都被处理。
   */
  String get label => switch (this) {
        // 平均值
        CalculationType.Average =>
          LocaleKeys.grid_calculationTypeLabel_average.tr(),
        // 最大值
        CalculationType.Max => LocaleKeys.grid_calculationTypeLabel_max.tr(),
        // 中位数
        CalculationType.Median =>
          LocaleKeys.grid_calculationTypeLabel_median.tr(),
        // 最小值
        CalculationType.Min => LocaleKeys.grid_calculationTypeLabel_min.tr(),
        // 总和
        CalculationType.Sum => LocaleKeys.grid_calculationTypeLabel_sum.tr(),
        // 计数（非空）
        CalculationType.Count =>
          LocaleKeys.grid_calculationTypeLabel_count.tr(),
        // 空值计数
        CalculationType.CountEmpty =>
          LocaleKeys.grid_calculationTypeLabel_countEmpty.tr(),
        // 非空计数
        CalculationType.CountNonEmpty =>
          LocaleKeys.grid_calculationTypeLabel_countNonEmpty.tr(),
        // 如果添加了新的计算类型但没有处理，抛出错误
        _ => throw UnimplementedError(
            'Label for $this has not been implemented',
          ),
      };

  /*
   * 获取简短标签
   * 
   * 用于空间有限的地方，如表格底部的统计栏。
   * 大部分类型使用完整标签，只有部分类型有特别的简短版本。
   */
  String get shortLabel => switch (this) {
        // 空值计数的简短形式
        CalculationType.CountEmpty =>
          LocaleKeys.grid_calculationTypeLabel_countEmptyShort.tr(),
        // 非空计数的简短形式
        CalculationType.CountNonEmpty =>
          LocaleKeys.grid_calculationTypeLabel_countNonEmptyShort.tr(),
        // 其他类型使用完整标签
        _ => label,
      };
}
