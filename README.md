# SnapChart — Spot the Setup. Seize the Trade.

**TRBP-60 Strategy Intelligence Platform**

Dark luxury + glassmorphism market intelligence app powered by the research-backed Trend-Filtered RSI/Bollinger Pullback (TRBP-60) strategy.

---

## What’s included

| Folder | Purpose |
|--------|---------|
| `backend/` | Python TRBP-60 strategy engine + Flask API |
| `templates/` + `static/` | Web dashboard (dark glass UI) |
| `mobile/` | Flutter mobile shell (Android APK / iOS ready) |

---

## Quick start — Web dashboard

```bash
cd snapchart
pip install flask pandas numpy
PYTHONPATH=backend python backend/app.py
```

Open **http://localhost:5000**

---

## Quick start — Flutter mobile

```bash
cd mobile
flutter pub get
flutter run
# or build APK:
flutter build apk --release
```

The APK will be at:
`mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## Strategy (TRBP-60)

- **Bias**: 1H 200 EMA (price above + rising for longs)
- **Entry**: 15M Bollinger Band (20, 2.0) + RSI(14) exhaustion
- **Confirmation**: Candle closes back inside the bands
- **Stop**: 1.0–1.5 × ATR
- **Target**: ~0.8–1.0R (designed for high hit-rate)
- **Pairs**: EUR/USD first, then GBP/USD, USD/JPY

Full rules are implemented in `backend/strategy_engine.py`.

---

## Features

- Market scan with setup quality score + Strategy DNA
- “Why This Trade?” explanations
- Position size calculator
- Auto-Trading Control Centre (MT5 bridge ready)
- AI Journal + performance analytics
- Push notification hooks (FCM ready)
- Dark luxury glassmorphism UI

---

## Project structure

```
snapchart/
├── backend/
│   ├── strategy_engine.py   # Core TRBP-60 rules
│   ├── sample_data.py       # Demo OHLC + setups
│   └── app.py               # Flask API
├── templates/dashboard.html
├── static/css/ + static/js/
├── mobile/                  # Flutter app
│   ├── lib/
│   ├── pubspec.yaml
│   └── README_MOBILE.md
├── .gitignore
└── README.md
```

---

## Disclaimer

Educational research tool only. **Not financial advice.**  
Validate the strategy on your own broker data before risking real capital.  
Past performance does not guarantee future results. Trading involves substantial risk of loss.
