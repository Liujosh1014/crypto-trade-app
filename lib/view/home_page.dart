import 'package:flutter/material.dart';
import 'kline.dart';
import '../tools/position_tracker.dart';
import '../tools/pnl_calculator.dart';
import '../main.dart';
import '../data/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _selectedSymbol = "BTCUSDT";

  // 💡 新增：用來儲存使用者目前輸入的搜尋關鍵字
  String _searchQuery = "";

  final List<String> _availableSymbols = [
    "BTCUSDT",
    "ETHUSDT",
    "SOLUSDT",
    "BNBUSDT",
    "ADAUSDT",
    "XRPUSDT",
    "DOGEUSDT",
    "DOTUSDT",
    "UNIUSDT",
    "LTCUSDT",
    "LINKUSDT",
    "BCHUSDT",
    "MATICUSDT",
    "AVAXUSDT",
  ];
  double _currentLeverage = 20.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      positionTracker.loadFromFirestore();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 💡 核心過濾邏輯：當在行情大廳且有輸入文字時，動態過濾顯示的幣種
    final filteredSymbols = _availableSymbols
        .where(
          (symbol) => symbol.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        elevation: 0,
        title: _currentIndex == 0
            ? const Text(
                "行情大廳",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              )
            : _currentIndex == 1
            ? Text(
                "合約交易 · $_selectedSymbol",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              )
            : const Text(
                "資產錢包",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
            onPressed: () async => await AuthService().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // 頂部錢包餘額顯示欄
          ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF161616),
                  border: Border(
                    bottom: BorderSide(color: Colors.white10, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentIndex == 0
                              ? "投資組合 (Portfolio)"
                              : "可用餘額 (Available)",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${positionTracker.money.toStringAsFixed(2)} USDT",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 💡 關鍵修正：如果是「行情大廳 (Index 0)」，就在頂部塞入 SearchBar
          if (_currentIndex == 0)
            _SearchBar(
              onSymbolChanged: (val) {
                setState(() {
                  _searchQuery = val; // 💡 更新關鍵字，觸發 filteredSymbols 重新計算與 UI 刷新
                });
              },
            ),

          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // 行情大廳分頁
                _HomeDashboardTab(
                  coinList: filteredSymbols, // 💡 傳入過濾後的清單，而非原始清單
                  onSymbolSelect: (symbol) {
                    setState(() {
                      _selectedSymbol = symbol;
                      _currentIndex = 1; // 跳轉到交易頁
                    });
                  },
                ),

                // 交易分頁
                _TradeTab(
                  symbol: _selectedSymbol,
                  currentLeverage: _currentLeverage,
                  onLeverageChanged: (val) =>
                      setState(() => _currentLeverage = val),
                ),

                const _WalletTab(),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF161616),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: '行情'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '交易'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: '錢包'),
        ],
      ),
    );
  }
}

/// 💡 修正：乾淨的行情列表元件，內部不再錯置 SearchBar
class _HomeDashboardTab extends StatelessWidget {
  final List<String> coinList;
  final ValueChanged<String> onSymbolSelect;

