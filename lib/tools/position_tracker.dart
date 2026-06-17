import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pnl_calculator.dart';
import '../data/websocket_manager.dart';

enum PositionSide { long, short }

class Position {
  final String symbol;
  final double entryPrice;
  final double quantity;
  final int leverage;
  final PositionSide side;
  final double isolatedMargin;

  Position({
    required this.symbol,
    required this.entryPrice,
    required this.quantity,
    required this.leverage,
    required this.side,
    required this.isolatedMargin,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'entryPrice': entryPrice,
      'quantity': quantity,
      'leverage': leverage,
      'side': side.name,
      'isolatedMargin': isolatedMargin,
    };
  }

  factory Position.fromMap(Map<String, dynamic> map) {
    return Position(
      symbol: map['symbol'] ?? 'BTCUSDT',
      entryPrice: (map['entryPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      leverage: (map['leverage'] as num).toInt(),
      side: map['side'] == 'short' ? PositionSide.short : PositionSide.long,
      isolatedMargin:
          (map['isolatedMargin'] as num?)?.toDouble() ??
          ((map['entryPrice'] as num).toDouble() *
              (map['quantity'] as num).toDouble() /
              (map['leverage'] as num).toInt()),
    );
  }
}

class PositionTracker extends ChangeNotifier {
  final WebSocketManager _ws;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _money = 10000.0;
  final List<Position> _positions = [];

  // 改為儲存全幣種價格的 Map
  final Map<String, double> _prices = {
    "BTCUSDT": 0.0,
    "ETHUSDT": 0.0,
    "SOLUSDT": 0.0,
  };

  double get money => _money;
  List<Position> get positions => _positions;
  Map<String, double> get prices => _prices;
  double get availableBalance => _money > 0 ? _money : 0.0;

  // 安全獲取特定代幣最新價
  double getPrice(String symbol) => _prices[symbol] ?? 0.0;

  PositionTracker(this._ws) {
    // 訂閱多幣種字典，隨時通知 UI 刷新
    _ws.priceMapStream.listen((updatedPrices) {
      _prices.addAll(updatedPrices);

      _checkLiquidation();

      notifyListeners();
    });
  }

  Future<void> loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // 1. 載入餘額
        if (data['money'] != null) {
          _money = (data['money'] as num).toDouble();
        }

        // 2. 載入持倉 (假設你將持倉存成陣列或子集合，這裡以陣列為例)
        if (data['positions'] != null) {
          final List<dynamic> posList = data['positions'];
          _positions.clear();
          _positions.addAll(posList.map((e) => Position.fromMap(e)));
        }

        notifyListeners(); // 通知介面更新
        print("Firestore 資料載入成功！");
      }
    } catch (e) {
      print("載入 Firestore 失敗: $e");
    }
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _money = (data['money'] as num? ?? 10000.0).toDouble();
        _positions.clear();
        if (data['positions'] != null) {
          final List<dynamic> cloudPositions = data['positions'];
          for (var item in cloudPositions) {
            _positions.add(Position.fromMap(item as Map<String, dynamic>));
          }
        }
      } else {
        _money = 10000.0;
        _positions.clear();
        await _firestore.collection('users').doc(user.uid).set({
          'money': _money,
          'positions': [],
        });
      }
      notifyListeners();
    } catch (e) {
      print("下載雲端持倉失敗: $e");
    }
  }

  Future<void> syncDataToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final List<Map<String, dynamic>> positionMaps = _positions
          .map((pos) => pos.toMap())
          .toList();
      await _firestore.collection('users').doc(user.uid).set({
        'money': _money,
        'positions': positionMaps,
      }, SetOptions(merge: true));
    } catch (e) {
      print("同步雲端失敗: $e");
    }
  }

  void openPosition(Position pos) {
    if (availableBalance < pos.isolatedMargin) {
      print("可用餘額不足，放棄執行開倉");
      return;
    }

    _money -= pos.isolatedMargin;
    _positions.add(pos);
    notifyListeners();
    syncDataToFirebase();
  }

  void closePosition(int index) {
    if (index < 0 || index >= _positions.length) return;

    final targetPos = _positions[index];
    final marketPrice = getPrice(targetPos.symbol);
    final price = marketPrice > 0 ? marketPrice : targetPos.entryPrice;

    final pnl = PnlCalculator.calculatePnL(
      entryPrice: targetPos.entryPrice,
      currentPrice: price,
      quantity: targetPos.quantity,
      side: targetPos.side,
    );

    _money += targetPos.isolatedMargin + pnl;
    _positions.removeAt(index);
    notifyListeners();
    syncDataToFirebase();
  }

  void _checkLiquidation() {
    if (_positions.isEmpty) return;

    for (int i = _positions.length - 1; i >= 0; i--) {
      final pos = _positions[i];
      final marketPrice = getPrice(pos.symbol);
      if (marketPrice <= 0) continue;

      final liqPrice = PnlCalculator.calculateLiquidationPrice(
        entryPrice: pos.entryPrice,
        quantity: pos.quantity,
        side: pos.side,
        isolatedMargin: pos.isolatedMargin,
      );

      bool triggerLiquidation = false;

      if (pos.side == PositionSide.long) {
        // 多單：當市場價格「跌破或等於」強平價時爆倉
        if (marketPrice <= liqPrice) triggerLiquidation = true;
      } else {
        // 空單：當市場價格「漲破或等於」強平價時爆倉
        if (marketPrice >= liqPrice) triggerLiquidation = true;
      }

      // 3. 執行強制平倉
      if (triggerLiquidation) {
        print(
          "🚨【風控系統警告】${pos.symbol} ${pos.side == PositionSide.long ? '多單' : '空單'}已觸及強平價 ${liqPrice.toStringAsFixed(2)}（現價: $marketPrice），執行強制平倉！",
        );
        _executeForceLiquidation(i);
      }
    }
  }

  void _executeForceLiquidation(int index) {
    if (index < 0 || index >= _positions.length) return;

    final pos = _positions[index];
    final marketPrice = getPrice(pos.symbol);
    final price = marketPrice > 0 ? marketPrice : pos.entryPrice;

    // 強平時的盈虧計算（以市場價為準）
    final pnl = PnlCalculator.calculatePnL(
      entryPrice: pos.entryPrice,
      currentPrice: price,
      quantity: pos.quantity,
      side: pos.side,
    );

    // 強平後，扣除剩餘保證金並結算盈虧
    _money += pnl; // 注意：強平不退還保證金，盈虧直接從剩餘資金扣除
    _positions.removeAt(index);
    notifyListeners();
    syncDataToFirebase();
  }
}
