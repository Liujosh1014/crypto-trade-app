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

  Position({
    required this.symbol,
    required this.entryPrice,
    required this.quantity,
    required this.leverage,
    required this.side,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'entryPrice': entryPrice,
      'quantity': quantity,
      'leverage': leverage,
      'side': side.name,
    };
  }

  factory Position.fromMap(Map<String, dynamic> map) {
    return Position(
      symbol: map['symbol'] ?? 'BTCUSDT',
      entryPrice: (map['entryPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      leverage: (map['leverage'] as num).toInt(),
      side: map['side'] == 'short' ? PositionSide.short : PositionSide.long,
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

  // 安全獲取特定代幣最新價
  double getPrice(String symbol) => _prices[symbol] ?? 0.0;

  PositionTracker(this._ws) {
    // 訂閱多幣種字典，隨時通知 UI 刷新
    _ws.priceMapStream.listen((updatedPrices) {
      _prices.addAll(updatedPrices);
      notifyListeners();
    });
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

    _money += pnl;
    _positions.removeAt(index);
    notifyListeners();
    syncDataToFirebase();
  }
}