  const _HomeDashboardTab({
    required this.coinList,
    required this.onSymbolSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: positionTracker,
      builder: (context, _) {
        if (coinList.isEmpty) {
          return const Center(
            child: Text("找不到相關幣種", style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: coinList.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final symbol = coinList[index];
            final price = positionTracker.getPrice(symbol);

            return InkWell(
              onTap: () => onSymbolSelect(symbol),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              symbol.replaceAll("USDT", "/USDT"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "現貨",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: price > 0
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        price > 0 ? price.toStringAsFixed(2) : "載入中...",
                        style: TextStyle(
                          color: price > 0 ? Colors.greenAccent : Colors.grey,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchBar extends StatefulWidget {
  final ValueChanged<String> onSymbolChanged;

  const _SearchBar({super.key, required this.onSymbolChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  // 💡 引入 Controller 來精準控制輸入框的文字與清空動作
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose(); // 記得銷毀控制器釋放記憶體
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF161616),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller, // 💡 綁定 Controller
              onChanged: widget.onSymbolChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "搜尋幣種 (例如：BTCUSDT)",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),

                // 💡 新增：當輸入框有字時，顯示右側的「清除按鈕」
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.clear(); // 1. 清空輸入框文字
                          });
                          widget.onSymbolChanged(''); // 2. 傳遞空字串給父層，讓列表變回全部幣種
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeTab extends StatefulWidget {
  final String symbol;
  final double currentLeverage;
  final ValueChanged<double> onLeverageChanged;

  const _TradeTab({
    required this.symbol,
    required this.currentLeverage,
    required this.onLeverageChanged,
  });

  @override
  State<_TradeTab> createState() => _TradeTabState();
}

class _TradeTabState extends State<_TradeTab> {
  KlineIntervalOption _selectedInterval = KlineIntervalOption.oneHour;
  final TextEditingController _amountController = TextEditingController(
    text: "100",
  );

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KlineView(symbol: widget.symbol, intervalOption: _selectedInterval),

        Container(
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            border: Border(
              bottom: BorderSide(color: Colors.white10, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: KlineIntervalOption.values.map((option) {
              bool isActive = _selectedInterval == option;
              String labelName = option == KlineIntervalOption.oneMinute
                  ? "1分"
                  : option == KlineIntervalOption.oneHour
                  ? "1小時"
                  : option == KlineIntervalOption.fourHours
                  ? "4小時"
                  : "日線";

              return InkWell(
                onTap: () => setState(() => _selectedInterval = option),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    labelName,
                    style: TextStyle(
                      color: isActive ? Colors.amber : Colors.grey,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: ListenableBuilder(
            listenable: positionTracker,
            builder: (context, _) {
              if (positionTracker.positions.isEmpty) {
                return const Center(
                  child: Text(
                    "目前無任何持倉",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                );
              }
              return ListView.builder(
                itemCount: positionTracker.positions.length,
                itemBuilder: (context, index) => _buildPositionCard(index),
              );
            },
          ),
        ),

        ListenableBuilder(
          listenable: positionTracker,
          builder: (context, _) => _buildActionPanel(),
        ),
      ],
    );
  }

  Widget _buildPositionCard(int index) {
    if (index >= positionTracker.positions.length)
      return const SizedBox.shrink();
    final pos = positionTracker.positions[index];
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
      color: const Color(0xFF1E1E1E),
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
                    color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "開倉價: ${pos.entryPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  "強平價: ${liqPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                ),
                onPressed: () => positionTracker.closePosition(index),
                child: const Text(
                  "市價平倉",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel() {
    final double marketPrice = positionTracker.getPrice(widget.symbol);
    final bool isPriceReady = marketPrice > 0;
    final double inputAmount = double.tryParse(_amountController.text) ?? 0.0;
    final double calculatedQuantity = isPriceReady && inputAmount > 0
        ? (inputAmount * widget.currentLeverage) / marketPrice
        : 0.0;

    void openOrder(PositionSide side) {
      positionTracker.openPosition(
        Position(
          symbol: widget.symbol,
          entryPrice: marketPrice,
          quantity: calculatedQuantity,
          leverage: widget.currentLeverage.toInt(),
          side: side,
          isolatedMargin: inputAmount,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "開倉金額",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "輸入 USDT 金額",
                      suffixText: "USDT",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "槓桿倍數: ${widget.currentLeverage.toInt()}x",
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Slider(
                  value: widget.currentLeverage,
                  min: 1.0,
                  max: 100.0,
                  divisions: 99,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey.shade800,
                  onChanged: widget.onLeverageChanged,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "預估數量: ${calculatedQuantity.toStringAsFixed(4)} ${widget.symbol.replaceAll('USDT', '')}",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  "逐倉保證金: ${inputAmount.toStringAsFixed(2)} USDT",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
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
                  child: Text(
                    isPriceReady ? "開多 (Long)" : "讀取價格中...",
                    style: const TextStyle(color: Colors.white),
                  ),
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
                  child: Text(
                    isPriceReady ? "開空 (Short)" : "讀取價格中...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletTab extends StatelessWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListenableBuilder(
        listenable: positionTracker,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 64,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              const Text(
                "錢包餘額",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                "${positionTracker.money.toStringAsFixed(2)} USDT",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "目前持倉數量: ${positionTracker.positions.length} 筆",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
