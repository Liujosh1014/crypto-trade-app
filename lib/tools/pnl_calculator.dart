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

  /// 計算強平價格 (Liquidation Price) - 簡化版（不含手續費與維持保證金率）
  static double calculateLiquidationPrice({
    required double entryPrice,
    required int leverage,
    required PositionSide side,
  }) {
    if (side == PositionSide.long) {
      return entryPrice * (1 - 1 / leverage);
    } else {
      return entryPrice * (1 + 1 / leverage);
    }
  }
}
