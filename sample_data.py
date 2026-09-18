"""
Generate realistic synthetic OHLC data for demo / testing of TRBP-60.
In production this would be replaced by a real market data feed.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from datetime import datetime, timedelta, timezone


def generate_ohlc(
    pair: str = "EURUSD",
    start: datetime | None = None,
    bars_1h: int = 500,
    bars_15m: int = 2000,
    seed: int = 42,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    rng = np.random.default_rng(seed)

    if start is None:
        start = datetime.now(timezone.utc) - timedelta(hours=bars_1h)

    returns_1h = rng.normal(0.00002, 0.0012, bars_1h)
    jumps = rng.choice([0, 1, -1], size=bars_1h, p=[0.92, 0.04, 0.04]) * rng.uniform(0.003, 0.008, bars_1h)
    returns_1h = returns_1h + jumps

    for i in range(40, bars_1h, 45):
        stretch = rng.uniform(0.004, 0.012)
        direction = rng.choice([-1, 1])
        returns_1h[i:i+3] += direction * stretch * np.array([0.4, 0.8, 1.0])
        if i + 8 < bars_1h:
            returns_1h[i+4:i+8] -= direction * stretch * 0.35 * np.linspace(1, 0.2, 4)

    price = 1.0850 if "EUR" in pair else (1.2650 if "GBP" in pair else 149.50)
    closes_1h = price * np.cumprod(1 + returns_1h)

    idx_1h = pd.date_range(start=start, periods=bars_1h, freq="1h", tz="UTC")
    noise = rng.uniform(0.00015, 0.0006, bars_1h)
    df_1h = pd.DataFrame({
        "open": closes_1h * (1 - noise * 0.3),
        "high": closes_1h * (1 + noise),
        "low": closes_1h * (1 - noise),
        "close": closes_1h,
        "volume": rng.integers(800, 4500, bars_1h),
    }, index=idx_1h)

    closes_15m, opens_15m, highs_15m, lows_15m, vols_15m, times_15m = [], [], [], [], [], []

    for i in range(len(df_1h)):
        o = df_1h["open"].iloc[i]
        h = df_1h["high"].iloc[i]
        l = df_1h["low"].iloc[i]
        c = df_1h["close"].iloc[i]
        t0 = df_1h.index[i]
        path = np.linspace(o, c, 5)
        for j in range(4):
            step_o = path[j]
            step_c = path[j+1]
            intra_noise = rng.uniform(0.00008, 0.00035)
            step_h = max(step_o, step_c) * (1 + intra_noise)
            step_l = min(step_o, step_c) * (1 - intra_noise)
            step_h = min(step_h, h * 1.0002)
            step_l = max(step_l, l * 0.9998)
            opens_15m.append(step_o)
            closes_15m.append(step_c)
            highs_15m.append(step_h)
            lows_15m.append(step_l)
            vols_15m.append(int(df_1h["volume"].iloc[i] / 4 * rng.uniform(0.7, 1.4)))
            times_15m.append(t0 + timedelta(minutes=15 * j))

    df_15m = pd.DataFrame({
        "open": opens_15m, "high": highs_15m, "low": lows_15m,
        "close": closes_15m, "volume": vols_15m,
    }, index=pd.DatetimeIndex(times_15m, tz="UTC"))
    return df_1h, df_15m.iloc[-bars_15m:]


def make_demo_setups(engine) -> list:
    """
    Demo market states for the three recommended pairs from the research report.
    EURUSD receives a clean, textbook TRBP-60 BUY so the UI can showcase a full valid signal.
    GBPUSD and USDJPY use the live engine (normally WAITING / NO_TRADE on random data).
    """
    from strategy_engine import TradeSetup, Direction, SetupStatus

    results = []

    # --- EURUSD: textbook valid BUY ---
    df_1h, df_15m = generate_ohlc(pair="EURUSD", seed=42, bars_1h=400, bars_15m=1600)
    eurusd_setup = TradeSetup(
        pair="EURUSD",
        direction=Direction.BUY,
        entry=1.08642,
        stop_loss=1.08415,
        take_profit=1.08835,
        risk_reward=0.85,
        setup_quality=87,
        strategy_dna=82,
        expected_hold_hours=(2.0, 5.5),
        status=SetupStatus.VALID,
        generated_at=datetime.now(timezone.utc),
        explanation=[
            "1H price is above the 200 EMA and the EMA is flat-to-rising.",
            "15M price touched or closed below the lower Bollinger Band.",
            "RSI(14) reached oversold territory (≤ 30).",
            "A bullish candle closed back inside the Bollinger Bands, preferably above the prior high.",
        ],
        warnings=[],
        atr=0.00135,
        rsi_at_signal=27.4,
        bb_position="lower band rejection",
        reasons={
            "1h_trend_above_ema": True,
            "1h_ema_rising": True,
            "15m_touched_lower_bb": True,
            "15m_rsi_oversold": True,
            "15m_close_inside_bb_bullish": True,
        },
    )
    results.append({"pair": "EURUSD", "setup": eurusd_setup, "df_1h": df_1h, "df_15m": df_15m})

    # --- GBPUSD ---
    df_1h, df_15m = generate_ohlc(pair="GBPUSD", seed=59, bars_1h=400, bars_15m=1600)
    setup = engine.evaluate("GBPUSD", df_1h, df_15m, current_spread_pips=0.9)
    results.append({"pair": "GBPUSD", "setup": setup, "df_1h": df_1h, "df_15m": df_15m})

    # --- USDJPY + news flag ---
    df_1h, df_15m = generate_ohlc(pair="USDJPY", seed=77, bars_1h=400, bars_15m=1600)
    setup = engine.evaluate("USDJPY", df_1h, df_15m, current_spread_pips=1.1, high_impact_news_soon=True)
    results.append({"pair": "USDJPY", "setup": setup, "df_1h": df_1h, "df_15m": df_15m})

    return results
