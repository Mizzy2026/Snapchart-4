"""
SnapChart Strategy Engine — TRBP-60
Trend-Filtered RSI/Bollinger Pullback

Implements the research-backed high-selectivity mean-reversion framework
from the Forex Strategy Research Report.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, List, Dict, Any
import math

import numpy as np
import pandas as pd


class Direction(str, Enum):
    BUY = "BUY"
    SELL = "SELL"
    NONE = "NONE"


class SetupStatus(str, Enum):
    VALID = "VALID"
    WAITING = "WAITING"
    NO_TRADE = "NO_TRADE"
    INVALIDATED = "INVALIDATED"
    EXPIRED = "EXPIRED"


@dataclass
class TradeSetup:
    pair: str
    direction: Direction
    entry: float
    stop_loss: float
    take_profit: float
    risk_reward: float
    setup_quality: int  # 0-100
    strategy_dna: int   # 0-100
    expected_hold_hours: tuple[float, float]
    timeframe_bias: str = "1H"
    timeframe_exec: str = "15M"
    status: SetupStatus = SetupStatus.VALID
    generated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    explanation: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    atr: float = 0.0
    rsi_at_signal: float = 0.0
    bb_position: str = ""
    reasons: Dict[str, bool] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "pair": self.pair,
            "direction": self.direction.value,
            "entry": round(self.entry, 5),
            "stop_loss": round(self.stop_loss, 5),
            "take_profit": round(self.take_profit, 5),
            "risk_reward": round(self.risk_reward, 2),
            "setup_quality": self.setup_quality,
            "strategy_dna": self.strategy_dna,
            "expected_hold_hours": self.expected_hold_hours,
            "status": self.status.value,
            "generated_at": self.generated_at.isoformat(),
            "explanation": self.explanation,
            "warnings": self.warnings,
            "atr": round(self.atr, 5),
            "rsi": round(self.rsi_at_signal, 1),
            "bb_position": self.bb_position,
            "reasons": self.reasons,
        }


def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def sma(series: pd.Series, period: int) -> pd.Series:
    return series.rolling(window=period).mean()


def rsi(series: pd.Series, period: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def bollinger_bands(series: pd.Series, period: int = 20, std_dev: float = 2.0):
    mid = sma(series, period)
    std = series.rolling(window=period).std()
    upper = mid + std_dev * std
    lower = mid - std_dev * std
    return upper, mid, lower


def atr(high: pd.Series, low: pd.Series, close: pd.Series, period: int = 14) -> pd.Series:
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs()
    ], axis=1).max(axis=1)
    return tr.ewm(alpha=1/period, min_periods=period, adjust=False).mean()


class TRBP60Engine:
    """
    Trend-Filtered RSI/Bollinger Pullback (TRBP-60)
    """

    def __init__(
        self,
        ema_period: int = 200,
        bb_period: int = 20,
        bb_std: float = 2.0,
        rsi_period: int = 14,
        rsi_oversold: float = 30.0,
        rsi_overbought: float = 70.0,
        atr_period: int = 14,
        min_stop_atr: float = 1.0,
        max_stop_atr: float = 1.5,
        target_rr_min: float = 0.7,
        target_rr_preferred: float = 0.9,
    ):
        self.ema_period = ema_period
        self.bb_period = bb_period
        self.bb_std = bb_std
        self.rsi_period = rsi_period
        self.rsi_oversold = rsi_oversold
        self.rsi_overbought = rsi_overbought
        self.atr_period = atr_period
        self.min_stop_atr = min_stop_atr
        self.max_stop_atr = max_stop_atr
        self.target_rr_min = target_rr_min
        self.target_rr_preferred = target_rr_preferred

    def prepare_indicators(self, df_1h: pd.DataFrame, df_15m: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
        """
        Expects DataFrames with columns: open, high, low, close, volume (optional)
        Index should be datetime.
        """
        h = df_1h.copy()
        m = df_15m.copy()

        h["ema200"] = ema(h["close"], self.ema_period)
        h["ema200_slope"] = h["ema200"].diff(3)  # rough slope over ~3 hours

        m["rsi"] = rsi(m["close"], self.rsi_period)
        m["bb_upper"], m["bb_mid"], m["bb_lower"] = bollinger_bands(m["close"], self.bb_period, self.bb_std)
        m["atr"] = atr(m["high"], m["low"], m["close"], self.atr_period)

        return h, m

    def _is_ema_rising(self, slope: float, threshold: float = 0.0) -> bool:
        return slope > threshold

    def _is_ema_falling(self, slope: float, threshold: float = 0.0) -> bool:
        return slope < -threshold

    def evaluate(
        self,
        pair: str,
        df_1h: pd.DataFrame,
        df_15m: pd.DataFrame,
        current_spread_pips: float = 0.8,
        high_impact_news_soon: bool = False,
    ) -> Optional[TradeSetup]:
        """
        Evaluate the latest bars for a valid TRBP-60 setup.
        Returns a TradeSetup if conditions are met, else None (or a NO_TRADE status object if desired).
        """
        if len(df_1h) < self.ema_period + 10 or len(df_15m) < max(self.bb_period, self.rsi_period, self.atr_period) + 20:
            return None

        h, m = self.prepare_indicators(df_1h, df_15m)

        # Latest values
        last_h = h.iloc[-1]
        prev_h = h.iloc[-2] if len(h) > 1 else last_h
        last_m = m.iloc[-1]
        prev_m = m.iloc[-2]
        prev2_m = m.iloc[-3] if len(m) > 2 else prev_m

        price = float(last_m["close"])
        ema200 = float(last_h["ema200"])
        slope = float(last_h["ema200_slope"]) if not pd.isna(last_h["ema200_slope"]) else 0.0
        rsi_val = float(last_m["rsi"])
        bb_upper = float(last_m["bb_upper"])
        bb_mid = float(last_m["bb_mid"])
        bb_lower = float(last_m["bb_lower"])
        atr_val = float(last_m["atr"])

        if any(math.isnan(x) for x in [ema200, rsi_val, bb_upper, bb_mid, bb_lower, atr_val]):
            return None

        # --- LONG SETUP ---
        long_trend = price > ema200 and self._is_ema_rising(slope)
        long_pullback = (prev_m["low"] <= prev_m["bb_lower"] or last_m["low"] <= last_m["bb_lower"])
        long_rsi_exhaust = (prev_m["rsi"] <= self.rsi_oversold or last_m["rsi"] <= self.rsi_oversold)
        # Confirmation: candle closes back inside bands and bullish
        long_confirm = (
            last_m["close"] > last_m["bb_lower"]
            and last_m["close"] > last_m["open"]  # bullish close
            and last_m["close"] > prev_m["high"]  # stronger: closes above previous high
        )

        # --- SHORT SETUP ---
        short_trend = price < ema200 and self._is_ema_falling(slope)
        short_pullback = (prev_m["high"] >= prev_m["bb_upper"] or last_m["high"] >= last_m["bb_upper"])
        short_rsi_exhaust = (prev_m["rsi"] >= self.rsi_overbought or last_m["rsi"] >= self.rsi_overbought)
        short_confirm = (
            last_m["close"] < last_m["bb_upper"]
            and last_m["close"] < last_m["open"]  # bearish close
            and last_m["close"] < prev_m["low"]
        )

        direction = Direction.NONE
        reasons = {}
        explanation = []
        warnings = []

        if long_trend and long_pullback and long_rsi_exhaust and long_confirm:
            direction = Direction.BUY
            reasons = {
                "1h_trend_above_ema": True,
                "1h_ema_rising": True,
                "15m_touched_lower_bb": True,
                "15m_rsi_oversold": True,
                "15m_close_inside_bb_bullish": True,
            }
            explanation = [
                "1H price is above the 200 EMA and the EMA is flat-to-rising.",
                "15M price touched or closed below the lower Bollinger Band.",
                f"RSI(14) reached oversold territory (≤ {self.rsi_oversold}).",
                "A bullish candle closed back inside the Bollinger Bands, preferably above the prior high.",
            ]
        elif short_trend and short_pullback and short_rsi_exhaust and short_confirm:
            direction = Direction.SELL
            reasons = {
                "1h_trend_below_ema": True,
                "1h_ema_falling": True,
                "15m_touched_upper_bb": True,
                "15m_rsi_overbought": True,
                "15m_close_inside_bb_bearish": True,
            }
            explanation = [
                "1H price is below the 200 EMA and the EMA is flat-to-falling.",
                "15M price touched or closed above the upper Bollinger Band.",
                f"RSI(14) reached overbought territory (≥ {self.rsi_overbought}).",
                "A bearish candle closed back inside the Bollinger Bands, preferably below the prior low.",
            ]
        else:
            # No valid setup — return a status object for the dashboard
            status = SetupStatus.NO_TRADE
            if long_trend or short_trend:
                status = SetupStatus.WAITING
            return TradeSetup(
                pair=pair,
                direction=Direction.NONE,
                entry=price,
                stop_loss=price,
                take_profit=price,
                risk_reward=0.0,
                setup_quality=0,
                strategy_dna=self._estimate_dna(long_trend or short_trend, atr_val, high_impact_news_soon),
                expected_hold_hours=(0, 0),
                status=status,
                explanation=["No high-quality setup currently detected."],
                warnings=["Market conditions do not currently match the strategy rules."] if not (long_trend or short_trend) else [],
                atr=atr_val,
                rsi_at_signal=rsi_val,
            )

        # Calculate levels
        if direction == Direction.BUY:
            # Stop below the recent pullback low
            pullback_low = float(min(m["low"].iloc[-8:]))  # recent swing
            stop = pullback_low - 0.1 * atr_val  # small buffer
            stop_distance = price - stop
            if stop_distance < self.min_stop_atr * atr_val:
                stop = price - self.min_stop_atr * atr_val
                stop_distance = self.min_stop_atr * atr_val
            if stop_distance > self.max_stop_atr * atr_val:
                # Skip abnormally wide
                return TradeSetup(
                    pair=pair, direction=Direction.NONE, entry=price, stop_loss=price,
                    take_profit=price, risk_reward=0, setup_quality=0,
                    strategy_dna=40, expected_hold_hours=(0, 0),
                    status=SetupStatus.NO_TRADE,
                    explanation=["Setup rejected: stop distance > 1.5 ATR."],
                    atr=atr_val, rsi_at_signal=rsi_val,
                )
            # Target: mid band or ~0.9R
            target_mid = bb_mid
            rr_mid = (target_mid - price) / stop_distance if stop_distance > 0 else 0
            preferred_target = price + self.target_rr_preferred * stop_distance
            # Choose the closer reasonable target
            if 0.7 <= rr_mid <= 1.3:
                take_profit = target_mid
            else:
                take_profit = preferred_target
            risk_reward = (take_profit - price) / stop_distance if stop_distance > 0 else 0
            bb_pos = "lower band rejection"
        else:  # SELL
            pullback_high = float(max(m["high"].iloc[-8:]))
            stop = pullback_high + 0.1 * atr_val
            stop_distance = stop - price
            if stop_distance < self.min_stop_atr * atr_val:
                stop = price + self.min_stop_atr * atr_val
                stop_distance = self.min_stop_atr * atr_val
            if stop_distance > self.max_stop_atr * atr_val:
                return TradeSetup(
                    pair=pair, direction=Direction.NONE, entry=price, stop_loss=price,
                    take_profit=price, risk_reward=0, setup_quality=0,
                    strategy_dna=40, expected_hold_hours=(0, 0),
                    status=SetupStatus.NO_TRADE,
                    explanation=["Setup rejected: stop distance > 1.5 ATR."],
                    atr=atr_val, rsi_at_signal=rsi_val,
                )
            target_mid = bb_mid
            rr_mid = (price - target_mid) / stop_distance if stop_distance > 0 else 0
            preferred_target = price - self.target_rr_preferred * stop_distance
            if 0.7 <= rr_mid <= 1.3:
                take_profit = target_mid
            else:
                take_profit = preferred_target
            risk_reward = (price - take_profit) / stop_distance if stop_distance > 0 else 0
            bb_pos = "upper band rejection"

        if risk_reward < self.target_rr_min:
            return TradeSetup(
                pair=pair, direction=Direction.NONE, entry=price, stop_loss=price,
                take_profit=price, risk_reward=0, setup_quality=0,
                strategy_dna=45, expected_hold_hours=(0, 0),
                status=SetupStatus.NO_TRADE,
                explanation=[f"Setup rejected: R:R {risk_reward:.2f} below minimum {self.target_rr_min}."],
                atr=atr_val, rsi_at_signal=rsi_val,
            )

        # Quality score (0-100)
        quality = self._calculate_quality(
            direction, long_trend or short_trend, rsi_val, risk_reward,
            atr_val, high_impact_news_soon, current_spread_pips
        )

        # Strategy DNA (market regime match)
        dna = self._estimate_dna(True, atr_val, high_impact_news_soon, quality)

        if high_impact_news_soon:
            warnings.append("High-impact economic news is scheduled soon. Exercise caution.")

        # Estimated hold (heuristic based on ATR and typical mean-reversion)
        hold_low = 1.5
        hold_high = 6.0
        if atr_val > 0:
            # Rough: higher volatility → potentially faster moves
            hold_high = min(8.0, max(3.0, 4.0 + atr_val * 50))

        setup = TradeSetup(
            pair=pair,
            direction=direction,
            entry=price,
            stop_loss=stop,
            take_profit=take_profit,
            risk_reward=risk_reward,
            setup_quality=quality,
            strategy_dna=dna,
            expected_hold_hours=(hold_low, hold_high),
            status=SetupStatus.VALID,
            explanation=explanation,
            warnings=warnings,
            atr=atr_val,
            rsi_at_signal=rsi_val,
            bb_position=bb_pos,
            reasons=reasons,
        )
        return setup

    def _calculate_quality(
        self,
        direction: Direction,
        trend_ok: bool,
        rsi_val: float,
        rr: float,
        atr_val: float,
        news: bool,
        spread: float,
    ) -> int:
        score = 50  # base

        if trend_ok:
            score += 15
        # RSI extremity
        if direction == Direction.BUY and rsi_val <= 25:
            score += 12
        elif direction == Direction.BUY and rsi_val <= 30:
            score += 8
        elif direction == Direction.SELL and rsi_val >= 75:
            score += 12
        elif direction == Direction.SELL and rsi_val >= 70:
            score += 8

        # R:R quality
        if 0.85 <= rr <= 1.15:
            score += 12
        elif 0.7 <= rr < 0.85 or 1.15 < rr <= 1.4:
            score += 6

        # Spread penalty
        if spread > 1.5:
            score -= 15
        elif spread > 1.0:
            score -= 8

        if news:
            score -= 10

        return max(0, min(100, int(score)))

    def _estimate_dna(
        self,
        trend_present: bool,
        atr_val: float,
        news: bool,
        quality: int = 50,
    ) -> int:
        dna = 55
        if trend_present:
            dna += 20
        if quality > 75:
            dna += 10
        if news:
            dna -= 15
        # mild volatility preference for mean-reversion
        if 0.0004 < atr_val < 0.0020:  # rough EURUSD scale
            dna += 5
        return max(20, min(95, dna))


def position_size(
    account_balance: float,
    risk_percent: float,
    entry: float,
    stop_loss: float,
    pair: str = "EURUSD",
    account_currency: str = "USD",
) -> Dict[str, float]:
    """
    Simple position size calculator (standard lot = 100_000 units).
    Returns recommended lots and risk amount.
    Note: For true accuracy use broker contract specs + conversion rates.
    """
    risk_amount = account_balance * (risk_percent / 100.0)
    stop_pips = abs(entry - stop_loss) * 10000  # for 4-decimal pairs (JPY is 100)
    if "JPY" in pair.upper():
        stop_pips = abs(entry - stop_loss) * 100

    # Approximate pip value for 1 standard lot (very simplified for USD accounts)
    pip_value_per_lot = 10.0  # ~$10 per pip for EURUSD 1 lot
    if "JPY" in pair.upper():
        pip_value_per_lot = 9.0  # rough

    if stop_pips <= 0:
        return {"lots": 0.0, "risk_amount": 0.0, "stop_pips": 0.0}

    lots = risk_amount / (stop_pips * pip_value_per_lot)
    lots = max(0.01, round(lots, 2))  # min 0.01

    return {
        "lots": lots,
        "risk_amount": round(risk_amount, 2),
        "stop_pips": round(stop_pips, 1),
        "pip_value_used": pip_value_per_lot,
    }
