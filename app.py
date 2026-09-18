"""
SnapChart — Spot the Setup. Seize the Trade.
Simple Flask dashboard + TRBP-60 strategy engine.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure backend is importable
sys.path.insert(0, str(Path(__file__).parent))

from flask import Flask, render_template, jsonify, request
from strategy_engine import TRBP60Engine, position_size, Direction, SetupStatus
from sample_data import generate_ohlc, make_demo_setups
from datetime import datetime, timezone

app = Flask(
    __name__,
    template_folder=str(Path(__file__).parent.parent / "templates"),
    static_folder=str(Path(__file__).parent.parent / "static"),
)

engine = TRBP60Engine()

# Cache demo data so the page is fast
_demo_cache = None


def get_market_scan():
    global _demo_cache
    if _demo_cache is None:
        _demo_cache = make_demo_setups(engine)
    return _demo_cache


@app.route("/")
def index():
    return render_template("dashboard.html")


@app.route("/api/scan")
def api_scan():
    results = get_market_scan()
    scan = []
    valid_count = 0
    for item in results:
        s = item["setup"]
        d = s.to_dict() if s else {}
        if s and s.status == SetupStatus.VALID:
            valid_count += 1
        scan.append(d)

    return jsonify({
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pairs_analysed": len(scan),
        "setups_detected": valid_count,
        "scan": scan,
        "message": "Market scan complete — TRBP-60 engine",
    })


@app.route("/api/setup/<pair>")
def api_setup(pair: str):
    results = get_market_scan()
    for item in results:
        if item["pair"].upper() == pair.upper():
            s = item["setup"]
            return jsonify(s.to_dict() if s else {"error": "No data"})
    return jsonify({"error": "Pair not found"}), 404


@app.route("/api/position-size", methods=["POST"])
def api_position_size():
    data = request.get_json() or {}
    balance = float(data.get("balance", 1000))
    risk_pct = float(data.get("risk_percent", 0.5))
    entry = float(data.get("entry", 1.17))
    stop = float(data.get("stop_loss", 1.168))
    pair = data.get("pair", "EURUSD")
    result = position_size(balance, risk_pct, entry, stop, pair)
    return jsonify(result)


@app.route("/api/refresh")
def api_refresh():
    """Force regenerate demo data (new random seed flavour)."""
    global _demo_cache
    _demo_cache = None
    return api_scan()


if __name__ == "__main__":
    print("SnapChart engine ready. Starting dashboard on http://0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
