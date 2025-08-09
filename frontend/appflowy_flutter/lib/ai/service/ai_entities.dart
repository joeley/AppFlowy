/// AI实体定义文件
/// 
/// 定义了AI功能模块中使用的所有核心数据结构和实体类
/// 包括：流事件前缀、AI类型、预定义格式、提示词、提示词数据库配置等

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/easy_localiation_service.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

// 代码生成文件，用于JSON序列化
part 'ai_entities.g.dart';

/// AI流事件前缀定义
/// 
/// 定义了AI服务器发送的SSE（Server-Sent Events）流事件的前缀标识
/// 这些前缀用于区分不同类型的事件消息，便于客户端解析和处理
class AIStreamEventPrefix {
  // 数据事件：包含实际的AI响应内容
  static const data = 'data:';
  // 错误事件：包含错误信息
  static const error = 'error:';
  // 元数据事件：包含响应的元信息
  static const metadata = 'metadata:';
  // 开始事件：标记流的开始
  static const start = 'start:';
  // 结束事件：标记流的结束
  static const finish = 'finish:';
  // 注释事件：包含附加说明信息
  static const comment = 'comment:';
  // AI响应限制：达到响应次数限制
  static const aiResponseLimit = 'ai_response_limit:';
  // AI图片响应限制：达到图片生成限制
  static const aiImageResponseLimit = 'ai_image_response_limit:';
  // AI最大值要求：需要升级到更高级别的服务
  static const aiMaxRequired = 'ai_max_required:';
  // 本地AI未就绪：本地AI服务尚未准备好
  static const localAINotReady = 'local_ai_not_ready:';
  // 本地AI已禁用：本地AI功能被禁用
  static const localAIDisabled = 'local_ai_disabled:';
  // AI后续问题：AI生成的后续问题建议
  static const aiFollowUp = 'ai_follow_up:';
}

/// AI服务类型枚举
/// 
/// 区分AI服务的部署方式：云端服务或本地部署
enum AiType {
  // 云端AI服务（如OpenAI、Claude等）
  cloud,
  // 本地AI服务（如Ollama、LocalAI等）
  local;

  // 是否为云端服务
  bool get isCloud => this == cloud;
  // 是否为本地服务
  bool get isLocal => this == local;
}

/// 预定义输出格式类
/// 
/// 定义AI响应的输出格式组合，包括图像格式和文本格式
/// 用于控制AI生成内容的展现形式
class PredefinedFormat extends Equatable {
  const PredefinedFormat({
    required this.imageFormat,
    required this.textFormat,
  });

  // 图像格式：控制是否包含图片
  final ImageFormat imageFormat;
  // 文本格式：控制文本的组织形式（可选）
  final TextFormat? textFormat;

  /// 转换为Protocol Buffer格式
  /// 
  /// 将Flutter实体转换为与后端通信的PB格式
  PredefinedFormatPB toPB() {
    return PredefinedFormatPB(
      // 映射图像格式到PB枚举
      imageFormat: switch (imageFormat) {
        ImageFormat.text => ResponseImageFormatPB.TextOnly,
        ImageFormat.image => ResponseImageFormatPB.ImageOnly,
        ImageFormat.textAndImage => ResponseImageFormatPB.TextAndImage,
      },
      // 映射文本格式到PB枚举（可能为空）
      textFormat: switch (textFormat) {
        TextFormat.paragraph => ResponseTextFormatPB.Paragraph,
        TextFormat.bulletList => ResponseTextFormatPB.BulletedList,
        TextFormat.numberedList => ResponseTextFormatPB.NumberedList,
        TextFormat.table => ResponseTextFormatPB.Table,
        _ => null,
      },
    );
  }

  @override
  List<Object?> get props => [imageFormat, textFormat];
}

/// 图像格式枚举
/// 
/// 定义AI响应中包含的内容类型
enum ImageFormat {
  // 仅文本内容
  text,
  // 仅图片内容
  image,
  // 文本和图片混合内容
  textAndImage;

  // 判断是否包含文本内容
  bool get hasText => this == text || this == textAndImage;

  /// 获取对应的图标
  FlowySvgData get icon {
    return switch (this) {
      ImageFormat.text => FlowySvgs.ai_text_s,
      ImageFormat.image => FlowySvgs.ai_image_s,
      ImageFormat.textAndImage => FlowySvgs.ai_text_image_s,
    };
  }

