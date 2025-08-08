/*
 * 文档服务层
 * 
 * 设计理念：
 * 提供文档操作的服务接口，封装与后端的通信细节。
 * 处理文档的创建、打开、关闭、同步等核心业务逻辑。
 * 
 * 核心功能：
 * 1. 文档生命周期管理（创建、打开、关闭）
 * 2. 文档数据获取和更新
 * 3. 块操作和文本同步
 * 4. 文件上传下载
 * 5. 协作状态同步
 * 
 * 架构设计：
 * - 使用Dispatch模式与Rust后端通信
 * - 返回FlowyResult统一错误处理
 * - 支持ProtoBuf序列化
 * - 提供异步API接口
 * 
 * 使用场景：
 * - 文档编辑器初始化
 * - 实时协作同步
 * - 文件附件管理
 * - 离线编辑支持
 */

import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-document/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:fixnum/fixnum.dart';

/*
 * 文档服务类
 * 
 * 职责：
 * 1. 封装文档相关的后端API
 * 2. 处理数据转换和错误
 * 3. 提供统一的服务接口
 * 4. 管理文档状态同步
 */
class DocumentService {
  /*
   * 创建新文档
   * 
   * 功能：
   * 创建一个新的文档实例。
   * 
   * 处理逻辑：
   * 1. 先尝试打开文档（检查是否已存在）
   * 2. 如果能打开说明已存在，直接返回成功
   * 3. 否则创建新文档
   * 
   * 参数：
   * - view：视图信息，包含文档ID
   * 
   * 注意：当前未使用此方法
   */
  Future<FlowyResult<void, FlowyError>> createDocument({
    required ViewPB view,
  }) async {
    /* 检查文档是否已存在 */
    final canOpen = await openDocument(documentId: view.id);
    if (canOpen.isSuccess) {
      return FlowyResult.success(null);
    }
    /* 创建新文档 */
    final payload = CreateDocumentPayloadPB()..documentId = view.id;
    final result = await DocumentEventCreateDocument(payload).send();
    return result;
  }

  /*
   * 打开文档
   * 
   * 功能：
   * 打开指定ID的文档，初始化文档编辑会话。
   * 
   * 使用场景：
   * - 用户点击文档列表项
   * - 从链接跳转到文档
   * - 恢复上次编辑
   * 
   * 返回：文档数据对象
   */
  Future<FlowyResult<DocumentDataPB, FlowyError>> openDocument({
    required String documentId,
  }) async {
    final payload = OpenDocumentPayloadPB()..documentId = documentId;
    final result = await DocumentEventOpenDocument(payload).send();
    return result;
  }

  /*
   * 获取文档数据
   * 
   * 功能：
   * 获取文档的完整数据，不创建编辑会话。
   * 
   * 与openDocument的区别：
   * - openDocument：创建编辑会话，用于编辑
   * - getDocument：仅获取数据，用于只读访问
   * 
   * 使用场景：
   * - 预览文档内容
   * - 导出文档数据
   * - 同步差分计算
   */
  Future<FlowyResult<DocumentDataPB, FlowyError>> getDocument({
    required String documentId,
  }) async {
    final payload = OpenDocumentPayloadPB()..documentId = documentId;
    final result = await DocumentEventGetDocumentData(payload).send();
    return result;
  }

  /*
   * 获取文档节点
   * 
   * 功能：
   * 获取文档中指定块的完整信息，包括文档数据、块数据和节点对象。
   * 
   * 处理流程：
   * 1. 获取完整文档数据
   * 2. 从文档中查找指定块
   * 3. 构建节点树对象
   * 4. 返回三元组结果
   * 
   * 参数：
   * - documentId：文档ID
   * - blockId：块ID
   * 
   * 返回：(文档数据, 块数据, 节点对象) 三元组
   * 
   * 使用场景：
   * - 定位到特定内容块
   * - 编辑特定段落
   * - 引用块内容
   */
  Future<FlowyResult<(DocumentDataPB, BlockPB, Node), FlowyError>>
      getDocumentNode({
    required String documentId,
    required String blockId,
  }) async {
    /* 获取文档数据 */
    final documentResult = await getDocument(documentId: documentId);
    final document = documentResult.fold((l) => l, (f) => null);
    if (document == null) {
      Log.error('unable to get the document for page $documentId');
      return FlowyResult.failure(FlowyError(msg: 'Document not found'));
    }

    /* 查找指定块 */
    final blockResult = await getBlockFromDocument(
      document: document,
      blockId: blockId,
    );
    final block = blockResult.fold((l) => l, (f) => null);
    if (block == null) {
      Log.error(
        'unable to get the block $blockId from the document $documentId',
      );
      return FlowyResult.failure(FlowyError(msg: 'Block not found'));
    }

    /* 构建节点对象 */
    final node = document.buildNode(blockId);
    if (node == null) {
      Log.error(
        'unable to get the node for block $blockId in document $documentId',
      );
      return FlowyResult.failure(FlowyError(msg: 'Node not found'));
    }

    return FlowyResult.success((document, block, node));
  }

