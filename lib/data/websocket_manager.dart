import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketManager {
  WebSocketChannel? _channel;
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  // 1. 修改：新增目前訂閱的幣種變數，預設為 BTCUSDT
  String _currentSymbol = "BTCUSDT";

  // 2. 新增：標記是否為「手動切換中」，避免重連邏輯打架
  bool _isManuallySwitching = false;

  Stream<double> get priceStream => _controller.stream;

  void connect() {
    // 安全防護：如果既有連線還在，先將其關閉
    _channel?.sink.close();

    // 3. 修改：根據目前選擇的幣種，動態轉換為小寫並組裝成幣安的 WebSocket 網址
    final String symbolLower = _currentSymbol.toLowerCase();
    final String url = "wss://stream.binance.com:9443/ws/$symbolLower@ticker";

    try {
      print("正在建立 $_currentSymbol WebSocket 連線...");
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);

          // 幣安 ticker 流的當前最新成交價欄位是 'c'
          if (data['c'] != null) {
            double price = double.parse(data['c']);
            _controller.add(price);
          }
        },
        onError: (error) {
          print("WebSocket 錯誤: $error");
          _reconnect(); // 發生錯誤時重連
        },
        onDone: () {
          print("WebSocket 連線關閉");
          // 4. 修改：只有在「非手動切換」的被動斷線情況下，才觸發 5 秒延遲重連
          if (!_isManuallySwitching) {
            _reconnect();
          }
        },
      );
    } catch (e) {
      print("連線初始化失敗: $e");
    }
  }

  // 5. 新增：提供給 UI 呼叫的切換幣種核心方法
  void switchSymbol(String newSymbol) {
    if (_currentSymbol == newSymbol) return; // 相同幣種就不重複切換

    print("🔄 正在從 $_currentSymbol 切換至 $newSymbol...");

    _isManuallySwitching = true;
    _currentSymbol = newSymbol;

    // 掐斷當前連線（這會觸發 onDone，但因為旗標已開，不會進入 5 秒延遲重連）
    _channel?.sink.close();

    _isManuallySwitching = false;

    // 立刻點火連接新幣種的 Stream！
    connect();
  }

  void _reconnect() {
    print("嘗試在 5 秒後重連...");
    Future.delayed(Duration(seconds: 5), () => connect());
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}