  /// 获取国际化文本
  String get i18n {
    return switch (this) {
      ImageFormat.text => LocaleKeys.chat_changeFormat_textOnly.tr(),
      ImageFormat.image => LocaleKeys.chat_changeFormat_imageOnly.tr(),
      ImageFormat.textAndImage =>
        LocaleKeys.chat_changeFormat_textAndImage.tr(),
    };
  }
}

/// 文本格式枚举
/// 
/// 定义AI生成文本的组织形式
enum TextFormat {
  // 段落格式
  paragraph,
  // 无序列表格式
  bulletList,
  // 有序列表格式
  numberedList,
  // 表格格式
  table;

  /// 获取对应的图标
  FlowySvgData get icon {
    return switch (this) {
      TextFormat.paragraph => FlowySvgs.ai_paragraph_s,
      TextFormat.bulletList => FlowySvgs.ai_list_s,
      TextFormat.numberedList => FlowySvgs.ai_number_list_s,
      TextFormat.table => FlowySvgs.ai_table_s,
    };
  }

  /// 获取国际化文本
  String get i18n {
    return switch (this) {
      TextFormat.paragraph => LocaleKeys.chat_changeFormat_text.tr(),
      TextFormat.bulletList => LocaleKeys.chat_changeFormat_bullet.tr(),
      TextFormat.numberedList => LocaleKeys.chat_changeFormat_number.tr(),
      TextFormat.table => LocaleKeys.chat_changeFormat_table.tr(),
    };
  }
}

/// AI提示词分类枚举
/// 
/// 定义预定义提示词的分类，帮助用户快速找到需要的提示词模板
enum AiPromptCategory {
  // 其他类别
  other,
  // 开发相关
  development,
  // 写作创作
  writing,
  // 健康与健身
  healthAndFitness,
  // 商业
  business,
  // 市场营销
  marketing,
  // 旅行
  travel,
  // 内容SEO
  contentSeo,
  // 邮件营销
  emailMarketing,
  // 付费广告
  paidAds,
  // 公关传播
  prCommunication,
  // 招聘
  recruiting,
  // 销售
  sales,
  // 社交媒体
  socialMedia,
  // 战略规划
  strategy,
  // 案例研究
  caseStudies,
  // 销售文案
  salesCopy,
  // 教育
  education,
  // 工作
  work,
  // 播客制作
  podcastProduction,
  // 文案写作
  copyWriting,
  // 客户成功
  customerSuccess;

  String get i18n => token.tr();

  String get token {
    return switch (this) {
      other => LocaleKeys.ai_customPrompt_others,
      development => LocaleKeys.ai_customPrompt_development,
      writing => LocaleKeys.ai_customPrompt_writing,
      healthAndFitness => LocaleKeys.ai_customPrompt_healthAndFitness,
      business => LocaleKeys.ai_customPrompt_business,
      marketing => LocaleKeys.ai_customPrompt_marketing,
      travel => LocaleKeys.ai_customPrompt_travel,
      contentSeo => LocaleKeys.ai_customPrompt_contentSeo,
      emailMarketing => LocaleKeys.ai_customPrompt_emailMarketing,
      paidAds => LocaleKeys.ai_customPrompt_paidAds,
      prCommunication => LocaleKeys.ai_customPrompt_prCommunication,
      recruiting => LocaleKeys.ai_customPrompt_recruiting,
      sales => LocaleKeys.ai_customPrompt_sales,
      socialMedia => LocaleKeys.ai_customPrompt_socialMedia,
      strategy => LocaleKeys.ai_customPrompt_strategy,
      caseStudies => LocaleKeys.ai_customPrompt_caseStudies,
      salesCopy => LocaleKeys.ai_customPrompt_salesCopy,
      education => LocaleKeys.ai_customPrompt_education,
      work => LocaleKeys.ai_customPrompt_work,
      podcastProduction => LocaleKeys.ai_customPrompt_podcastProduction,
      copyWriting => LocaleKeys.ai_customPrompt_copyWriting,
      customerSuccess => LocaleKeys.ai_customPrompt_customerSuccess,
    };
  }
}

/// AI提示词实体类
/// 
/// 表示一个AI提示词模板，包含提示词的所有信息
/// 支持JSON序列化，用于网络传输和本地存储
@JsonSerializable()
class AiPrompt extends Equatable {
  const AiPrompt({
    required this.id,
    required this.name,
    required this.content,
    required this.category,
    required this.example,
    required this.isFeatured,
    required this.isCustom,
  });

