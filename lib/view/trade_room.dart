import 'package:flutter/material.dart';
import '../tools/pnl_calculator.dart';
import '../tools/position_tracker.dart';
import '../main.dart'; // 確保獲取全域 positionTracker

class TradeRoom extends StatefulWidget {
  const TradeRoom({super.key});

  @override
  State<TradeRoom> createState() => _TradeRoomState();
}

class _TradeRoomState extends State<TradeRoom> {
  // 直接拿全域的 priceStream
  late final Stream<double> priceStream = positionTracker.priceStream;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BTCUSDT 永續合約模擬"),
        actions: [
          // 餘額局部更新
          ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    "餘額: ${positionTracker.money.toStringAsFixed(2)} USDT",
                    style: const TextStyle(color: Colors.amber, fontSize: 16),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 即時價格看板：直連 StreamBuilder，保證價格絕對瘋狂更新！
          StreamBuilder<double>(
            stream: priceStream,
            builder: (context, snapshot) {
              final price = snapshot.data ?? positionTracker.currentPrice;
              return Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("BTCUSDT 標記價格", style: TextStyle(fontSize: 16)),
                    Text(
                      "\$${price.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: price >= positionTracker.currentPrice
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          // 2. 當前持倉列表：只有持倉陣列改變時才重繪列表框架
          Expanded(
            child: ListenableBuilder(
              listenable: positionTracker,
              builder: (context, _) {
                if (positionTracker.positions.isEmpty) {
                  return const Center(
                    child: Text("目前無持倉", style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  itemCount: positionTracker.positions.length,
                  itemBuilder: (context, index) => _buildPositionCard(index),
                );
              },
            ),
          ),

          // 3. 下單按鈕區：丟進 ListenableBuilder，只要 Tracker 價格快照更新了，按鈕立刻變色解鎖
          ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) => _buildActionPanel(),
          ),
        ],
      ),
    );
  }

  // 倉位卡片：內部獨立監聽價格，跳動互不影響
  Widget _buildPositionCard(int index) {
    // 防呆：有可能在重繪瞬間 index 已經沒了
    if (index >= positionTracker.positions.length)
      return const SizedBox.shrink();
    final pos = positionTracker.positions[index];

    return StreamBuilder<double>(
      stream: priceStream,
      builder: (context, snapshot) {
        final currentPrice = snapshot.data ?? positionTracker.currentPrice;
        final validPrice = currentPrice > 0 ? currentPrice : pos.entryPrice;

        final pnl = PnlCalculator.calculatePnL(
          entryPrice: pos.entryPrice,
          currentPrice: validPrice,
          quantity: pos.quantity,
          side: pos.side,
        );

        final liqPrice = PnlCalculator.calculateLiquidationPrice(
          entryPrice: pos.entryPrice,
          leverage: pos.leverage,
          side: pos.side,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${pos.side == PositionSide.long ? '做多' : '做空'} ${pos.leverage}x",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: pos.side == PositionSide.long
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    Text(
                      "盈虧: ${pnl.toStringAsFixed(2)} USDT",
                      style: TextStyle(
                        color: pnl >= 0 ? Colors.green : Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("開倉價: ${pos.entryPrice.toStringAsFixed(2)}"),
                    Text(
                      "強平價: ${liqPrice.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                    ),
                    onPressed: () => positionTracker.closePosition(index),
                    child: const Text(
                      "平倉",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 下單面板
  Widget _buildActionPanel() {
    // 直接動態判定 Tracker 的價格是不是大於 0
    final bool isPriceReady = positionTracker.currentPrice > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey.shade900),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPriceReady ? Colors.green : Colors.grey,
              ),
              onPressed: !isPriceReady
                  ? null
                  : () {
                      positionTracker.openPosition(
                        Position(
                          symbol: "BTCUSDT",
                          entryPrice: positionTracker.currentPrice,
                          quantity: 0.1,
                          leverage: 20,
                          side: PositionSide.long,
                        ),
                      );
                    },
              child: Text(
                isPriceReady ? "市價買入 / 做多" : "等待即時價格...",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPriceReady ? Colors.red : Colors.grey,
              ),
              onPressed: !isPriceReady
                  ? null
                  : () {
                      positionTracker.openPosition(
                        Position(
                          symbol: "BTCUSDT",
                          entryPrice: positionTracker.currentPrice,
                          quantity: 0.1,
                          leverage: 20,
                          side: PositionSide.short,
                        ),
                      );
                    },
              child: Text(
                isPriceReady ? "市價賣出 / 做空" : "等待即時價格...",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
