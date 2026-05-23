import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_service.dart';
import 'trade_room.dart';
import 'login_room.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, snapshot) {
        // 1. 還在與伺服器確認狀態時，顯示加載圈
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        // 2. 確定有用戶資料 -> 前往交易室
        if (snapshot.hasData && snapshot.data != null) {
          return const TradeRoom();
        }

        // 3. 沒資料或未登入 -> 前往登入頁面
        return const LoginRoom();
      },
    );
  }
}
