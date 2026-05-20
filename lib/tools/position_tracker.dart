import 'package:flutter/material.dart';
import 'pnl_calculator.dart';
import '../data/websocket_manager.dart';

// 定義持倉方向列舉（如果原本檔案沒定義，補上）
enum PositionSide { long, short }

class Position {
  final String symbol;
  final double entryPrice;
  final double quantity;
  final int leverage;
  final PositionSide side;

  Position({
    required this.symbol,
    required this.entryPrice,
    required this.quantity,
    required this.leverage,
    required this.side,
  });
}

class PositionTracker extends ChangeNotifier {
  // 由外部傳入單例（Singleton）的 WebSocketManager，避免重複連線
  final WebSocketManager _ws;

  double _money = 10000.0;
  double _currentPrice = 0.0;
  final List<Position> _positions = [];

  Stream<double> get priceStream => _ws.priceStream;

  WebSocketManager get ws => _ws; // 方便測試或其他工具直接訪問 WebSocketManager

  // Getters
  double get money => _money;
  List<Position> get positions => _positions;
  double get currentPrice => _currentPrice;

  PositionTracker(this._ws) {
    // 監聽價格串流，即時同步最新價格快照
    _ws.priceStream.listen((price) {
      _currentPrice = price;
      notifyListeners(); // 價格更新時通知 UI 刷新
    });

    // 初始化預設持倉（改用 listen 一次性處理，避免 firstWhere 卡死）
    late var subscription;
    subscription = _ws.priceStream.listen((price) {
      if (price > 0 && _positions.isEmpty) {
        _positions.add(
          Position(
            symbol: "BTCUSDT",
            entryPrice: price,
            quantity: 0.1,
            leverage: 20,
            side: PositionSide.long,
          ),
        );
        notifyListeners();
        subscription.cancel(); // 成功加入後就取消這個初始化的監聽
      }
    });
  }

  // 下單邏輯
  void openPosition(Position pos) {
    // 檢查餘額是否足夠保證金（此處可依需求加入 PnlCalculator 判斷）
    _positions.add(pos);
    notifyListeners(); // 這裡會通知 UI 重新整理列表
  }

  // 計算未實現盈虧
  double getUnrealizedPnl(Position pos, double price) {
    return PnlCalculator.calculatePnL(
      entryPrice: pos.entryPrice,
      currentPrice: price,
      quantity: pos.quantity,
      side: pos.side,
    );
  }

  // 平倉邏輯（直接使用當前快照價格，改為同步執行，更安全）
  void closePosition(int index) {
    if (index < 0 || index >= _positions.length) return;

    final targetPos = _positions[index];
    // 如果最新價格還是 0（尚未收到訊號），就用開倉價當作平倉價防止報錯
    final price = _currentPrice > 0 ? _currentPrice : targetPos.entryPrice;

    final pnl = getUnrealizedPnl(targetPos, price);

    _money += pnl; // 更新餘額
    _positions.removeAt(index); // 移除倉位

    notifyListeners(); // 同時觸發餘額與持倉列表的 UI 更新！
  }
}
