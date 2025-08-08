/*
 * 防抖工具类
 * 
 * 设计理念：
 * 防抖(Debounce)是一种优化技术，用于限制函数的执行频率。
 * 当事件连续触发时，只有在指定时间内没有新的触发才会执行。
 * 
 * 工作原理：
 * 1. 每次调用时取消之前的定时器
 * 2. 设置新的定时器
 * 3. 只有最后一次调用的定时器会执行
 * 
 * 使用场景：
 * - 搜索框输入（等待用户停止输入后再搜索）
 * - 窗口调整大小（等待调整结束后再重新布局）
 * - 按钮防重复点击
 * - 自动保存（等待用户停止编辑后再保存）
 * 
 * 与节流(Throttle)的区别：
 * - 防抖：在事件停止触发后执行
 * - 节流：在固定时间间隔内只执行一次
 */

import 'dart:async';

/*
 * 防抖类
 * 
 * 通过延迟执行和取消机制，
 * 确保函数只在最后一次触发后执行。
 */
class Debounce {
  /*
   * 构造函数
   * 
   * 参数：
   * - duration：防抖延迟时间，默认1000毫秒
   *   时间越长，触发越不频繁
   *   时间越短，响应越灵敏
   */
  Debounce({
    this.duration = const Duration(milliseconds: 1000),
  });

  final Duration duration;  /* 防抖延迟时间 */
  Timer? _timer;            /* 内部定时器 */

  /*
   * 调用防抖函数
   * 
   * 参数：
   * - action：要执行的函数
   * 
   * 执行流程：
   * 1. 取消之前的定时器（如果存在）
   * 2. 创建新的定时器
   * 3. 在指定时间后执行action
   * 
   * 示例：
   * final debounce = Debounce(duration: Duration(milliseconds: 500));
   * textField.onChanged = (text) => debounce.call(() => search(text));
   */
  void call(Function action) {
    /* 取消之前的定时器，重新计时 */
    dispose();

    /* 设置新的定时器 */
    _timer = Timer(duration, () {
      action();
    });
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
   * - 不再需要防抖功能时
   * - 在call方法中重置定时器
   */
  void dispose() {
    _timer?.cancel();  /* 取消定时器 */
    _timer = null;     /* 清空引用，避免内存泄漏 */
  }
}