  /*
   * 从文档中获取块
   * 
   * 功能：
   * 从已加载的文档数据中查找指定ID的块。
   * 
   * 参数：
   * - document：文档数据对象
   * - blockId：要查找的块ID
   * 
   * 返回：块数据对象或错误
   * 
   * 注意：这是一个本地查找操作，不涉及网络请求
   */
  Future<FlowyResult<BlockPB, FlowyError>> getBlockFromDocument({
    required DocumentDataPB document,
    required String blockId,
  }) async {
    /* 从块映射表中查找 */
    final block = document.blocks[blockId];

    if (block != null) {
      return FlowyResult.success(block);
    }

    /* 块不存在，返回错误 */
    return FlowyResult.failure(
      FlowyError(
        msg: 'Block($blockId) not found in Document(${document.pageId})',
      ),
    );
  }

  /*
   * 关闭文档
   * 
   * 功能：
   * 关闭文档编辑会话，释放相关资源。
   * 
   * 处理内容：
   * - 保存未保存的更改
   * - 清理编辑器状态
   * - 释放内存资源
   * - 断开协作连接
   * 
   * 参数：
   * - viewId：视图ID（等同于文档ID）
   */
  Future<FlowyResult<void, FlowyError>> closeDocument({
    required String viewId,
  }) async {
    final payload = ViewIdPB()..value = viewId;
    final result = await FolderEventCloseView(payload).send();
    return result;
  }

  /*
   * 应用块操作
   * 
   * 功能：
   * 批量应用块级操作到文档，如插入、删除、更新块。
   * 
   * 参数：
   * - documentId：目标文档ID
   * - actions：操作列表
   * 
   * 操作类型：
   * - 插入新块
   * - 删除现有块
   * - 更新块内容
   * - 移动块位置
   * 
   * 使用场景：
   * - 批量编辑操作
   * - 撤销/重做功能
   * - 模板应用
   */
  Future<FlowyResult<void, FlowyError>> applyAction({
    required String documentId,
    required Iterable<BlockActionPB> actions,
  }) async {
    final payload = ApplyActionPayloadPB(
      documentId: documentId,
      actions: actions,
    );
    final result = await DocumentEventApplyAction(payload).send();
    return result;
  }

  /*
   * 创建外部文本
   * 
   * 功能：
   * 创建独立存储的长文本内容，适用于需要单独同步的大文本块。
   * 
   * 设计原因：
   * - 大文本块单独存储可优化性能
   * - 支持增量同步减少传输量
   * - 便于实现协作编辑
   * 
   * 参数：
   * - documentId：所属文档ID
   * - textId：文本块唯一ID
   * - delta：Delta格式的JSON字符串（富文本内容）
   * 
   * 使用场景：
   * - 创建长段落
   * - 代码块内容
   * - 表格单元格文本
   */
  Future<FlowyResult<void, FlowyError>> createExternalText({
    required String documentId,
    required String textId,
    String? delta,
  }) async {
    final payload = TextDeltaPayloadPB(
      documentId: documentId,
      textId: textId,
      delta: delta,
    );
    final result = await DocumentEventCreateText(payload).send();
    return result;
  }

  /*
   * 更新外部文本
   * 
   * 功能：
   * 更新已存在的外部文本内容。
   * 
   * 与createExternalText的关系：
   * - 使用相同的数据格式
   * - 必须先创建才能更新
   * - 支持增量更新
   * 
   * 参数：
   * - documentId：所属文档ID
   * - textId：文本块ID
   * - delta：新的Delta内容（JSON格式）
   * 
   * 使用场景：
   * - 编辑长文本内容
   * - 应用格式变更
   * - 同步远程更改
   */
  Future<FlowyResult<void, FlowyError>> updateExternalText({
    required String documentId,
    required String textId,
    String? delta,
  }) async {
    final payload = TextDeltaPayloadPB(
      documentId: documentId,
      textId: textId,
      delta: delta,
    );
    final result = await DocumentEventApplyTextDeltaEvent(payload).send();
    return result;
  }

