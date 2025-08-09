import 'dart:io';

import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/plugins/document/application/document_appearance_cubit.dart';
import 'package:appflowy/shared/clipboard_state.dart';
import 'package:appflowy/shared/easy_localiation_service.dart';
import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/shared/icon_emoji_picker/icon_picker.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_settings_service.dart';
import 'package:appflowy/util/font_family_extension.dart';
import 'package:appflowy/util/string_extension.dart';
import 'package:appflowy/workspace/application/action_navigation/action_navigation_bloc.dart';
import 'package:appflowy/workspace/application/action_navigation/navigation_action.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy/workspace/application/notification/notification_service.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/appearance/base_appearance.dart';
import 'package:appflowy/workspace/application/settings/notifications/notification_settings_cubit.dart';
import 'package:appflowy/workspace/application/sidebar/rename_view/rename_view_bloc.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/command_palette/command_palette.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:universal_platform/universal_platform.dart';

import 'prelude.dart';

/// 应用Widget初始化任务
/// 
/// 功能说明：
/// 1. 初始化应用的根Widget
/// 2. 配置多语言支持
/// 3. 设置全局主题
/// 4. 初始化通知服务
/// 5. 加载图标资源
/// 
/// 这是应用启动的核心任务，负责构建整个应用的Widget树
class InitAppWidgetTask extends LaunchTask {
  const InitAppWidgetTask();

  @override
  LaunchTaskType get type => LaunchTaskType.appLauncher;

  /// 初始化应用Widget
  /// 
  /// 执行流程：
  /// 1. 确保Flutter绑定初始化
  /// 2. 初始化通知服务
  /// 3. 加载图标组资源
  /// 4. 获取用户设置（外观、时间格式）
  /// 5. 创建应用根Widget
  /// 6. 配置多语言支持
  /// 7. 启动应用
  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 确保Flutter框架已初始化
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化通知服务（用于应用内通知）
    await NotificationService.initialize();

    // 加载图标组（用于图标选择器）
    await loadIconGroups();

    // 通过依赖注入获取入口点并创建主Widget
    final widget = context.getIt<EntryPoint>().create(context.config);
    
    // 获取用户的外观设置（主题、字体、语言等）
    final appearanceSetting =
        await UserSettingsBackendService().getAppearanceSetting();
    
    // 获取日期时间格式设置
    final dateTimeSettings =
        await UserSettingsBackendService().getDateTimeSettings();

    // 创建应用根Widget
    // 使用context作为key，确保context变化时重建Widget
    final app = ApplicationWidget(
      key: ValueKey(context),
      appearanceSetting: appearanceSetting,
      dateTimeSettings: dateTimeSettings,
      appTheme: await appTheme(appearanceSetting.theme),
      child: widget,
    );

    // 启动应用，配置多语言支持
    runApp(
      EasyLocalization(
        // 支持的语言列表（按字母顺序排列）
        supportedLocales: const [
          Locale('am', 'ET'),  // 阿姆哈拉语（埃塞俄比亚）
          Locale('ar', 'SA'),  // 阿拉伯语（沙特）
          Locale('ca', 'ES'),  // 加泰罗尼亚语（西班牙）
          Locale('cs', 'CZ'),  // 捷克语
          Locale('ckb', 'KU'), // 库尔德语
          Locale('de', 'DE'),  // 德语
          Locale('en', 'US'),  // 英语（美国）
          Locale('en', 'GB'),  // 英语（英国）
          Locale('es', 'VE'),  // 西班牙语（委内瑞拉）
          Locale('eu', 'ES'),  // 巴斯克语（西班牙）
          Locale('el', 'GR'),  // 希腊语
          Locale('fr', 'FR'),  // 法语（法国）
          Locale('fr', 'CA'),  // 法语（加拿大）
          Locale('he'),        // 希伯来语
          Locale('hu', 'HU'),  // 匈牙利语
          Locale('id', 'ID'),  // 印度尼西亚语
          Locale('it', 'IT'),  // 意大利语
          Locale('ja', 'JP'),  // 日语
          Locale('ko', 'KR'),  // 韩语
          Locale('pl', 'PL'),  // 波兰语
          Locale('pt', 'BR'),  // 葡萄牙语（巴西）
          Locale('ru', 'RU'),  // 俄语
          Locale('sv', 'SE'),  // 瑞典语
          Locale('th', 'TH'),  // 泰语
          Locale('tr', 'TR'),  // 土耳其语
          Locale('uk', 'UA'),  // 乌克兰语
          Locale('ur'),        // 乌尔都语
          Locale('vi', 'VN'),  // 越南语
          Locale('zh', 'CN'),  // 中文（简体）
          Locale('zh', 'TW'),  // 中文（繁体）
          Locale('fa'),        // 波斯语
          Locale('hin'),       // 印地语
          Locale('mr', 'IN'),  // 马拉地语（印度）
        ],
        // 翻译文件路径
        path: 'assets/translations',
        // 默认语言（当系统语言不支持时）
        fallbackLocale: const Locale('en', 'US'),
        // 启用回退翻译
        useFallbackTranslations: true,
        child: Builder(
          builder: (context) {
            // 初始化本地化服务
            getIt.get<EasyLocalizationService>().init(context);
            return app;
          },
        ),
      ),
    );