  /// 从Protocol Buffer创建实例
  /// 
  /// 将后端返回的PB格式数据转换为Flutter实体
  /// 处理分类名称的映射，支持多语言
  factory AiPrompt.fromPB(CustomPromptPB pb) {
    // 构建分类名称映射表
    final map = _buildCategoryNameMap();
    // 解析逗号分隔的分类字符串
    final categories = pb.category
        .split(',')
        .map((categoryName) => categoryName.trim())
        .map(
          (categoryName) {
            // 查找匹配的分类枚举
            final entry = map.entries.firstWhereOrNull(
              (entry) =>
                  entry.value.$1 == categoryName ||
                  entry.value.$2 == categoryName,
            );
            return entry?.key ?? AiPromptCategory.other;
          },
        )
        .toSet()  // 去重
        .toList();

    return AiPrompt(
      id: pb.id,
      name: pb.name,
      content: pb.content,
      category: categories,
      example: pb.example,
      isFeatured: false,  // 自定义提示词默认非精选
      isCustom: true,     // 从PB创建的都是自定义提示词
    );
  }

  factory AiPrompt.fromJson(Map<String, dynamic> json) =>
      _$AiPromptFromJson(json);

  Map<String, dynamic> toJson() => _$AiPromptToJson(this);

  // 提示词唯一标识
  final String id;
  // 提示词名称
  final String name;
  // 提示词内容模板
  final String content;
  // 提示词分类列表（支持多分类）
  @JsonKey(fromJson: _categoryFromJson)
  final List<AiPromptCategory> category;
  // 使用示例（可选）
  @JsonKey(defaultValue: "")
  final String example;
  // 是否为精选提示词
  @JsonKey(defaultValue: false)
  final bool isFeatured;
  // 是否为用户自定义提示词
  @JsonKey(defaultValue: false)
  final bool isCustom;

  @override
  List<Object?> get props =>
      [id, name, content, category, example, isFeatured, isCustom];

  /// 构建分类名称映射表
  /// 
  /// 创建分类枚举到本地化名称的映射
  /// 返回值为元组：(英文名, 本地化名)
  static Map<AiPromptCategory, (String, String)> _buildCategoryNameMap() {
    final service = getIt<EasyLocalizationService>();
    return {
      for (final category in AiPromptCategory.values)
        category: (
          service.getFallbackTranslation(category.token),  // 英文回退翻译
          service.getFallbackTranslation(category.token),  // 本地化翻译
        ),
    };
  }

  /// 从JSON解析分类列表
  /// 
  /// 处理逗号分隔的分类字符串，转换为枚举列表
  /// 如果解析失败，返回默认的"其他"分类
  static List<AiPromptCategory> _categoryFromJson(dynamic json) {
    if (json is String) {
      return json
          .split(',')  // 按逗号分割
          .map((categoryName) => categoryName.trim())  // 去除空格
          .map(
            (categoryName) => $enumDecode(
              _aiPromptCategoryEnumMap,
              categoryName,
              unknownValue: AiPromptCategory.other,  // 未知分类归为其他
            ),
          )
          .toSet()  // 去重
          .toList();
    }

    // 非字符串类型默认返回其他分类
    return [AiPromptCategory.other];
  }
}

/// 提示词分类枚举映射表
/// 
/// 用于JSON序列化/反序列化时的枚举值映射
/// key为枚举值，value为对应的字符串标识
const _aiPromptCategoryEnumMap = {
  AiPromptCategory.other: 'other',
  AiPromptCategory.development: 'development',
  AiPromptCategory.writing: 'writing',
  AiPromptCategory.healthAndFitness: 'healthAndFitness',
  AiPromptCategory.business: 'business',
  AiPromptCategory.marketing: 'marketing',
  AiPromptCategory.travel: 'travel',
  AiPromptCategory.contentSeo: 'contentSeo',
  AiPromptCategory.emailMarketing: 'emailMarketing',
  AiPromptCategory.paidAds: 'paidAds',
  AiPromptCategory.prCommunication: 'prCommunication',
  AiPromptCategory.recruiting: 'recruiting',
  AiPromptCategory.sales: 'sales',
  AiPromptCategory.socialMedia: 'socialMedia',
  AiPromptCategory.strategy: 'strategy',
  AiPromptCategory.caseStudies: 'caseStudies',
  AiPromptCategory.salesCopy: 'salesCopy',
  AiPromptCategory.education: 'education',
  AiPromptCategory.work: 'work',
  AiPromptCategory.podcastProduction: 'podcastProduction',
  AiPromptCategory.copyWriting: 'copyWriting',
  AiPromptCategory.customerSuccess: 'customerSuccess',
};

