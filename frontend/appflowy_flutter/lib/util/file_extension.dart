/*
 * 文件扩展工具
 * 
 * 设计理念：
 * 为String类型添加文件相关的扩展方法。
 * 将文件路径字符串转换为文件操作的便捷接口。
 * 
 * 使用场景：
 * - 快速获取文件大小
 * - 文件存在性检查
 * - 文件属性查询
 * 
 * 扩展方法优势：
 * - 语法简洁：path.fileSize 替代 File(path).lengthSync()
 * - 链式调用：支持流畅的API设计
 * - 类型安全：编译时类型检查
 */

import 'dart:io';

/*
 * 文件大小扩展
 * 
 * 为String类型添加fileSize属性，
 * 直接从文件路径获取文件大小。
 */
extension FileSizeExtension on String {
  /*
   * 获取文件大小
   * 
   * 功能：
   * 将字符串作为文件路径，返回文件的字节大小
   * 
   * 返回值：
   * - int：文件大小（字节）
   * - null：文件不存在
   * 
   * 实现逻辑：
   * 1. 创建File对象
   * 2. 检查文件是否存在
   * 3. 存在则返回文件大小，否则返回null
   * 
   * 使用示例：
   * final path = "/path/to/file.txt";
   * final size = path.fileSize;
   * if (size != null) {
   *   print("文件大小: $size 字节");
   * }
   * 
   * 注意事项：
   * - 使用同步API，可能阻塞UI
   * - 大文件建议使用异步方法
   * - 需要文件读取权限
   */
  int? get fileSize {
    /* 创建文件对象 */
    final file = File(this);
    /* 检查文件存在性并返回大小 */
    if (file.existsSync()) {
      return file.lengthSync();
    }
    /* 文件不存在返回null */
    return null;
  }
}