    return;
  }
}

/// 应用程序根Widget
/// 
/// 功能说明：
/// 1. 管理全局状态（主题、语言、设置）
/// 2. 提供全局的BLoC
/// 3. 配置路由
/// 4. 处理系统UI样式
/// 
/// 这是整个应用的状态容器，所有全局状态都在这里管理
class ApplicationWidget extends StatefulWidget {
  const ApplicationWidget({
    super.key,
    required this.child,
    required this.appTheme,
    required this.appearanceSetting,
    required this.dateTimeSettings,
  });

  /// 子Widget（通常是路由页面）
  final Widget child;
  /// 应用主题
  final AppTheme appTheme;
  /// 外观设置
  final AppearanceSettingsPB appearanceSetting;
  /// 日期时间设置
  final DateTimeSettingsPB dateTimeSettings;

  @override
  State<ApplicationWidget> createState() => _ApplicationWidgetState();
}

class _ApplicationWidgetState extends State<ApplicationWidget> {
  /// 路由配置
  /// 使用late final确保只初始化一次，避免主题变化时重建路由
  late final GoRouter routerConfig;

  /// 命令面板通知器
  /// 用于控制命令面板的显示和隐藏
  final _commandPaletteNotifier = ValueNotifier(CommandPaletteNotifierValue());

  /// 主题构建器
  /// 用于生成应用的明暗主题
  final themeBuilder = AppFlowyDefaultTheme();

  @override
  void initState() {
    super.initState();
    // 初始化路由配置
    // 只在initState中初始化一次，避免主题变化时重建路由导致导航状态丢失
    routerConfig = generateRouter(widget.child);
  }

