import 'package:flexi_kline/flexi_kline.dart';
import 'package:flutter/material.dart';

class MyKlineTheme implements IFlexiKlineTheme {
  @override
  Color get longColor => Colors.green;
  @override
  Color get shortColor => Colors.red;
  @override
  Color get chartBg => Colors.black;
  @override
  Color get tooltipBg => Colors.black;
  @override
  Color get crossTextBg => Colors.black;
  @override
  Color get latestPriceBg => Colors.blue;
  @override
  Color get lastPriceBg => Colors.grey;
  @override
  Color get countDownBg => Colors.orange;
  @override
  Color get dragBg => Colors.white12;

  @override
  Color get gridLineColor => Colors.white10;
  @override
  Color get crosshairColor => Colors.white24;
  @override
  Color get drawToolColor => Colors.yellow;
  @override
  Color get markLineColor => Colors.white30;
  @override
  Color get lineChartColor => Colors.blueAccent;

  @override
  Color get textColor => Colors.white;
  @override
  Color get ticksTextColor => Colors.white70;
  @override
  Color get lastPriceColor => Colors.white;
  @override
  Color get crossTextColor => Colors.white;
  @override
  Color get tooltipTextColor => Colors.white;
}

class MyKlineConfiguration
    with FlexiKlineThemeConfigurationMixin
    implements IConfiguration {
  @override
  String get configKey => "crypto_custom_default";

  @override
  IFlexiKlineTheme get theme => MyKlineTheme();

  @override
  MainPaintObjectIndicator genMainIndicator(
    MainPaintObjectIndicator<Indicator>? mainIndicator,
  ) {
    return mainIndicator ??
        MainPaintObjectIndicator(
          size: const Size(0, 240), // 💡 修正：寬度給 0（套件會自動橫向拉伸填滿螢幕），高度給 240
          padding: const EdgeInsets.symmetric(vertical: 10),
        );
  }

  @override
  FlexiKlineConfig generateFlexiKlineConfig([FlexiKlineConfig? origin]) {
    return FlexiKlineConfig(
      grid: genGridConfig(origin?.grid),
      setting: genSettingConfig(origin?.setting),
      gesture: genGestureConfig(origin?.gesture),
      cross: genCrossConfig(origin?.cross),
      draw: genDrawConfig(origin?.draw),
      mainIndicator: genMainIndicator(origin?.mainIndicator),
    );
  }

  final Map<String, Map<String, dynamic>> _memoryStorage = {};

  @override
  Map<String, dynamic>? getConfig(String key) => _memoryStorage[key];

  @override
  Future<bool> setConfig(String key, Map<String, dynamic> value) async {
    if (value.isEmpty) {
      _memoryStorage.remove(key);
    } else {
      _memoryStorage[key] = value;
    }
    return true;
  }

  @override
  IndicatorBuilder<CandleIndicator> get candleIndicatorBuilder =>
      (map) => CandleIndicator.fromJson(map ?? <String, dynamic>{});

  @override
  IndicatorBuilder<TimeIndicator> get timeIndicatorBuilder =>
      (map) => TimeIndicator.fromJson(map ?? <String, dynamic>{});

  @override
  Map<IIndicatorKey, IndicatorBuilder> get mainIndicatorBuilders => {};

  @override
  Map<IIndicatorKey, IndicatorBuilder> get subIndicatorBuilders => {};

  @override
  Map<IDrawType, DrawObjectBuilder> get drawObjectBuilders => {};
}
