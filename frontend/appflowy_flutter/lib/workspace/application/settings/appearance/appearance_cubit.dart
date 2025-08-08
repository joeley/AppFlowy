import 'dart:async';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_settings_service.dart';
import 'package:appflowy/util/color_to_hex_string.dart';
import 'package:appflowy/workspace/application/appearance_defaults.dart';
import 'package:appflowy/workspace/application/settings/appearance/base_appearance.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/date_time.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_setting.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart'
    show AppFlowyEditorLocalizations;
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:universal_platform/universal_platform.dart';

part 'appearance_cubit.freezed.dart';

/*
 * 外观设置管理器
 * 
 * 核心职责：
 * 管理AppFlowy的所有外观相关设置
 * 
 * 管理内容：
 * - 主题样式 (AppTheme)
 * - 明暗模式 (ThemeMode)
 * - 字体样式 (TextStyle)
 * - 语言设置 (Locale)
 * - 日期格式 (UserDateFormatPB)
 * - 时间格式 (UserTimeFormatPB)
 * - 文档编辑器颜色（光标、选中）
 * - 菜单折叠状态
 * - RTL布局支持
 * 
 * 设计特点：
 * - 使用Cubit状态管理
 * - 持久化到后端服务
 * - 支持实时响应
 * - 跨设备同步（部分设置）
 */
class AppearanceSettingsCubit extends Cubit<AppearanceSettingsState> {
  AppearanceSettingsCubit(
    AppearanceSettingsPB appearanceSettings,
    DateTimeSettingsPB dateTimeSettings,
    AppTheme appTheme,
  )   : _appearanceSettings = appearanceSettings,
        _dateTimeSettings = dateTimeSettings,
        super(
          AppearanceSettingsState.initial(
            appTheme,
            appearanceSettings.themeMode,
            appearanceSettings.font,
            appearanceSettings.layoutDirection,
            appearanceSettings.textDirection,
            appearanceSettings.enableRtlToolbarItems,
            appearanceSettings.locale,
            appearanceSettings.isMenuCollapsed,
            appearanceSettings.menuOffset,
            dateTimeSettings.dateFormat,
            dateTimeSettings.timeFormat,
            dateTimeSettings.timezoneId,
            /* 处理文档光标颜色：空字符串表示使用默认值 */
            appearanceSettings.documentSetting.cursorColor.isEmpty
                ? null
                : Color(
                    int.parse(appearanceSettings.documentSetting.cursorColor),
                  ),
            /* 处理文档选中颜色：空字符串表示使用默认值 */
            appearanceSettings.documentSetting.selectionColor.isEmpty
                ? null
                : Color(
                    int.parse(
                      appearanceSettings.documentSetting.selectionColor,
                    ),
                  ),
            1.0, /* 默认文本缩放因子 */
          ),
        ) {
    /* 初始化时读取本地存储的文本缩放因子 */
    readTextScaleFactor();
  }

  /* 外观设置数据对象 */
  final AppearanceSettingsPB _appearanceSettings;
  /* 日期时间设置数据对象 */
  final DateTimeSettingsPB _dateTimeSettings;

  /*
   * 设置文本缩放因子
   * 
   * 特点：
   * - 仅存储在本地，不跨设备同步
   * - 限制范围：0.7-1.0
   * - 超过1.0会导致UI问题
   * 
   * 应用场景：
   * - 适应不同显示器尺寸
   * - 辅助老年用户或视力障碍用户
   */
  Future<void> setTextScaleFactor(double textScaleFactor) async {
    /* 保存到本地存储 */
    await getIt<KeyValueStorage>().set(
      KVKeys.textScaleFactor,
      textScaleFactor.toString(),
    );

    /* 限制缩放范围，避免破坏UI布局 */
    emit(state.copyWith(textScaleFactor: textScaleFactor.clamp(0.7, 1.0)));
  }

