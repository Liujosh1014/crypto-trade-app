import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 新增：導入 Firestore
import 'package:firebase_auth/firebase_auth.dart'; // 新增：導入 FirebaseAuth
import 'pnl_calculator.dart';
import '../data/websocket_manager.dart';

// 定義持倉方向列舉
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

  // 新增：將 Position 物件轉成 Map，方便寫入 Firestore
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'entryPrice': entryPrice,
      'quantity': quantity,
      'leverage': leverage,
      'side': side.name, // 使用 side.name 存成字串 "long" 或 "short"
    };
  }

  // 新增：將 Firestore 讀出來的 Map 還原成 Position 物件
  factory Position.fromMap(Map<String, dynamic> map) {
    return Position(
      symbol: map['symbol'] ?? 'BTCUSDT',
      // 安全轉型：Firestore 數字可能是 int 或 double，先轉成 num 再 toDouble()
      entryPrice: (map['entryPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      leverage: (map['leverage'] as num).toInt(),
      side: map['side'] == 'short' ? PositionSide.short : PositionSide.long,
    );
  }
}

class PositionTracker extends ChangeNotifier {
  final WebSocketManager _ws;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // 新增：Firestore 實例

  double _money = 10000.0;
  double _currentPrice = 0.0;
  final List<Position> _positions = [];

  Stream<double> get priceStream => _ws.priceStream;
  WebSocketManager get ws => _ws;

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

    // 提示：已移除原本一開程式就自動加載 dummy BTC 倉位的舊邏輯
    // 改由使用者登入後，手動呼叫 loadUserData() 來載入真實雲端持倉。
  }

  // ==================== 新增：Firebase 核心同步邏輯 ====================

  // 核心功能 1：從雲端載入使用者資料（餘額與持倉）
  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // 讀取餘額
        _money = (data['money'] as num? ?? 10000.0).toDouble();

        // 讀取並還原持倉列表
        _positions.clear();
        if (data['positions'] != null) {
          final List<dynamic> cloudPositions = data['positions'];
          for (var item in cloudPositions) {
            _positions.add(Position.fromMap(item as Map<String, dynamic>));
          }
        }
      } else {
        // 如果此新用戶在雲端還沒有任何檔案，初始化一筆預設資產
        _money = 10000.0;
        _positions.clear();
        await _firestore.collection('users').doc(user.uid).set({
          'money': _money,
          'positions': [],
        });
      }
      notifyListeners(); // 成功加載後，全面刷新介面
    } catch (e) {
      print("從 Firebase 載入使用者資料發生錯誤: $e");
    }
  }

  // 核心功能 2：將當前最新狀態同步備份至雲端
  Future<void> syncDataToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 將本機持倉列表全部物件轉成 Map 陣列
      final List<Map<String, dynamic>> positionMaps = _positions
          .map((pos) => pos.toMap())
          .toList();

      await _firestore.collection('users').doc(user.uid).set({
        'money': _money,
        'positions': positionMaps,
      }, SetOptions(merge: true)); // 使用 merge 確保不影響該用戶的其他雲端欄位
    } catch (e) {
      print("同步資料至 Firebase 發生錯誤: $e");
    }
  }

  // =================================================================

  // 下單邏輯
  void openPosition(Position pos) {
    _positions.add(pos);
    notifyListeners(); // 通知 UI 重新整理列表

    syncDataToFirebase(); // 新增：下單成功立刻同步雲端
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

  // 平倉邏輯
  void closePosition(int index) {
    if (index < 0 || index >= _positions.length) return;

    final targetPos = _positions[index];
    final price = _currentPrice > 0 ? _currentPrice : targetPos.entryPrice;
    final pnl = getUnrealizedPnl(targetPos, price);

    _money += pnl; // 更新餘額
    _positions.removeAt(index); // 移除倉位

    notifyListeners(); // 觸發 UI 更新

    syncDataToFirebase(); // 新增：平倉成功立刻同步雲端
  }
}
