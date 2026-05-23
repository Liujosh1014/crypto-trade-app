import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 導入 Firebase 核心
import 'view/auth_wrapper.dart'; // 導入剛寫好的分流層
import 'tools/position_tracker.dart';
import 'data/websocket_manager.dart';

final WebSocketManager sharedWs = WebSocketManager();
final PositionTracker positionTracker = PositionTracker(sharedWs);

void main() async {
  // 1. 改為 async
  // 2. 確保 Flutter 元件初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 3. 啟動 Firebase 連線
  await Firebase.initializeApp();

  // 4. 開啟 WebSocket
  sharedWs.connect();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AuthWrapper(), // 5. 改由 AuthWrapper 決定進入哪個畫面
    );
  }
}
