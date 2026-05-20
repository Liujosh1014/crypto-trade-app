import 'package:flutter/material.dart';
import 'view/trade_room.dart';
import 'tools/position_tracker.dart';
import 'data/websocket_manager.dart';

// 全域實例
final WebSocketManager sharedWs = WebSocketManager();
final PositionTracker positionTracker = PositionTracker(sharedWs);

void main() {
  // 1. 確保 Flutter 核心元件完成初始化（涉及非同步連線時必加）
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 灌入靈魂！在這裡立刻呼叫連線，讓 WebSocket 開始跑
  sharedWs.connect();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(), // 交易軟體通常用深色模式比較專業
      home: const TradeRoom(),
    );
  }
}
