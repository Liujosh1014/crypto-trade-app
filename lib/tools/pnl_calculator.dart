import 'position_tracker.dart';

class PnlCalculator {
  /// 計算未實現盈虧 (Unrealized PnL)
  static double calculatePnL({
    required double entryPrice,
    required double currentPrice,
    required double quantity,
    required PositionSide side,
  }) {
    if (side == PositionSide.long) {
      return (currentPrice - entryPrice) * quantity;
    } else {
      return (entryPrice - currentPrice) * quantity;
    }
  }

  /// 計算強平價格 (Liquidation Price)
  ///
  /// [maintenanceMarginRate] 維持保證金率（例如：0.005 代表 0.5%）
  /// [liquidationFeeRate] 強平手續費率（例如：0.0005 代表 0.05%）
  static double calculateLiquidationPrice({
    required double entryPrice,
    required double quantity,
    required PositionSide side,
    required double isolatedMargin,
    double maintenanceMarginRate = 0.005, // 預設值，可根據交易所/槓桿調整
    double liquidationFeeRate = 0.0005, // 預設值
  }) {
    if (quantity <= 0) return 0.0;

    // 名義價值 (Notional Value) = 開倉價 * 數量
    final notionalValue = entryPrice * quantity;

    if (side == PositionSide.long) {
      // 多單公式：
      // 強平價 = (開倉價 * 數量 - 逐倉保證金) / (數量 * (1 - 維持保證金率 - 強平手續費率))
      final denominator =
          quantity * (1 - maintenanceMarginRate - liquidationFeeRate);
      if (denominator <= 0) return 0.0;

      final liqPrice = (notionalValue - isolatedMargin) / denominator;
      return liqPrice > 0 ? liqPrice : 0.0;
    } else {
      // 空單公式：
      // 強平價 = (開倉價 * 數量 + 逐倉保證金) / (數量 * (1 + 維持保證金率 + 強平手續費率))
      final denominator =
          quantity * (1 + maintenanceMarginRate + liquidationFeeRate);

      final liqPrice = (notionalValue + isolatedMargin) / denominator;
      return liqPrice;
    }
  }
}
