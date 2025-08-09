import 'dart:convert';
import 'dart:math';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/string_extension.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/icon.dart';
import 'package:appflowy/shared/icon_emoji_picker/icon_search_bar.dart';
import 'package:appflowy/shared/icon_emoji_picker/recent_icons.dart';
import 'package:appflowy/util/debounce.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/space_icon_popup.dart';
import 'package:appflowy_backend/log.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';

import 'colors.dart';
import 'icon_color_picker.dart';

/// 图标组缓存
/// 避免多次加载图标资源，提高性能
List<IconGroup>? kIconGroups;

/// 最近使用图标组的名称常量
const _kRecentIconGroupName = 'Recent';

/// 图标组过滤扩展
/// 
/// 提供图标组列表的实用方法
extension IconGroupFilter on List<IconGroup> {
  /// 根据键查找SVG内容
  /// 
  /// 参数：
  /// - key: 格式为 "groupName/iconName" 的键
  /// 
  /// 返回：
  /// - SVG内容字符串，未找到返回null
  String? findSvgContent(String key) {
    final values = key.split('/');
    if (values.length != 2) {
      return null;
    }
    final groupName = values[0];
    final iconName = values[1];
    // 在缓存的图标组中查找匹配的SVG内容
    final svgString = kIconGroups
        ?.firstWhereOrNull(
          (group) => group.name == groupName,
        )
        ?.icons
        .firstWhereOrNull(
          (icon) => icon.name == iconName,
        )
        ?.content;
    return svgString;
  }

  /// 获取随机图标
  /// 
  /// 从所有图标组中随机选择一个图标
  /// 
  /// 返回：
  /// - (图标组, 图标) 元组
  (IconGroup, Icon) randomIcon() {
    final random = Random();
    final group = this[random.nextInt(length)];
    final icon = group.icons[random.nextInt(group.icons.length)];
    return (group, icon);
  }
}

/// 加载图标组
/// 
/// 功能说明：
/// 1. 从assets加载图标JSON文件
/// 2. 解析并缓存图标数据
/// 3. 记录加载性能
/// 
/// 优化策略：
/// - 使用缓存避免重复加载
/// - 异步加载不阻塞UI
/// - 错误处理保证稳定性
/// 
/// 返回：
/// - 图标组列表
Future<List<IconGroup>> loadIconGroups() async {
  // 如果已缓存，直接返回
  if (kIconGroups != null) {
    return kIconGroups!;
  }

  // 性能监控
  final stopwatch = Stopwatch()..start();
  
  // 从assets加载图标配置文件
  final jsonString = await rootBundle.loadString('assets/icons/icons.json');
  try {
    // 解析JSON数据
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    // 转换为图标组对象
    final iconGroups = json.entries.map(IconGroup.fromMapEntry).toList();
    // 缓存结果
    kIconGroups = iconGroups;
    return iconGroups;
  } catch (e) {
    Log.error('Failed to decode icons.json', e);
    return [];
  } finally {
    stopwatch.stop();
    Log.info('Loaded icon groups in ${stopwatch.elapsedMilliseconds}ms');
  }
}

/// 图标选择器结果
/// 
/// 包含选中的图标数据和选择方式
class IconPickerResult {
  IconPickerResult(this.data, this.isRandom);

  /// 选中的图标数据
  final IconsData data;
  
  /// 是否为随机选择
  final bool isRandom;
}

/// IconsData到IconPickerResult的扩展
/// 
/// 提供便捷的转换方法
extension IconsDataToIconPickerResultExtension on IconsData {
  /// 转换为选择器结果
  IconPickerResult toResult({bool isRandom = false}) =>
      IconPickerResult(this, isRandom);
}

/// Flowy图标选择器主组件
/// 
/// 功能说明：
/// 1. 提供图标搜索功能
/// 2. 支持最近使用图标
/// 3. 支持随机选择图标
/// 4. 可选背景色选择
/// 5. 响应式网格布局
/// 
/// 使用场景：
/// - 空间图标选择
/// - 页面图标选择
/// - 文档图标装饰
class FlowyIconPicker extends StatefulWidget {
  const FlowyIconPicker({
    super.key,
    required this.onSelectedIcon,
    required this.enableBackgroundColorSelection,
    this.iconPerLine = 9,
    this.ensureFocus = false,
  });

  /// 是否启用背景色选择功能
  final bool enableBackgroundColorSelection;
  
  /// 图标选中回调
  final ValueChanged<IconPickerResult> onSelectedIcon;
  
  /// 每行显示的图标数量
  final int iconPerLine;
  
