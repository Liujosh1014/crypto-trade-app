import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketManager {
  WebSocketChannel? _channel;

  // 修改：改為廣播價格字典對照表，讓全網同時獲取 BTC、ETH、SOL 的跳動價格
  final StreamController<Map<String, double>> _controller =
      StreamController<Map<String, double>>.broadcast();

  // 系統支援的幣種清單（小寫形式供幣安串流識別）
  final List<String> _symbols = ["btcusdt", "ethusdt", "solusdt"];
  final Map<String, double> _latestPrices = {
    "BTCUSDT": 0.0,
    "ETHUSDT": 0.0,
    "SOLUSDT": 0.0,
  };

  Stream<Map<String, double>> get priceMapStream => _controller.stream;

  void connect() {
    _channel?.sink.close();

    // 建立幣安多重組合串流網址格式
    final String streams = _symbols.map((s) => "$s@ticker").join("/");
    final String url = "wss://stream.binance.com:9443/stream?streams=$streams";

    try {
      print("正在建立多幣種 Combined WebSocket 連線...");
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (message) {
          final json = jsonDecode(message);

          // 組合串流真實的行情數據存放在 'data' 欄位中
          if (json['data'] != null) {
            final data = json['data'];
            final String symbol = data['s']; // 取得大寫幣種名稱，如 "BTCUSDT"
            final double price = double.parse(data['c']); // 最新成交價 'c'

            _latestPrices[symbol] = price;
            _controller.add(_latestPrices); // 廣播最新的全幣種行情快照
          }
        },
        onError: (error) {
          print("WebSocket 錯誤: $error");
          _reconnect();
        },
        onDone: () {
          print("WebSocket 連線關閉");
          _reconnect();
        },
      );
    } catch (e) {
      print("連線初始化失敗: $e");
    }
  }

  void _reconnect() {
    print("嘗試在 5 秒後重連...");
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}
