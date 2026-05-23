import 'package:flutter/material.dart';
import '../data/auth_service.dart';

class LoginRoom extends StatefulWidget {
  const LoginRoom({super.key});

  @override
  State<LoginRoom> createState() => _LoginRoomState();
}

class _LoginRoomState extends State<LoginRoom> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleSignIn() async {
    setState(() => _isLoading = true);

    // 執行非同步 Google 登入
    final userCredential = await _authService.signInWithGoogle();

    // 🔥 核心修正點：如果登入成功，畫面已經跳轉，此 Widget 會被卸載 (unmounted)
    // 此時必須直接中斷，絕對不能再呼叫下面的 setState() 與 context 操作！
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (userCredential != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("歡迎回來！交易員：${userCredential.user?.displayName ?? '未知'}"),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("登入失敗或已取消，請重試。")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.currency_exchange, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "Crypto Simulator",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "加密貨幣永續合約模擬平台",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 60),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.amber)
                : SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _handleSignIn,
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 30,
                        color: Colors.red,
                      ),
                      label: const Text(
                        "使用 Google 帳號登入",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
