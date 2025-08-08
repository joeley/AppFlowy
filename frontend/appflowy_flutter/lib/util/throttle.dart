/*
 * 节流工具类
 * 
 * 设计理念：
 * 节流(Throttle)是一种优化技术，用于限制函数的执行频率。
 * 在固定时间间隔内，无论事件触发多少次，只执行第一次。
 * 
 * 工作原理：
 * 1. 第一次调用立即设置定时器
 * 2. 在定时器活跃期间，忽略所有新的调用
 * 3. 定时器结束后才能接受新的调用
 * 
 * 使用场景：
 * - 滚动事件处理（固定频率更新UI）
 * - 鼠标移动跟踪（限制位置更新频率）
 * - API请求限流（防止过度请求）
 * - 实时保存（固定间隔保存）
 * 
 * 与防抖(Debounce)的区别：
 * - 节流：在固定间隔内只执行第一次
 * - 防抖：只执行最后一次
 */

import 'dart:async';

/*
 * 节流器类
 * 
 * 通过定时器控制，确保函数在指定时间间隔内只执行一次。
 */
class Throttler {
  /*
   * 构造函数
   * 
   * 参数：
   * - duration：节流时间间隔，默认1000毫秒
   *   时间越长，执行频率越低
   *   时间越短，执行频率越高
   */
  Throttler({
    this.duration = const Duration(milliseconds: 1000),
  });

  final Duration duration;  /* 节流时间间隔 */
  Timer? _timer;            /* 内部定时器 */

  /*
   * 调用节流函数
   * 
   * 参数：
   * - callback：要执行的回调函数
   * 
   * 执行逻辑：
   * 1. 检查定时器是否活跃
   * 2. 如果活跃，直接返回（忽略本次调用）
   * 3. 如果不活跃，设置新定时器并执行callback
   * 
   * 示例：
   * final throttler = Throttler(duration: Duration(seconds: 1));
   * scrollView.onScroll = () => throttler.call(() => updateUI());
   */
  void call(Function callback) {
    /* 如果定时器活跃，忽略本次调用 */
    if (_timer?.isActive ?? false) return;

    /* 设置新定时器，在duration后执行callback */
    _timer = Timer(duration, () {
      callback();
    });
  }

  /*
   * 取消当前节流
   * 
   * 功能：
   * 取消正在进行的定时器，允许立即接受新的调用
   * 
   * 使用场景：
   * - 需要立即响应用户操作时
   * - 重置节流状态时
   */
  void cancel() {
    _timer?.cancel();
  }

  /*
   * 释放资源
   * 
   * 功能：
   * - 取消定时器
   * - 清空引用
   * 
   * 调用时机：
   * - 组件销毁时
   * - 不再需要节流功能时
   */
  void dispose() {
    _timer?.cancel();  /* 取消定时器 */
    _timer = null;     /* 清空引用，避免内存泄漏 */
  }
}