  /// 是否确保搜索框获得焦点
  final bool ensureFocus;

  @override
  State<FlowyIconPicker> createState() => _FlowyIconPickerState();
}

class _FlowyIconPickerState extends State<FlowyIconPicker> {
  /// 图标组数据列表
  final List<IconGroup> iconGroups = [];
  
  /// 加载状态标志
  bool loaded = false;
  
  /// 搜索关键词通知器
  final ValueNotifier<String> keyword = ValueNotifier('');
  
  /// 搜索防抖器，避免频繁触发搜索
  final debounce = Debounce(duration: const Duration(milliseconds: 150));

  /// 加载图标数据
  /// 
  /// 执行流程：
  /// 1. 加载本地图标组
  /// 2. 加载最近使用的图标
  /// 3. 合并并更新UI
  Future<void> loadIcons() async {
    // 加载本地图标组
    final localIcons = await loadIconGroups();
    
    // 加载并处理最近使用的图标
    final recentIcons = await RecentIcons.getIcons();
    if (recentIcons.isNotEmpty) {
      // 过滤和限制最近图标数量
      // 只显示一行最近使用的图标
      final filterRecentIcons = recentIcons
          .sublist(
            0,
            min(recentIcons.length, widget.iconPerLine),
          )
          .skipWhile((e) => e.groupName.isEmpty)
          .map((e) => e.icon)
          .toList();
      
      // 如果有有效的最近图标，添加到列表顶部
      if (filterRecentIcons.isNotEmpty) {
        iconGroups.add(
          IconGroup(
            name: _kRecentIconGroupName,
            icons: filterRecentIcons,
          ),
        );
      }
    }
    
    // 添加所有本地图标组
    iconGroups.addAll(localIcons);
    
    // 更新UI状态
    if (mounted) {
      setState(() {
        loaded = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadIcons();
  }

  @override
  void dispose() {
    keyword.dispose();
    debounce.dispose();
    iconGroups.clear();
    loaded = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: IconSearchBar(
            ensureFocus: widget.ensureFocus,
            onRandomTap: () {
              // 获取随机图标
              final value = kIconGroups?.randomIcon();
              if (value == null) {
                return;
              }
              
              // 根据设置决定是否生成随机颜色
              final color = widget.enableBackgroundColorSelection
                  ? generateRandomSpaceColor()
                  : null;
              
              // 触发选中回调，标记为随机选择
              widget.onSelectedIcon(
                IconsData(
                  value.$1.name,
                  value.$2.name,
                  color,
                ).toResult(isRandom: true),
              );
              
              // 更新最近使用记录
              RecentIcons.putIcon(RecentIcon(value.$2, value.$1.name));
            },
            onKeywordChanged: (keyword) => {
              // 使用防抖处理搜索输入
              debounce.call(() {
                this.keyword.value = keyword;
              }),
            },
          ),
        ),
        Expanded(
          child: loaded
              ? _buildIcons(iconGroups)
              : const Center(
                  child: SizedBox.square(
                    dimension: 24.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// 构建图标显示区域
  /// 
  /// 根据搜索关键词动态过滤和显示图标
  Widget _buildIcons(List<IconGroup> iconGroups) {
    return ValueListenableBuilder(
      valueListenable: keyword,
      builder: (_, keyword, __) {
        if (keyword.isNotEmpty) {
          // 有搜索关键词时，过滤图标组
          final filteredIconGroups = iconGroups
              .map((iconGroup) => iconGroup.filter(keyword))
              .where((iconGroup) => iconGroup.icons.isNotEmpty)
              .toList();
          return IconPicker(
            iconGroups: filteredIconGroups,
            enableBackgroundColorSelection:
                widget.enableBackgroundColorSelection,
            onSelectedIcon: (r) => widget.onSelectedIcon.call(r.toResult()),
            iconPerLine: widget.iconPerLine,
          );
        }
        // 无搜索关键词时，显示所有图标
        return IconPicker(
          iconGroups: iconGroups,
          enableBackgroundColorSelection: widget.enableBackgroundColorSelection,
          onSelectedIcon: (r) => widget.onSelectedIcon.call(r.toResult()),
          iconPerLine: widget.iconPerLine,
        );
      },
    );
  }
}

/// 图标数据模型
/// 
/// 包含图标的完整信息：
/// - 所属组名
/// - 图标名称
/// - 背景颜色（可选）
/// 
/// 支持序列化为JSON格式用于存储
class IconsData {
  IconsData(this.groupName, this.iconName, this.color);

  /// 图标组名称
  final String groupName;
  
  /// 图标名称
  final String iconName;
  
  /// 背景颜色（十六进制字符串）
  final String? color;

  /// 转换为JSON字符串
  /// 用于存储和传输
  String get iconString => jsonEncode({
        'groupName': groupName,
        'iconName': iconName,
        if (color != null) 'color': color,
      });

  /// 转换为Emoji图标数据
  EmojiIconData toEmojiIconData() => EmojiIconData.icon(this);

  /// 创建无颜色版本
  IconsData noColor() => IconsData(groupName, iconName, null);

  /// 从JSON解析
  static IconsData fromJson(dynamic json) {
    return IconsData(
      json['groupName'],
      json['iconName'],
      json['color'],
    );
  }

  /// 获取SVG内容字符串
  /// 从缓存的图标组中查找对应的SVG内容
  String? get svgString => kIconGroups
      ?.firstWhereOrNull((group) => group.name == groupName)
      ?.icons
      .firstWhereOrNull((icon) => icon.name == iconName)
      ?.content;
}

/// 图标选择器核心组件
/// 
/// 功能说明：
/// 1. 显示图标网格
/// 2. 支持分组显示
/// 3. 可选颜色选择器
/// 4. 处理图标点击事件
/// 
/// 交互设计：
/// - 点击图标直接选择（无背景色模式）
/// - 点击图标弹出颜色选择器（有背景色模式）
/// - 滚动时自动关闭颜色选择器
class IconPicker extends StatefulWidget {
  const IconPicker({
    super.key,
    required this.onSelectedIcon,
    required this.enableBackgroundColorSelection,
    required this.iconGroups,
    required this.iconPerLine,
  });

  /// 图标组列表
  final List<IconGroup> iconGroups;
  
  /// 每行图标数量
  final int iconPerLine;
  
  /// 是否启用背景色选择
  final bool enableBackgroundColorSelection;
  
  /// 图标选中回调
  final ValueChanged<IconsData> onSelectedIcon;

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker> {
  /// 弹出层互斥锁
  /// 确保同时只有一个颜色选择器打开
  final mutex = PopoverMutex();
  
  /// 子弹出层控制器
  /// 用于管理颜色选择器的显示/隐藏
  PopoverController? childPopoverController;

  @override
  void dispose() {
    super.dispose();
    childPopoverController = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hideColorSelector,
      child: NotificationListener(
        onNotification: (notificationInfo) {
          if (notificationInfo is ScrollStartNotification) {
            hideColorSelector();
          }
          return true;
        },
        child: ListView.builder(
          itemCount: widget.iconGroups.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemBuilder: (context, index) {
            final iconGroup = widget.iconGroups[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlowyText(
                  iconGroup.displayName.capitalize(),
                  fontSize: 12,
                  figmaLineHeight: 18.0,
                  color: context.pickerTextColor,
                ),
                const VSpace(4.0),
                GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.iconPerLine,
                  ),
                  itemCount: iconGroup.icons.length,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final icon = iconGroup.icons[index];
                    return widget.enableBackgroundColorSelection
                        ? _Icon(
                            icon: icon,
                            mutex: mutex,
                            onOpen: (childPopoverController) {
                              this.childPopoverController =
                                  childPopoverController;
                            },
                            onSelectedColor: (context, color) {
                              // 处理组名：最近使用的图标需要获取原始组名
                              String groupName = iconGroup.name;
                              if (groupName == _kRecentIconGroupName) {
                                groupName = getGroupName(index);
                              }
                              
                              // 触发选中回调
                              widget.onSelectedIcon(
                                IconsData(
                                  groupName,
                                  icon.name,
                                  color,
                                ),
                              );
                              
                              // 更新最近使用记录
                              RecentIcons.putIcon(RecentIcon(icon, groupName));
                              
                              // 关闭弹出层
                              PopoverContainer.of(context).close();
                            },
                          )
                        : _IconNoBackground(
                            icon: icon,
                            onSelectedIcon: () {
                              // 处理组名：最近使用的图标需要获取原始组名
                              String groupName = iconGroup.name;
                              if (groupName == _kRecentIconGroupName) {
                                groupName = getGroupName(index);
                              }
                              
                              // 触发选中回调（无颜色）
                              widget.onSelectedIcon(
                                IconsData(
                                  groupName,
                                  icon.name,
                                  null,
                                ),
                              );
                              
                              // 更新最近使用记录
                              RecentIcons.putIcon(RecentIcon(icon, groupName));
                            },
                          );
                  },
                ),
                const VSpace(12.0),
                if (index == widget.iconGroups.length - 1) ...[
                  const StreamlinePermit(),
                  const VSpace(12.0),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// 隐藏颜色选择器
  /// 
  /// 在滚动或点击其他区域时调用
  void hideColorSelector() {
    childPopoverController?.close();
    childPopoverController = null;
  }

  /// 获取最近使用图标的原始组名
  /// 
  /// 参数：
  /// - index: 图标在最近使用列表中的索引
  /// 
  /// 返回：
  /// - 原始组名，错误时返回空字符串
  String getGroupName(int index) {
    final recentIcons = RecentIcons.getIconsSync();
    try {
      return recentIcons[index].groupName;
    } catch (e) {
      Log.error('getGroupName with index: $index error', e);
      return '';
    }
  }
}

/// 无背景图标组件
/// 
/// 显示单个图标，不支持背景色选择
/// 点击直接触发选中回调
class _IconNoBackground extends StatelessWidget {
  const _IconNoBackground({
    required this.icon,
    required this.onSelectedIcon,
    this.isSelected = false,
  });

  /// 图标数据
  final Icon icon;
  
  /// 是否处于选中状态
  final bool isSelected;
  
  /// 选中回调
  final VoidCallback onSelectedIcon;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: icon.displayName,
      preferBelow: false,
      child: FlowyButton(
        isSelected: isSelected,
        useIntrinsicWidth: true,
        onTap: () => onSelectedIcon(),
        margin: const EdgeInsets.all(8.0),
        text: Center(
          child: FlowySvg.string(
            icon.content,
            size: const Size.square(20),
            color: context.pickerIconColor,
            opacity: 0.7,
          ),
        ),
      ),
    );
  }
}

/// 带背景色选择的图标组件
/// 
/// 功能说明：
/// 1. 显示图标
/// 2. 点击弹出颜色选择器
/// 3. 支持选中状态显示
/// 4. 使用互斥锁确保单一弹出层
class _Icon extends StatefulWidget {
  const _Icon({
    required this.icon,
    required this.mutex,
    required this.onSelectedColor,
    this.onOpen,
  });

  /// 图标数据
  final Icon icon;
  
  /// 弹出层互斥锁
  final PopoverMutex mutex;
  
  /// 颜色选中回调
  final void Function(BuildContext context, String color) onSelectedColor;
  
  /// 弹出层打开回调
  final ValueChanged<PopoverController>? onOpen;

  @override
  State<_Icon> createState() => _IconState();
}

class _IconState extends State<_Icon> {
  final PopoverController _popoverController = PopoverController();
  bool isSelected = false;

  @override
  void dispose() {
    super.dispose();
    _popoverController.close();
  }

  @override
  Widget build(BuildContext context) {
    return AppFlowyPopover(
      direction: PopoverDirection.bottomWithCenterAligned,
      controller: _popoverController,
      offset: const Offset(0, 6),
      mutex: widget.mutex,
      onClose: () {
        updateIsSelected(false);
      },
      clickHandler: PopoverClickHandler.gestureDetector,
      child: _IconNoBackground(
        icon: widget.icon,
        isSelected: isSelected,
        onSelectedIcon: () {
          updateIsSelected(true);
          _popoverController.show();
          widget.onOpen?.call(_popoverController);
        },
      ),
      popupBuilder: (context) {
        return Container(
          padding: const EdgeInsets.all(6.0),
          child: IconColorPicker(
            onSelected: (color) => widget.onSelectedColor(context, color),
          ),
        );
      },
    );
  }

  /// 更新选中状态
  /// 
  /// 在弹出层打开/关闭时调用
  void updateIsSelected(bool isSelected) {
    setState(() {
      this.isSelected = isSelected;
    });
  }
}

/// Streamline版权声明组件
/// 
/// 显示图标来源和版权信息
/// 包含可点击的链接跳转到Streamline官网
class StreamlinePermit extends StatelessWidget {
  const StreamlinePermit({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 开源图标来自Streamline
    final textStyle = TextStyle(
      fontSize: 12.0,
      height: 18.0 / 12.0,
      fontWeight: FontWeight.w500,
      color: context.pickerTextColor,
    );
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${LocaleKeys.emoji_openSourceIconsFrom.tr()} ',
            style: textStyle,
          ),
          TextSpan(
            text: 'Streamline',
            style: textStyle.copyWith(
              decoration: TextDecoration.underline,
              color: Theme.of(context).colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                afLaunchUrlString('https://www.streamlinehq.com/');
              },
          ),
        ],
      ),
    );
  }
}
