import 'package:flutter/material.dart';
import '../tools/pnl_calculator.dart';
import '../tools/position_tracker.dart';
import '../main.dart';
import '../data/auth_service.dart';
import 'kline.dart';

class TradeRoom extends StatefulWidget {
  const TradeRoom({super.key});

  @override
  State<TradeRoom> createState() => _TradeRoomState();
}

class _TradeRoomState extends State<TradeRoom> {
  String _selectedSymbol = "BTCUSDT";
  final List<String> _availableSymbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"];
  KlineIntervalOption _selectedInterval = KlineIntervalOption.oneHour;

  double _currentLeverage = 20.0;
  final TextEditingController _amountController = TextEditingController(
    text: "100",
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      positionTracker.loadUserData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
                  _selectedSymbol = newValue;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                const Text(
                  "K 線週期",
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
          KlineView(symbol: _selectedSymbol, intervalOption: _selectedInterval),

          const Divider(height: 1),

          // 2. 當前持倉列表
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

          // 3. 下單面板
          ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) => _buildActionPanel(),
          ),
        ],
      ),
    );
  }

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
          quantity: pos.quantity,
          side: pos.side,
          isolatedMargin: pos.isolatedMargin,
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
                      "${pos.symbol} ${pos.side == PositionSide.long ? '多單' : '空單'} ${pos.leverage}x",
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

  Widget _buildActionPanel() {
    final double marketPrice = positionTracker.getPrice(_selectedSymbol);
    final bool isPriceReady = marketPrice > 0;
    final double inputAmount = double.tryParse(_amountController.text) ?? 0.0;
    final double calculatedQuantity = isPriceReady && inputAmount > 0
        ? (inputAmount * _currentLeverage) / marketPrice
        : 0.0;

    void openOrder(PositionSide side) {
      positionTracker.openPosition(
        Position(
          symbol: _selectedSymbol,
          entryPrice: marketPrice,
          quantity: calculatedQuantity,
          leverage: _currentLeverage.toInt(),
          side: side,
          isolatedMargin: inputAmount,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "開倉金額",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    color: Colors.amber,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: "輸入 USDT 金額",
                    suffixText: "USDT",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "預估開倉數量: ${calculatedQuantity.toStringAsFixed(4)} ${_selectedSymbol.replaceAll('USDT', '')}",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  "逐倉保證金: ${inputAmount.toStringAsFixed(2)} USDT",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPriceReady && inputAmount > 0
                        ? Colors.green
                        : Colors.grey,
                  ),
                  onPressed: !isPriceReady || inputAmount <= 0
                      ? null
                      : () => openOrder(PositionSide.long),
                  child: Text(isPriceReady ? "開多" : "讀取價格中..."),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPriceReady && inputAmount > 0
                        ? Colors.red
                        : Colors.grey,
                  ),
                  onPressed: !isPriceReady || inputAmount <= 0
                      ? null
                      : () => openOrder(PositionSide.short),
                  child: Text(isPriceReady ? "開空" : "讀取價格中..."),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