  /*
   * 上传文件到云存储
   * 
   * 功能：
   * 将本地文件上传到云端存储，用于文档附件。
   * 
   * 处理流程：
   * 1. 获取当前工作区信息
   * 2. 构建上传参数
   * 3. 执行上传操作
   * 4. 返回上传结果
   * 
   * 参数：
   * - localFilePath：本地文件路径
   * - documentId：关联的文档ID
   * 
   * 返回：上传成功的文件信息（URL、大小等）
   * 
   * 使用场景：
   * - 插入图片
   * - 添加附件
   * - 嵌入文件
   */
  Future<FlowyResult<UploadedFilePB, FlowyError>> uploadFile({
    required String localFilePath,
    required String documentId,
  }) async {
    /* 获取当前工作区 */
    final workspace = await FolderEventReadCurrentWorkspace().send();
    return workspace.fold(
      (l) async {
        /* 构建上传参数 */
        final payload = UploadFileParamsPB(
          workspaceId: l.id,
          localFilePath: localFilePath,
          documentId: documentId,
        );
        /* 执行上传 */
        return DocumentEventUploadFile(payload).send();
      },
      (r) async {
        return FlowyResult.failure(FlowyError(msg: 'Workspace not found'));
      },
    );
  }

  /*
   * 从云存储下载文件
   * 
   * 功能：
   * 下载云端存储的文件到本地。
   * 
   * 参数：
   * - url：文件的云端URL
   * 
   * 使用场景：
   * - 查看附件
   * - 导出文件
   * - 离线缓存
   * 
   * 注意：
   * - 需要有效的工作区上下文
   * - 文件会下载到默认缓存目录
   */
  Future<FlowyResult<void, FlowyError>> downloadFile({
    required String url,
  }) async {
    final workspace = await FolderEventReadCurrentWorkspace().send();
    return workspace.fold((l) async {
      final payload = DownloadFilePB(
        url: url,
      );
      final result = await DocumentEventDownloadFile(payload).send();
      return result;
    }, (r) async {
      return FlowyResult.failure(FlowyError(msg: 'Workspace not found'));
    });
  }

  /*
   * 同步协作感知状态
   * 
   * 功能：
   * 同步用户的编辑状态到其他协作者，实现实时协作可视化。
   * 
   * 同步内容：
   * - 光标位置
   * - 选区范围
   * - 用户信息
   * - 在线状态
   * 
   * 参数：
   * - documentId：文档ID
   * - selection：当前选区
   * - metadata：元数据（用户名、颜色等）
   * 
   * 使用场景：
   * - 显示其他用户光标
   * - 标识正在编辑的段落
   * - 避免编辑冲突
   */
  Future<FlowyResult<void, FlowyError>> syncAwarenessStates({
    required String documentId,
    Selection? selection,
    String? metadata,
  }) async {
    final payload = UpdateDocumentAwarenessStatePB(
      documentId: documentId,
      selection: convertSelectionToAwarenessSelection(selection),
      metadata: metadata,
    );

    final result = await DocumentEventSetAwarenessState(payload).send();
    return result;
  }

  /*
   * 转换选区格式
   * 
   * 功能：
   * 将编辑器的Selection对象转换为协作感知的ProtoBuf格式。
   * 
   * 转换内容：
   * - 起始位置（路径和偏移）
   * - 结束位置（路径和偏移）
   * - 数据类型转换（int到Int64）
   * 
   * 返回：ProtoBuf格式的选区对象
   */
  DocumentAwarenessSelectionPB? convertSelectionToAwarenessSelection(
    Selection? selection,
  ) {
    if (selection == null) {
      return null;
    }
    /* 构建协作选区对象 */
    return DocumentAwarenessSelectionPB(
      start: DocumentAwarenessPositionPB(
        offset: Int64(selection.startIndex),
        path: selection.start.path.map((e) => Int64(e)),
      ),
      end: DocumentAwarenessPositionPB(
        offset: Int64(selection.endIndex),
        path: selection.end.path.map((e) => Int64(e)),
      ),
    );
  }
}
