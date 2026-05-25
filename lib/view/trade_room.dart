import 'package:flutter/material.dart';
import '../tools/pnl_calculator.dart';
import '../tools/position_tracker.dart';
import '../main.dart';
import '../data/auth_service.dart';
import 'kline.dart'; // 🔥 新增：導入剛剛寫好的獨立 K 線圖元件

class TradeRoom extends StatefulWidget {
  const TradeRoom({super.key});

  @override
  State<TradeRoom> createState() => _TradeRoomState();
}

class _TradeRoomState extends State<TradeRoom> {
  // 當前看盤與下單的幣種狀態，預設為 BTCUSDT
  String _selectedSymbol = "BTCUSDT";
  final List<String> _availableSymbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"];
  KlineIntervalOption _selectedInterval = KlineIntervalOption.oneHour;

  // 當前選擇的槓桿倍數，預設為 20x
  double _currentLeverage = 20.0;

  @override
  void initState() {
    super.initState();
    // 畫面首次渲染後向雲端加載真實使用者數據
    WidgetsBinding.instance.addPostFrameCallback((_) {
      positionTracker.loadUserData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedSymbol,
            dropdownColor: Colors.grey.shade900,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            items: _availableSymbols.map((String symbol) {
              return DropdownMenuItem<String>(
                value: symbol,
                child: Text(symbol),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedSymbol = newValue; // 這裡改變狀態，會引導下面的 KlineView 自動更新
                });
              }
            },
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) {
              return Center(
                child: Text(
                  "餘額: ${positionTracker.money.toStringAsFixed(2)} USDT",
                  style: const TextStyle(color: Colors.amber, fontSize: 16),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () async => await AuthService().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. 🔥 重構點：直接調用剛寫好的獨立 K 線圖 Widget，把目前選擇的幣種傳進去
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                const Text(
                  "K線週期",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<KlineIntervalOption>(
                      showSelectedIcon: false,
                      segments: KlineIntervalOption.values
                          .map(
                            (option) => ButtonSegment<KlineIntervalOption>(
                              value: option,
                              label: Text(option.label),
                            ),
                          )
                          .toList(),
                      selected: {_selectedInterval},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedInterval = selection.first;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          KlineView(
            symbol: _selectedSymbol,
            intervalOption: _selectedInterval,
          ),

          const Divider(height: 1),

          // 2. 當前持倉合約列表
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

          // 3. 槓桿滑桿與下單控制面板
          ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) => _buildActionPanel(),
          ),
        ],
      ),
    );
  }

  // 持倉卡片組件
  Widget _buildPositionCard(int index) {
    if (index >= positionTracker.positions.length) {
      return const SizedBox.shrink();
    }
    final pos = positionTracker.positions[index];

    return ListenableBuilder(
      listenable: positionTracker,
      builder: (context, _) {
        final currentPrice = positionTracker.getPrice(pos.symbol);
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${pos.symbol} · ${pos.side == PositionSide.long ? '做多' : '做空'} ${pos.leverage}x",
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                    ),
                    onPressed: () => positionTracker.closePosition(index),
                    child: const Text(
                      "市價平倉",
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

  // 下單面板組件
  Widget _buildActionPanel() {
    final double marketPrice = positionTracker.getPrice(_selectedSymbol);
    final bool isPriceReady = marketPrice > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 槓桿 Slider 滑桿控制
          Row(
            children: [
              Text(
                "槓桿倍數: ${_currentLeverage.toInt()}x",
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _currentLeverage,
                  min: 1.0,
                  max: 100.0,
                  divisions: 99,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey.shade700,
                  label: "${_currentLeverage.toInt()}x",
                  onChanged: (value) {
                    setState(() {
                      _currentLeverage = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
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
                              symbol: _selectedSymbol,
                              entryPrice: marketPrice,
                              quantity: 0.1,
                              leverage: _currentLeverage.toInt(),
                              side: PositionSide.long,
                            ),
                          );
                        },
                  child: Text(isPriceReady ? "市價做多" : "連線中..."),
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
                              symbol: _selectedSymbol,
                              entryPrice: marketPrice,
                              quantity: 0.1,
                              leverage: _currentLeverage.toInt(),
                              side: PositionSide.short,
                            ),
                          );
                        },
                  child: Text(isPriceReady ? "市價做空" : "連線中..."),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
