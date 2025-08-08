/*
 * 时间工具
 * 
 * 设计理念：
 * 提供时间格式化和解析功能，专门处理时长表示。
 * 支持"2h 30m"这样的人类可读格式。
 * 
 * 核心功能：
 * 1. 解析时间字符串为分钟数
 * 2. 格式化分钟数为可读字符串
 * 
 * 使用场景：
 * - 任务时长设置
 * - 倒计时显示
 * - 时间输入处理
 * - 进度跟踪
 * 
 * 支持的格式：
 * - 纯数字："60" => 60分钟
 * - 小时："2h" => 120分钟
 * - 分钟："30m" => 30分钟
 * - 组合："2h 30m" => 150分钟
 */

/*
 * 时间格式正则表达式
 * 
 * 匹配模式：
 * - (?<hours>\d*)h：可选的小时部分，捕获组名为hours
 * - ? ?：可选的空格分隔符
 * - (?<minutes>\d*)m：可选的分钟部分，捕获组名为minutes
 * 
 * 示例匹配：
 * - "2h" => hours=2, minutes=null
 * - "30m" => hours=null, minutes=30
 * - "2h 30m" => hours=2, minutes=30
 * - "2h30m" => hours=2, minutes=30（无空格也支持）
 */
final RegExp timerRegExp =
    RegExp(r'(?:(?<hours>\d*)h)? ?(?:(?<minutes>\d*)m)?');

/*
 * 解析时间字符串
 * 
 * 功能：
 * 将各种格式的时间字符串转换为分钟数。
 * 
 * 参数：
 * - timerStr：时间字符串
 * 
 * 支持的输入格式：
 * 1. 纯数字："60" => 60分钟
 * 2. 小时格式："2h" => 120分钟
 * 3. 分钟格式："30m" => 30分钟
 * 4. 组合格式："2h 30m" => 150分钟
 * 
 * 返回值：
 * - int：总分钟数
 * - null：格式无效
 * 
 * 解析流程：
 * 1. 首先尝试直接解析为数字
 * 2. 使用正则表达式匹配时间格式
 * 3. 验证格式正确性
 * 4. 计算总分钟数
 */
int? parseTime(String timerStr) {
  /* 尝试直接解析为数字 */
  int? res = int.tryParse(timerStr);
  if (res != null) {
    return res;
  }

  /* 使用正则表达式匹配 */
  final matches = timerRegExp.firstMatch(timerStr);
  if (matches == null) {
    return null;
  }
  
  /* 提取小时和分钟 */
  final hours = int.tryParse(matches.namedGroup('hours') ?? "");
  final minutes = int.tryParse(matches.namedGroup('minutes') ?? "");
  
  /* 如果都没有值，返回null */
  if (hours == null && minutes == null) {
    return null;
  }

  /* 验证格式：重构字符串并对比 */
  final expected =
      "${hours != null ? '${hours}h' : ''}${hours != null && minutes != null ? ' ' : ''}${minutes != null ? '${minutes}m' : ''}";
  if (timerStr != expected) {
    return null;  /* 格式不匹配 */
  }

  /* 计算总分钟数 */
  res = 0;
  res += hours != null ? hours * 60 : res;  /* 小时转分钟 */
  res += minutes ?? 0;  /* 加上分钟 */

  return res;
}

/*
 * 格式化时间
 * 
 * 功能：
 * 将分钟数转换为可读的时间字符串。
 * 
 * 参数：
 * - minutes：总分钟数
 * 
 * 返回格式：
 * - 小于60分钟："30m"
 * - 正好整小时："2h"
 * - 小时加分钟："2h 30m"
 * - 负数或无效：空字符串
 * 
 * 格式化规则：
 * 1. 优先显示小时（如果大于等于60分钟）
 * 2. 整小时不显示分钟部分
 * 3. 有余数时显示完整的小时和分钟
 * 
 * 示例：
 * - formatTime(30) => "30m"
 * - formatTime(60) => "1h"
 * - formatTime(90) => "1h 30m"
 * - formatTime(120) => "2h"
 */
String formatTime(int minutes) {
  /* 大于等于60分钟，显示小时 */
  if (minutes >= 60) {
    if (minutes % 60 == 0) {
      /* 整小时 */
      return "${minutes ~/ 60}h";
    }
    /* 小时加分钟 */
    return "${minutes ~/ 60}h ${minutes % 60}m";
  } else if (minutes >= 0) {
    /* 小于60分钟，只显示分钟 */
    return "${minutes}m";
  }
  /* 负数或其他无效值 */
  return "";
}
