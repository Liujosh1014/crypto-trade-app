import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:local_auth/local_auth.dart';
import 'view/home_page.dart'; // 引入你的主畫面
import 'view/auth_wrapper.dart'; // 引入分流層，確保驗證成功後才進主頁

class SplashAnimateScreen extends StatefulWidget {
  const SplashAnimateScreen({Key? key}) : super(key: key);

  @override
  State<SplashAnimateScreen> createState() => _SplashAnimateScreenState();
}

class _SplashAnimateScreenState extends State<SplashAnimateScreen> {
  late VideoPlayerController _videoController;
  final LocalAuthentication _auth = LocalAuthentication();
  bool _hasTriggeredAuth = false; // 防止重複觸發辨識

  @override
  void initState() {
    super.initState();

    // 1. 初始化影片（請確保路徑與 pubspec.yaml 一致）
    _videoController =
        VideoPlayerController.asset('assets/splash_animation.mp4')
          ..initialize().then((_) {
            setState(() {});
            _videoController.play();
          });

    // 2. 監聽影片進度
    _videoController.addListener(() {
      final currentPosition = _videoController.value.position;

      // 當影片播到 7.5 秒（Logo與指紋出現時），且尚未觸發過辨識
      if (currentPosition >= const Duration(milliseconds: 10000) &&
          !_hasTriggeredAuth) {
        _hasTriggeredAuth = true;
        _videoController.pause(); // 暫停影片，停留在指紋畫面
        _authenticateUsers(); // 喚醒手機生物辨識
      }
    });
  }

  // 3. 呼叫原生生物辨識
  Future<void> _authenticateUsers() async {
    try {
      // 檢查裝置是否支援生物辨識
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        // 如果手機沒設密碼或不支援，直接進主頁
        _navigateToHome();
        return;
      }

      // 彈出系統辨識視窗
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: '請驗證指紋或面部以解鎖 FuturX 交易所',
        options: const AuthenticationOptions(
          biometricOnly: true, // 只允許生物辨識，不允許用 Pin 碼
          stickyAuth: true, // 當 App 切到背景再回來時保持驗證狀態
        ),
      );

      if (didAuthenticate) {
        // 驗證成功，無縫跳轉
        _navigateToHome();
      } else {
        // 使用者取消或失敗，允許他們點擊畫面重試
        _showRetrySnackBar();
      }
    } catch (e) {
      // 發生錯誤時的降級處理（直接進主頁，避免卡死）
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    // 動畫與指紋驗證成功後，無縫交棒給 AuthWrapper
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  void _showRetrySnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('驗證失敗，請點擊螢幕重試'),
        action: SnackBarAction(label: '重試', onPressed: _authenticateUsers),
      ),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 背景全黑，完美融合影片
      body: GestureDetector(
        // 如果失敗了，點擊螢幕可以重新觸發指紋辨識
        onTap: () {
          if (_videoController.value.position >=
              const Duration(milliseconds: 7500)) {
            _authenticateUsers();
          }
        },
        child: Stack(
          children: [
            if (_videoController.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover, // 裁切填滿螢幕
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}