  Future<void> readTextScaleFactor() async {
    final textScaleFactor = await getIt<KeyValueStorage>().getWithFormat(
          KVKeys.textScaleFactor,
          (value) => double.parse(value),
        ) ??
        1.0;
    emit(state.copyWith(textScaleFactor: textScaleFactor.clamp(0.7, 1.0)));
  }

  /*
   * 设置应用主题
   * 
   * 功能：
   * 1. 更新用户设置中的主题名称
   * 2. 加载对应的主题资源
   * 3. 应用新主题到UI
   * 
   * 错误处理：
   * - 主题加载失败时记录日志
   * - macOS平台显示错误通知
   * 
   * 异步保存：
   * - 使用unawaited避免阻塞UI
   * - 后台保存到服务器
   */
  Future<void> setTheme(String themeName) async {
    _appearanceSettings.theme = themeName;
    unawaited(_saveAppearanceSettings());
    try {
      final theme = await AppTheme.fromName(themeName);
      emit(state.copyWith(appTheme: theme));
    } catch (e) {
      Log.error("Error setting theme: $e");
      if (UniversalPlatform.isMacOS) {
        showToastNotification(
          message:
              LocaleKeys.settings_workspacePage_theme_failedToLoadThemes.tr(),
          type: ToastificationType.error,
        );
      }
    }
  }

  /// Reset the current user selected theme back to the default
  Future<void> resetTheme() =>
      setTheme(DefaultAppearanceSettings.kDefaultThemeName);

  /*
   * 设置主题模式（明/暗/跟随系统）
   * 
   * 支持模式：
   * - light：明亮模式
   * - dark：暗黑模式
   * - system：跟随系统设置
   */
  void setThemeMode(ThemeMode themeMode) {
    _appearanceSettings.themeMode = _themeModeToPB(themeMode);
    _saveAppearanceSettings();
    emit(state.copyWith(themeMode: themeMode));
  }

  /* 重置主题模式到默认值 */
  void resetThemeMode() =>
      setThemeMode(DefaultAppearanceSettings.kDefaultThemeMode);

