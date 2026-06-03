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
  int _currentIndex = 0; // 預設停在第一個「首頁大廳」

  // 全域連動的標的狀態
  String _selectedSymbol = "BTCUSDT";
  final List<String> _availableSymbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"];
  double _currentLeverage = 20.0; // 槓桿倍數狀態

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ==================== 1. 動態 AppBar（依分頁展示不同標題） ====================
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        elevation: 0,
        title: _currentIndex == 0
            ? const Text(
                "市場行情",
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
                "資產帳戶",
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

      // ==================== 2. 使用 IndexedStack 鎖定分頁狀態 ====================
      body: Column(
        children: [
          // 🔥 核心重構點：將原本 8 像素的空 Container 改造成高質感動態資產看板
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
                    // 左側：圖標與文字
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
                              ? "總資產估值 (Portfolio)"
                              : "可用餘額 (Available)",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // 右側：實時跟隨 WebSocket 與下單盈虧動態跳動的資產數字
                    Text(
                      "${positionTracker.money.toStringAsFixed(2)} USDT",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace', // 等寬字體，防止數字跳動時文字抖動
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 🔥 核心重構點：必須使用 Expanded 包裹 IndexedStack，
          // 讓分頁能夠完美、安全地吃掉除去頂部資產看板後的所有剩餘螢幕高度！
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // 分頁 0：純淨自選首頁 (只顯示幣種與即時價)
                _HomeDashboardTab(
                  coinList: _availableSymbols,
                  onSymbolSelect: (symbol) {
                    setState(() {
                      _selectedSymbol = symbol; // 變更全域標的
                      _currentIndex = 1; // 自動轉場滑入「合約交易」分頁
                    });
                  },
                ),

                // 分頁 1：升級版專業合約交易室 (內含 K 線與週期切換)
                _TradeTab(
                  symbol: _selectedSymbol,
                  currentLeverage: _currentLeverage,
                  onLeverageChanged: (val) =>
                      setState(() => _currentLeverage = val),
                ),

                // 分頁 2：個人帳戶
                const _WalletTab(),
              ],
            ),
          ),
        ],
      ),

      // ==================== 3. 質感暗色底部導航列 ====================
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
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: '市場行情'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '合約交易'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: '資產帳戶'),
        ],
      ),
    );
  }
}

// ============================================================================
// 📊 分頁 0：純淨首頁大廳 (Watchlist Dashboard) - 只顯示幣種與當前價格
// ============================================================================
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
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: coinList.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final symbol = coinList[index];
            final price = positionTracker.getPrice(symbol);

            return InkWell(
              onTap: () => onSymbolSelect(symbol), // 點擊項目觸發場景跳轉
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 左側：幣種名稱與永續合約標籤
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
                                "永續",
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
                    // 右側：純淨跳動價格字卡
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
                        price > 0 ? price.toStringAsFixed(2) : "連線中...",
                        style: TextStyle(
                          color: price > 0 ? Colors.greenAccent : Colors.grey,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace', // 等寬字體防抖動
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

// ============================================================================
// ⚡ 分頁 1：升級版合約交易室 (包含 K 線圖與獨立週期切換)
// ============================================================================
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
  // 讓交易室自主控制看盤週期，預設為 1h（1小時線）
  KlineIntervalOption _selectedInterval = KlineIntervalOption.oneHour;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. 🔥 K 線看盤組件完美移居至此！並與選中的動態週期綁定
        KlineView(symbol: widget.symbol, intervalOption: _selectedInterval),

        // 2. 高級內建時間週期切換橫列
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
                  ? "分時"
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

        // 3. 持倉合約卡片動態列表
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

        // 4. 固定的下單操作控制面板
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
      leverage: pos.leverage,
      side: pos.side,
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
                  "開倉均價: ${pos.entryPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  "強平價格: ${liqPrice.toStringAsFixed(2)}",
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
                  "市價全平",
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                              symbol: widget.symbol,
                              entryPrice: marketPrice,
                              quantity: 0.1,
                              leverage: widget.currentLeverage.toInt(),
                              side: PositionSide.long,
                            ),
                          );
                        },
                  child: Text(
                    isPriceReady ? "市價做多 (Long)" : "連線中...",
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
                              symbol: widget.symbol,
                              entryPrice: marketPrice,
                              quantity: 0.1,
                              leverage: widget.currentLeverage.toInt(),
                              side: PositionSide.short,
                            ),
                          );
                        },
                  child: Text(
                    isPriceReady ? "市價做空 (Short)" : "連線中...",
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

// ============================================================================
// 💰 分頁 2：個人資產賬戶中心 (Wallet Tab)
// ============================================================================
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
                "合約賬戶淨資產估值",
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
                  "目前動態監聽持倉數: ${positionTracker.positions.length} 筆",
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