/// 自定义提示词数据库配置
/// 
/// 定义用于存储自定义提示词的数据库视图配置
/// 指定了各个字段（标题、内容、示例、分类）对应的字段ID
class CustomPromptDatabaseConfig extends Equatable {
  const CustomPromptDatabaseConfig({
    required this.view,
    required this.titleFieldId,
    required this.contentFieldId,
    required this.exampleFieldId,
    required this.categoryFieldId,
  });

  /// 从AI配置PB创建实例
  /// 
  /// 用于AI服务相关的配置解析
  factory CustomPromptDatabaseConfig.fromAiPB(
    CustomPromptDatabaseConfigurationPB pb,
    ViewPB view,
  ) {
    final config = CustomPromptDatabaseConfig(
      view: view,
      titleFieldId: pb.titleFieldId,
      contentFieldId: pb.contentFieldId,
      // 示例字段可选
      exampleFieldId: pb.hasExampleFieldId() ? pb.exampleFieldId : null,
      // 分类字段可选
      categoryFieldId: pb.hasCategoryFieldId() ? pb.categoryFieldId : null,
    );

    return config;
  }

  /// 从数据库配置PB创建实例
  /// 
  /// 用于数据库相关的配置解析
  factory CustomPromptDatabaseConfig.fromDbPB(
    CustomPromptDatabaseConfigPB pb,
    ViewPB view,
  ) {
    final config = CustomPromptDatabaseConfig(
      view: view,
      titleFieldId: pb.titleFieldId,
      contentFieldId: pb.contentFieldId,
      // 示例字段可选
      exampleFieldId: pb.hasExampleFieldId() ? pb.exampleFieldId : null,
      // 分类字段可选
      categoryFieldId: pb.hasCategoryFieldId() ? pb.categoryFieldId : null,
    );

    return config;
  }

  // 关联的数据库视图
  final ViewPB view;
  // 标题字段ID（必需）
  final String titleFieldId;
  // 内容字段ID（必需）
  final String contentFieldId;
  // 示例字段ID（可选）
  final String? exampleFieldId;
  // 分类字段ID（可选）
  final String? categoryFieldId;

  @override
  List<Object?> get props =>
      [view.id, titleFieldId, contentFieldId, exampleFieldId, categoryFieldId];

  /// 复制并修改配置
  /// 
  /// 创建配置的副本，可选择性地修改部分字段
  CustomPromptDatabaseConfig copyWith({
    ViewPB? view,
    String? titleFieldId,
    String? contentFieldId,
    String? exampleFieldId,
    String? categoryFieldId,
  }) {
    return CustomPromptDatabaseConfig(
      view: view ?? this.view,
      titleFieldId: titleFieldId ?? this.titleFieldId,
      contentFieldId: contentFieldId ?? this.contentFieldId,
      exampleFieldId: exampleFieldId ?? this.exampleFieldId,
      categoryFieldId: categoryFieldId ?? this.categoryFieldId,
    );
  }

  /// 转换为AI配置PB格式
  /// 
  /// 用于发送给AI服务的配置数据
  CustomPromptDatabaseConfigurationPB toAiPB() {
    final payload = CustomPromptDatabaseConfigurationPB.create()
      ..viewId = view.id
      ..titleFieldId = titleFieldId
      ..contentFieldId = contentFieldId;

    // 仅在非空时设置可选字段
    if (exampleFieldId != null) {
      payload.exampleFieldId = exampleFieldId!;
    }
    if (categoryFieldId != null) {
      payload.categoryFieldId = categoryFieldId!;
    }

    return payload;
  }

  /// 转换为数据库配置PB格式
  /// 
  /// 用于存储到数据库的配置数据
  CustomPromptDatabaseConfigPB toDbPB() {
    final payload = CustomPromptDatabaseConfigPB.create()
      ..viewId = view.id
      ..titleFieldId = titleFieldId
      ..contentFieldId = contentFieldId;

    // 仅在非空时设置可选字段
    if (exampleFieldId != null) {
      payload.exampleFieldId = exampleFieldId!;
    }
    if (categoryFieldId != null) {
      payload.categoryFieldId = categoryFieldId!;
    }

    return payload;
  }
}
