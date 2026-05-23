import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 提供即時的登入狀態 Stream
  Stream<User?> get userStream => _auth.authStateChanges();

  // 取得當前已登入的用戶資訊
  User? get currentUser => _auth.currentUser;

  // 執行 Google 登入
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. 觸發手機端的 Google 帳號選擇視窗
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // 用戶中途取消

      // 2. 取得該 Google 帳號的驗證詳細憑證
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. 把憑證打包成 Firebase 認可的格式
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. 正式登入 Firebase 後台
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Google 登入失敗詳細原因: $e");
      return null;
    }
  }

  // 登出系統
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("登出失敗: $e");
    }
  }
}
