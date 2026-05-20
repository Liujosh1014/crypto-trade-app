import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketManager {
  WebSocketChannel? _channel;
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  // 合約標記價格網址 (Mark Price 是計算強平的依據)
  final String _url = "wss://stream.binance.com:9443/ws/btcusdt@ticker";

  Stream<double> get priceStream => _controller.stream;

  void connect() {
    try {
      print("正在建立 WebSocket 連線...");
      _channel = WebSocketChannel.connect(Uri.parse(_url));

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          print("收到價格更新: $data");
          // 幣安 markPrice 流的價格欄位是 'p'
          if (data['p'] != null) {
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
          _reconnect(); // 被動關閉時重連
        },
      );
    } catch (e) {
      print("連線初始化失敗: $e");
    }
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
