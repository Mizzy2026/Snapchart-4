# SnapChart Flutter Mobile Shell

## Build the APK

```bash
cd mobile
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

For a split APK / App Bundle:
```bash
flutter build appbundle --release
```

## Architecture

```
Flutter App (UI + local state)
    │  HTTP
    ▼
Python Backend (TRBP-60 engine + API)   ← already running on :5000
    │
    ├── Market data provider (see below)
    └── Optional: MT5 execution bridge (MetaAPI / custom EA)
```

## Real Market Data (instead of synthetic)

TradingView does **not** offer a public REST API for raw OHLC that you can legally use for automated strategy engines at scale. Recommended production options:

| Provider        | Notes                                      |
|-----------------|--------------------------------------------|
| Twelve Data     | Clean FX candles, generous free tier       |
| Polygon.io      | High quality, paid                         |
| OANDA / broker  | Direct from your broker                    |
| MetaTrader via bridge | Pull from the same account you trade  |

**TradingView charts** can still be embedded for the visual chart screen using their widget (iframe / WebView). Use them for display only; keep the strategy engine on a proper data feed.

To wire a real feed later:
1. Add a `MarketDataService` that fetches OHLC for EURUSD, GBPUSD, USDJPY.
2. Pass the DataFrames into `TRBP60Engine.evaluate()` on a schedule (e.g. every 1–5 min).
3. Push new VALID setups to connected Flutter clients via FCM.

## Push Notifications

- Local notifications are already wired (`flutter_local_notifications`).
- For production push: create a Firebase project, add `google-services.json`, uncomment the FCM code in `notification_service.dart`, and send the device token to your backend.

## MT5 Auto-Trading (Phase 3)

The Control Centre UI is complete. Real execution requires one of:

1. **MetaAPI** (or similar) – cloud bridge, token-based, no password in the app.
2. Custom Expert Advisor on the user’s MT5 that listens to a secure WebSocket you control.
3. Broker native API if available.

Never store raw MT5 passwords in the mobile app or your main backend database.

## Screens included

- Dashboard / Market Scan
- Signals list
- Setup detail (Why This Trade, position size)
- Performance analytics + AI insights
- AI Journal
- Auto-Trading Control Centre (risk limits, filters, MT5 connect, management rules)

## Disclaimer

Educational software. Not financial advice. Validate the strategy on your own broker data before risking capital.