  @override
  void dispose() {
    // 清理资源
    _commandPaletteNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        if (FeatureFlag.search.isOn)
          BlocProvider<CommandPaletteBloc>(create: (_) => CommandPaletteBloc()),
        BlocProvider<AppearanceSettingsCubit>(
          create: (_) => AppearanceSettingsCubit(
            widget.appearanceSetting,
            widget.dateTimeSettings,
            widget.appTheme,
          )..readLocaleWhenAppLaunch(context),
        ),
        BlocProvider<NotificationSettingsCubit>(
          create: (_) => NotificationSettingsCubit(),
        ),
        BlocProvider<DocumentAppearanceCubit>(
          create: (_) => DocumentAppearanceCubit()..fetch(),
        ),
        BlocProvider.value(value: getIt<RenameViewBloc>()),
        BlocProvider.value(value: getIt<ActionNavigationBloc>()),
      ],
      child: BlocListener<ActionNavigationBloc, ActionNavigationState>(
        listenWhen: (_, curr) => curr.action != null,
        listener: (context, state) {
          final action = state.action;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (action?.type == ActionType.openView &&
                UniversalPlatform.isDesktop) {
              final view =
                  action!.arguments?[ActionArgumentKeys.view] as ViewPB?;
              final nodePath = action.arguments?[ActionArgumentKeys.nodePath];
              final blockId = action.arguments?[ActionArgumentKeys.blockId];
              if (view != null) {
                getIt<TabsBloc>().openPlugin(
                  view,
                  arguments: {
                    PluginArgumentKeys.selection: nodePath,
                    PluginArgumentKeys.blockId: blockId,
                  },
                );
              }
            } else if (action?.type == ActionType.openRow &&
                UniversalPlatform.isMobile) {
              final view = action!.arguments?[ActionArgumentKeys.view];
              if (view != null) {
                final view = action.arguments?[ActionArgumentKeys.view];
                final rowId = action.arguments?[ActionArgumentKeys.rowId];
                AppGlobals.rootNavKey.currentContext?.pushView(
                  view,
                  arguments: {
                    PluginArgumentKeys.rowId: rowId,
                  },
                );
              }
            }
          });
        },
        child: BlocBuilder<AppearanceSettingsCubit, AppearanceSettingsState>(
          builder: (context, state) {
            _setSystemOverlayStyle(state);
            return Provider(
              create: (_) => ClipboardState(),
              dispose: (_, state) => state.dispose(),
              child: ToastificationWrapper(
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    /// This is a workaround to deal with below question:
                    /// When the mouse hovers over the tooltip, the scroll event is intercepted by it
                    /// Here, we listen for the scroll event and then remove the tooltip to avoid that situation
                    if (pointerSignal is PointerScrollEvent) {
                      Tooltip.dismissAllToolTips();
                    }
                  },
                  child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: state.lightTheme,
                    darkTheme: state.darkTheme,
                    themeMode: state.themeMode,
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    locale: state.locale,
                    routerConfig: routerConfig,
                    builder: (context, child) {
                      final brightness = Theme.of(context).brightness;
                      final fontFamily = state.font
                          .orDefault(defaultFontFamily)
                          .fontFamilyName;

                      return AnimatedAppFlowyTheme(
                        data: brightness == Brightness.light
                            ? themeBuilder.light(fontFamily: fontFamily)
                            : themeBuilder.dark(fontFamily: fontFamily),
                        child: MediaQuery(
                          // use the 1.0 as the textScaleFactor to avoid the text size
                          //  affected by the system setting.
                          data: MediaQuery.of(context).copyWith(
                            textScaler:
                                TextScaler.linear(state.textScaleFactor),
                          ),
                          child: overlayManagerBuilder(
                            context,
                            !UniversalPlatform.isMobile &&
                                    FeatureFlag.search.isOn
                                ? CommandPalette(
                                    notifier: _commandPaletteNotifier,
                                    child: child,
                                  )
                                : child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 设置系统UI样式
  /// 
  /// Android平台特有：
  /// 1. 启用边到边显示模式
  /// 2. 设置透明导航栏
  /// 
  /// 这让应用内容可以延伸到状态栏和导航栏区域
  void _setSystemOverlayStyle(AppearanceSettingsState state) {
    if (Platform.isAndroid) {
      // 设置边到边模式，隐藏系统UI
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [],  // 不显示任何系统覆盖层
      );
      // 设置透明导航栏
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
        ),
      );
    }
  }
}

/// 应用全局对象
/// 
/// 提供全局访问点：
/// - 导航器状态
/// - 全局context
/// 
/// 使用场景：
/// - 在没有context的地方进行导航
/// - 获取全局context进行操作
class AppGlobals {
  /// 根导航器的全局key
  static GlobalKey<NavigatorState> rootNavKey = GlobalKey();

  /// 获取导航器状态
  static NavigatorState get nav => rootNavKey.currentState!;

  /// 获取全局context
  static BuildContext get context => rootNavKey.currentContext!;
}

/// 加载应用主题
/// 
/// 功能说明：
/// 1. 根据主题名称加载对应的主题
/// 2. 如果主题名为空或加载失败，使用默认主题
/// 
/// 参数：
/// - [themeName]: 主题名称
/// 
/// 返回：
/// - AppTheme对象
Future<AppTheme> appTheme(String themeName) async {
  if (themeName.isEmpty) {
    return AppTheme.fallback;  // 使用默认主题
  } else {
    try {
      return await AppTheme.fromName(themeName);  // 根据名称加载主题
    } catch (e) {
      return AppTheme.fallback;  // 加载失败，使用默认主题
    }
  }
}