  /* 快速切换明暗模式 */
  void toggleThemeMode() {
    final currentThemeMode = state.themeMode;
    setThemeMode(
      currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  /*
   * 设置布局方向（LTR/RTL）
   * 用于支持从右到左的语言（如阿拉伯语、希伯来语）
   */
  void setLayoutDirection(LayoutDirection layoutDirection) {
    _appearanceSettings.layoutDirection = layoutDirection.toLayoutDirectionPB();
    _saveAppearanceSettings();
    emit(state.copyWith(layoutDirection: layoutDirection));
  }

  /*
   * 设置文本方向
   * - ltr：从左到右
   * - rtl：从右到左
   * - auto：自动检测
   */
  void setTextDirection(AppFlowyTextDirection textDirection) {
    _appearanceSettings.textDirection = textDirection.toTextDirectionPB();
    _saveAppearanceSettings();
    emit(state.copyWith(textDirection: textDirection));
  }

  /*
   * 启用/禁用RTL工具栏项
   * 控制编辑器工具栏是否显示RTL相关按钮
   */
  void setEnableRTLToolbarItems(bool value) {
    _appearanceSettings.enableRtlToolbarItems = value;
    _saveAppearanceSettings();
    emit(state.copyWith(enableRtlToolbarItems: value));
  }

  /*
   * 设置字体家族
   * 
   * 影响范围：
   * - 整个应用的显示字体
   * - 文档编辑器的默认字体
   * 
   * 注意：字体需要系统已安装
   */
  void setFontFamily(String fontFamilyName) {
    _appearanceSettings.font = fontFamilyName;
    _saveAppearanceSettings();
    emit(state.copyWith(font: fontFamilyName));
  }

  /* 重置字体到默认值 */
  void resetFontFamily() =>
      setFontFamily(DefaultAppearanceSettings.kDefaultFontFamily);

  /*
   * 设置文档编辑器光标颜色
   * 
   * 作用：自定义输入光标的颜色
   * 存储：转换为十六进制字符串
   */
  void setDocumentCursorColor(Color color) {
    _appearanceSettings.documentSetting.cursorColor = color.toHexString();
    _saveAppearanceSettings();
    emit(state.copyWith(documentCursorColor: color));
  }

  /* 重置光标颜色到默认值 */
  void resetDocumentCursorColor() {
    _appearanceSettings.documentSetting.cursorColor = '';
    _saveAppearanceSettings();
    emit(state.copyWith(documentCursorColor: null));
  }

  /*
   * 设置文档编辑器选中颜色
   * 
   * 作用：自定义文本选中时的背景颜色
   * 提升可读性和个性化体验
   */
  void setDocumentSelectionColor(Color color) {
    _appearanceSettings.documentSetting.selectionColor = color.toHexString();
    _saveAppearanceSettings();
    emit(state.copyWith(documentSelectionColor: color));
  }

  /* 重置选中颜色到默认值 */
  void resetDocumentSelectionColor() {
    _appearanceSettings.documentSetting.selectionColor = '';
    _saveAppearanceSettings();
    emit(state.copyWith(documentSelectionColor: null));
  }

  /*
   * 设置应用语言
   * 
   * 处理流程：
   * 1. 验证语言是否支持
   * 2. 不支持时回退到英文
   * 3. 更新应用和编辑器的语言
   * 4. 保存到设置
   * 
   * 同步机制：
   * - 应用全局语言
   * - 编辑器组件语言
   * - 后端设置存储
   */
  void setLocale(BuildContext context, Locale newLocale) {
    if (!context.supportedLocales.contains(newLocale)) {
      /* 不支持的语言回退到英文 */
      newLocale = const Locale('en', 'US');
    }

    /* 更新全局语言设置 */
    context.setLocale(newLocale).catchError((e) {
      Log.warn('Catch error in setLocale: $e}');
    });

    /* 同步编辑器组件的语言 */
    AppFlowyEditorLocalizations.load(newLocale);

    if (state.locale != newLocale) {
      _appearanceSettings.locale.languageCode = newLocale.languageCode;
      _appearanceSettings.locale.countryCode = newLocale.countryCode ?? "";
      _saveAppearanceSettings();
      emit(state.copyWith(locale: newLocale));
    }
  }

  /*
   * 保存菜单折叠状态
   * 记录侧边栏是否折叠，下次启动时恢复
   */
  void saveIsMenuCollapsed(bool collapsed) {
    _appearanceSettings.isMenuCollapsed = collapsed;
    _saveAppearanceSettings();
  }

  /*
   * 保存菜单宽度偏移量
   * 记录用户调整的侧边栏宽度
   */
  void saveMenuOffset(double offset) {
    _appearanceSettings.menuOffset = offset;
    _saveAppearanceSettings();
  }

  /*
   * 通用键值对存储
   * 
   * 功能：
   * - 保存任意键值对设置
   * - 值为null时删除该键
   * - 支持扩展新设置项
   * 
   * 使用场景：
   * - 插件自定义设置
   * - 实验性功能配置
   * - 临时用户偏好
   */
  void setKeyValue(String key, String? value) {
    if (key.isEmpty) {
      Log.warn("The key should not be empty");
      return;
    }

    if (value == null) {
      _appearanceSettings.settingKeyValue.remove(key);
    }

    if (_appearanceSettings.settingKeyValue[key] != value) {
      if (value == null) {
        _appearanceSettings.settingKeyValue.remove(key);
      } else {
        _appearanceSettings.settingKeyValue[key] = value;
      }
    }
    _saveAppearanceSettings();
  }

  /* 获取键值对设置 */
  String? getValue(String key) {
    if (key.isEmpty) {
      Log.warn("The key should not be empty");
      return null;
    }
    return _appearanceSettings.settingKeyValue[key];
  }

  /*
   * 应用启动时读取语言设置
   * 
   * 逻辑：
   * 1. 首次启动：使用设备语言
   * 2. 非首次启动：使用保存的语言
   * 
   * resetToDefault标志：
   * - true：需要重置到设备默认语言
   * - false：使用用户设置的语言
   */
  void readLocaleWhenAppLaunch(BuildContext context) {
    if (_appearanceSettings.resetToDefault) {
      /* 首次启动或重置后，使用设备语言 */
      _appearanceSettings.resetToDefault = false;
      _saveAppearanceSettings();
      setLocale(context, context.deviceLocale);
      return;
    }

    /* 使用保存的语言设置 */
    setLocale(context, state.locale);
  }

  void setDateFormat(UserDateFormatPB format) {
    _dateTimeSettings.dateFormat = format;
    _saveDateTimeSettings();
    emit(state.copyWith(dateFormat: format));
  }

  void setTimeFormat(UserTimeFormatPB format) {
    _dateTimeSettings.timeFormat = format;
    _saveDateTimeSettings();
    emit(state.copyWith(timeFormat: format));
  }

  /*
   * 保存日期时间设置到后端
   * 包括日期格式、时间格式、时区等
   */
  Future<void> _saveDateTimeSettings() async {
    final result = await UserSettingsBackendService()
        .setDateTimeSettings(_dateTimeSettings);
    result.fold(
      (_) => null,
      (error) => Log.error(error),
    );
  }

  /*
   * 保存外观设置到后端
   * 
   * 保存内容：
   * - 主题、字体、语言
   * - 文档颜色设置
   * - 菜单状态
   * - RTL设置
   * 
   * 错误处理：仅记录日志，不影响用户体验
   */
  Future<void> _saveAppearanceSettings() async {
    final result = await UserSettingsBackendService()
        .setAppearanceSetting(_appearanceSettings);
    result.fold(
      (l) => null,
      (error) => Log.error(error),
    );
  }
}

ThemeMode _themeModeFromPB(ThemeModePB themeModePB) {
  switch (themeModePB) {
    case ThemeModePB.Light:
      return ThemeMode.light;
    case ThemeModePB.Dark:
      return ThemeMode.dark;
    case ThemeModePB.System:
    default:
      return ThemeMode.system;
  }
}

ThemeModePB _themeModeToPB(ThemeMode themeMode) {
  switch (themeMode) {
    case ThemeMode.light:
      return ThemeModePB.Light;
    case ThemeMode.dark:
      return ThemeModePB.Dark;
    case ThemeMode.system:
      return ThemeModePB.System;
  }
}

/*
 * 布局方向枚举
 * 
 * 用于支持不同书写方向的语言：
 * - ltrLayout：从左到右（大部分语言）
 * - rtlLayout：从右到左（阿拉伯语、希伯来语等）
 */
enum LayoutDirection {
  ltrLayout,
  rtlLayout;

  static LayoutDirection fromLayoutDirectionPB(
    LayoutDirectionPB layoutDirectionPB,
  ) =>
      layoutDirectionPB == LayoutDirectionPB.RTLLayout
          ? LayoutDirection.rtlLayout
          : LayoutDirection.ltrLayout;

  LayoutDirectionPB toLayoutDirectionPB() => this == LayoutDirection.rtlLayout
      ? LayoutDirectionPB.RTLLayout
      : LayoutDirectionPB.LTRLayout;
}

/*
 * 文本方向枚举
 * 
 * 支持三种模式：
 * - ltr：强制从左到右
 * - rtl：强制从右到左
 * - auto：根据内容自动判断
 * 
 * auto模式特点：
 * - 根据首个强方向性字符判断
 * - 适合混合语言内容
 */
enum AppFlowyTextDirection {
  ltr,
  rtl,
  auto;

  static AppFlowyTextDirection fromTextDirectionPB(
    TextDirectionPB? textDirectionPB,
  ) {
    switch (textDirectionPB) {
      case TextDirectionPB.LTR:
        return AppFlowyTextDirection.ltr;
      case TextDirectionPB.RTL:
        return AppFlowyTextDirection.rtl;
      case TextDirectionPB.AUTO:
        return AppFlowyTextDirection.auto;
      default:
        return AppFlowyTextDirection.ltr;
    }
  }

  TextDirectionPB toTextDirectionPB() {
    switch (this) {
      case AppFlowyTextDirection.ltr:
        return TextDirectionPB.LTR;
      case AppFlowyTextDirection.rtl:
        return TextDirectionPB.RTL;
      case AppFlowyTextDirection.auto:
        return TextDirectionPB.AUTO;
    }
  }
}

/*
 * 外观设置状态对象
 * 
 * 使用freezed生成不可变对象
 * 包含所有外观相关的设置项
 * 
 * 状态组成：
 * - 主题相关：appTheme, themeMode
 * - 文本相关：font, textScaleFactor
 * - 布局相关：layoutDirection, textDirection, RTL
 * - 国际化：locale, dateFormat, timeFormat
 * - UI状态：isMenuCollapsed, menuOffset
 * - 编辑器颜色：cursorColor, selectionColor
 */
@freezed
class AppearanceSettingsState with _$AppearanceSettingsState {
  const AppearanceSettingsState._();

  const factory AppearanceSettingsState({
    required AppTheme appTheme,
    required ThemeMode themeMode,
    required String font,
    required LayoutDirection layoutDirection,
    required AppFlowyTextDirection textDirection,
    required bool enableRtlToolbarItems,
    required Locale locale,
    required bool isMenuCollapsed,
    required double menuOffset,
    required UserDateFormatPB dateFormat,
    required UserTimeFormatPB timeFormat,
    required String timezoneId,
    required Color? documentCursorColor,
    required Color? documentSelectionColor,
    required double textScaleFactor,
  }) = _AppearanceSettingsState;

  factory AppearanceSettingsState.initial(
    AppTheme appTheme,
    ThemeModePB themeModePB,
    String font,
    LayoutDirectionPB layoutDirectionPB,
    TextDirectionPB? textDirectionPB,
    bool enableRtlToolbarItems,
    LocaleSettingsPB localePB,
    bool isMenuCollapsed,
    double menuOffset,
    UserDateFormatPB dateFormat,
    UserTimeFormatPB timeFormat,
    String timezoneId,
    Color? documentCursorColor,
    Color? documentSelectionColor,
    double textScaleFactor,
  ) {
    return AppearanceSettingsState(
      appTheme: appTheme,
      font: font,
      layoutDirection: LayoutDirection.fromLayoutDirectionPB(layoutDirectionPB),
      textDirection: AppFlowyTextDirection.fromTextDirectionPB(textDirectionPB),
      enableRtlToolbarItems: enableRtlToolbarItems,
      themeMode: _themeModeFromPB(themeModePB),
      locale: Locale(localePB.languageCode, localePB.countryCode),
      isMenuCollapsed: isMenuCollapsed,
      menuOffset: menuOffset,
      dateFormat: dateFormat,
      timeFormat: timeFormat,
      timezoneId: timezoneId,
      documentCursorColor: documentCursorColor,
      documentSelectionColor: documentSelectionColor,
      textScaleFactor: textScaleFactor,
    );
  }

  ThemeData get lightTheme => _getThemeData(Brightness.light);

  ThemeData get darkTheme => _getThemeData(Brightness.dark);

  ThemeData _getThemeData(Brightness brightness) {
    return getIt<BaseAppearance>().getThemeData(
      appTheme,
      brightness,
      font,
      builtInCodeFontFamily,
    );
  }
}
