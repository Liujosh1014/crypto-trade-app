import 'dart:convert';

import 'package:flexi_formatter/date_time.dart' show TimeUnit;
import 'package:flexi_kline/flexi_kline.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import 'kline_configuration.dart';

enum KlineIntervalOption {
  oneMinute(
    label: '1m',
    apiValue: '1m',
    interval: FlexiTimeInterval(1, TimeUnit.minute),
  ),
  oneHour(
    label: '1h',
    apiValue: '1h',
    interval: FlexiTimeInterval(1, TimeUnit.hour),
  ),
  fourHours(
    label: '4h',
    apiValue: '4h',
    interval: FlexiTimeInterval(4, TimeUnit.hour),
  ),
  oneDay(
    label: '1d',
    apiValue: '1d',
    interval: FlexiTimeInterval(1, TimeUnit.day),
  );

  const KlineIntervalOption({
    required this.label,
    required this.apiValue,
    required this.interval,
  });

  final String label;
  final String apiValue;
  final FlexiTimeInterval interval;
}

class KlineView extends StatefulWidget {
  final String symbol;
  final KlineIntervalOption intervalOption;

  const KlineView({
    super.key,
    required this.symbol,
    required this.intervalOption,
  });

  @override
  State<KlineView> createState() => _KlineViewState();
}

class _KlineViewState extends State<KlineView> {
  late final FlexiKlineController _klineController;
  late KlineSpec _currentSpec;
  bool _isChartLoading = true;
  bool _hasNetworkError = false;
  CandleModel? _latestCandle;

  @override
  void initState() {
    super.initState();
    _currentSpec = _buildSpec();
    _klineController = FlexiKlineController(
      configuration: MyKlineConfiguration(),
      klineDataCacheCapacity: 5,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistoryKlines();
    });

    positionTracker.addListener(_onPriceSnapshotUpdate);
  }

  @override
  void didUpdateWidget(covariant KlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.intervalOption != widget.intervalOption) {
      debugPrint(
        "Kline updated: ${oldWidget.symbol}/${oldWidget.intervalOption.label} -> "
        "${widget.symbol}/${widget.intervalOption.label}",
      );
      setState(() {
        _currentSpec = _buildSpec();
        _latestCandle = null;
      });
      _fetchHistoryKlines();
    }
  }

  @override
  void dispose() {
    positionTracker.removeListener(_onPriceSnapshotUpdate);
    _klineController.dispose();
    super.dispose();
  }

  void _onPriceSnapshotUpdate() {
    final currentPrice = positionTracker.getPrice(widget.symbol);
    if (currentPrice <= 0 || _isChartLoading || _hasNetworkError) {
      return;
    }

    final latestCandle = _latestCandle;
    if (latestCandle == null) {
      return;
    }

    final currentBucket = _alignTimestamp(DateTime.now().millisecondsSinceEpoch);
    final latestTimestamp = (latestCandle.timestamp as num).toInt();
    final latestBucket = _alignTimestamp(latestTimestamp);
    final latestHigh = (latestCandle.high as num).toDouble();
    final latestLow = (latestCandle.low as num).toDouble();

    final liveCandle = currentBucket > latestBucket
        ? CandleModel(
            timestamp: currentBucket,
            open: latestCandle.close,
            high: currentPrice,
            low: currentPrice,
            close: currentPrice,
            volume: 0,
          )
        : CandleModel(
            timestamp: latestTimestamp,
            open: latestCandle.open,
            high: currentPrice > latestHigh ? currentPrice : latestHigh,
            low: currentPrice < latestLow ? currentPrice : latestLow,
            close: currentPrice,
            volume: latestCandle.volume,
          );

    _latestCandle = liveCandle;
    _klineController.updateKlineData(_currentSpec, [liveCandle]);
  }

  KlineSpec _buildSpec() {
    return KlineSpec(
      symbol: widget.symbol,
      interval: widget.intervalOption.interval,
    );
  }

  Duration get _intervalDuration {
    switch (widget.intervalOption) {
      case KlineIntervalOption.oneMinute:
        return const Duration(minutes: 1);
      case KlineIntervalOption.oneHour:
        return const Duration(hours: 1);
      case KlineIntervalOption.fourHours:
        return const Duration(hours: 4);
      case KlineIntervalOption.oneDay:
        return const Duration(days: 1);
    }
  }

  int _alignTimestamp(int timestamp) {
    final durationMs = _intervalDuration.inMilliseconds;
    return timestamp - (timestamp % durationMs);
  }

  Future<void> _fetchHistoryKlines() async {
    if (!mounted) return;
    setState(() {
      _isChartLoading = true;
      _hasNetworkError = false;
      _latestCandle = null;
    });

    try {
      debugPrint(
        "Fetching klines for ${_currentSpec.symbol}/${widget.intervalOption.label}...",
      );
      final response = await http.get(
        Uri.parse(
          "https://api.binance.com/api/v3/klines?"
          "symbol=${widget.symbol}&interval=${widget.intervalOption.apiValue}&limit=100",
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final historyList = <CandleModel>[];

        for (final item in jsonList) {
          historyList.add(
            CandleModel(
              timestamp: item[0],
              open: double.parse(item[1]),
              high: double.parse(item[2]),
              low: double.parse(item[3]),
              close: double.parse(item[4]),
              volume: double.parse(item[5]),
            ),
          );
        }

        if (historyList.isNotEmpty) {
          _latestCandle = historyList.last;
        }

        debugPrint(
          "Loaded ${historyList.length} candles for ${_currentSpec.symbol}",
        );
        _klineController.switchKlineData(_currentSpec, useCacheFirst: false);
        _klineController.updateKlineData(_currentSpec, historyList);
      } else {
        debugPrint("Binance kline API failed: ${response.statusCode}");
        setState(() => _hasNetworkError = true);
      }
    } catch (e) {
      debugPrint("Failed to fetch klines: $e");
      setState(() => _hasNetworkError = true);
    } finally {
      if (mounted) {
        setState(() => _isChartLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      width: double.infinity,
      color: const Color(0xFF121212),
      child: Stack(
        children: [
          FlexiKlineWidget(
            controller: _klineController,
            autoAdaptLayout: true,
          ),
          if (_hasNetworkError)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.redAccent, size: 48),
                    SizedBox(height: 10),
                    Text(
                      "K線資料載入失敗",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      "請稍後重試，或檢查網路與 Binance API 是否可用",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_isChartLoading && !_hasNetworkError)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
        ],
      ),
    );
  }
}
