import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 導入 Firebase 核心
import 'view/auth_wrapper.dart'; // 導入分流層
import 'tools/position_tracker.dart';
import 'data/websocket_manager.dart';
import 'splash_animate.dart'; // 1. 引入你的進場動畫畫面

final WebSocketManager sharedWs = WebSocketManager();
final PositionTracker positionTracker = PositionTracker(sharedWs);

void main() async {
  // 確保 Flutter 元件初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 啟動 Firebase 連線
  await Firebase.initializeApp();

  // 開啟 WebSocket
  sharedWs.connect();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "FutureXCrypto",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // 2. 將 home 改為動畫畫面，讓 App 一打開先看影片
      home: const SplashAnimateScreen(),
    );
  }
}
