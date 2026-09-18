/* SnapChart Dashboard Logic */

const state = {
  scan: [],
  selectedPair: null,
};

// ---------- Background subtle chart ----------
function drawBackgroundChart() {
  const canvas = document.getElementById("bg-chart");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    paint();
  }

  function paint() {
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    // Faint grid
    ctx.strokeStyle = "rgba(255,255,255,0.03)";
    ctx.lineWidth = 1;
    const step = 48;
    for (let x = 0; x < w; x += step) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }
    for (let y = 0; y < h; y += step) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    // Abstract price path (candlestick-ish silhouette)
    const points = 80;
    const midY = h * 0.55;
    ctx.beginPath();
    ctx.strokeStyle = "rgba(184, 242, 0, 0.12)";
    ctx.lineWidth = 1.5;

    let y = midY;
    for (let i = 0; i < points; i++) {
      const x = (i / (points - 1)) * w;
      y += (Math.sin(i * 0.18) * 18) + (Math.cos(i * 0.07) * 12) + (Math.random() - 0.5) * 8;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // A few glowing points
    ctx.fillStyle = "rgba(184, 242, 0, 0.25)";
    for (let i = 0; i < 5; i++) {
      const x = (0.15 + i * 0.18) * w;
      const py = midY + Math.sin(i * 1.7) * 40;
      ctx.beginPath();
      ctx.arc(x, py, 2.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  window.addEventListener("resize", resize);
  resize();
}

// ---------- API ----------
async function fetchScan() {
  try {
    const res = await fetch("/api/scan");
    const data = await res.json();
    state.scan = data.scan || [];
    updateSummary(data);
    renderCards();
  } catch (err) {
    console.error("Scan failed", err);
    document.getElementById("pairs-count").textContent = "—";
    document.getElementById("setups-count").textContent = "—";
  }
}

function updateSummary(data) {
  document.getElementById("pairs-count").textContent = data.pairs_analysed ?? "—";
  document.getElementById("setups-count").textContent = data.setups_detected ?? "—";
  const t = data.generated_at ? new Date(data.generated_at) : new Date();
  document.getElementById("scan-time").textContent = t.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
}

function statusClass(setup) {
  if (!setup || setup.direction === "NONE") {
    if (setup?.status === "WAITING") return "waiting";
    return "no-trade";
  }
  return setup.direction.toLowerCase();
}

function statusLabel(setup) {
  if (!setup || setup.direction === "NONE") {
    if (setup?.status === "WAITING") return "WAITING";
    return "NO TRADE";
  }
  return setup.direction === "BUY" ? "STRONG BUY" : "STRONG SELL";
}

function renderCards() {
  const grid = document.getElementById("cards-grid");
  grid.innerHTML = "";

  state.scan.forEach((setup) => {
    const isValid = setup.direction !== "NONE" && setup.status === "VALID";
    const card = document.createElement("article");
    card.className = `setup-card ${isValid ? "valid" : ""}`;
    card.dataset.pair = setup.pair;

    const scoreDisplay = isValid
      ? `<div class="card-score">${setup.setup_quality}<span>/100</span></div>
         <div class="card-score-label">Setup Quality</div>`
      : `<div class="card-score" style="color:var(--text-dim);font-size:22px;">—</div>
         <div class="card-score-label">${setup.explanation?.[0] || "No setup"}</div>`;

    const meta = isValid
      ? `<div class="card-meta">
           <div>Entry <span class="mono">${setup.entry}</span></div>
           <div>SL <span class="mono">${setup.stop_loss}</span> · TP <span class="mono">${setup.take_profit}</span></div>
           <div>R:R <span class="mono">1:${setup.risk_reward}</span> · DNA ${setup.strategy_dna}%</div>
         </div>`
      : `<div class="card-meta">
           <div>Strategy DNA <span class="mono">${setup.strategy_dna || "—"}%</span></div>
           <div style="margin-top:4px;font-size:12px;color:var(--text-dim);">Conditions not met</div>
         </div>`;

    card.innerHTML = `
      <div class="card-top">
        <div class="card-pair">${formatPair(setup.pair)}</div>
        <div class="card-status ${statusClass(setup)}">${statusLabel(setup)}</div>
      </div>
      ${scoreDisplay}
      ${meta}
    `;

    card.addEventListener("click", () => openDetail(setup));
    grid.appendChild(card);
  });
}

function formatPair(p) {
  if (!p) return "—";
  if (p.length === 6) return p.slice(0, 3) + "/" + p.slice(3);
  return p;
}

function openDetail(setup) {
  state.selectedPair = setup.pair;
  const panel = document.getElementById("detail-panel");
  panel.classList.remove("hidden");

  document.getElementById("detail-pair").textContent = formatPair(setup.pair);

  const dirEl = document.getElementById("detail-direction");
  dirEl.textContent = setup.direction === "NONE" ? setup.status : setup.direction;
  dirEl.className = "detail-direction " + (setup.direction === "BUY" ? "buy" : setup.direction === "SELL" ? "sell" : "");

  document.getElementById("detail-quality").innerHTML =
    setup.setup_quality > 0 ? `${setup.setup_quality}<span>/100</span>` : "—";
  document.getElementById("detail-dna").innerHTML =
    `${setup.strategy_dna || "—"}<span>%</span>`;

  document.getElementById("detail-entry").textContent = setup.entry || "—";
  document.getElementById("detail-sl").textContent = setup.stop_loss || "—";
  document.getElementById("detail-tp").textContent = setup.take_profit || "—";
  document.getElementById("detail-rr").textContent =
    setup.risk_reward > 0 ? `1 : ${setup.risk_reward}` : "—";

  const hold = setup.expected_hold_hours || [0, 0];
  document.getElementById("detail-hold").textContent =
    hold[0] > 0 ? `${hold[0]}–${hold[1]} hours` : "—";

  // Why list
  const list = document.getElementById("why-list");
  list.innerHTML = "";
  (setup.explanation || []).forEach((line) => {
    const li = document.createElement("li");
    li.textContent = line;
    list.appendChild(li);
  });

  const warn = document.getElementById("why-warnings");
  warn.innerHTML = (setup.warnings || []).map((w) => `⚠ ${w}`).join("<br>");

  // Reset why + risk result
  document.getElementById("why-content").classList.add("hidden");
  document.getElementById("risk-result").classList.add("hidden");

  panel.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

// Event listeners
document.getElementById("btn-close-detail").addEventListener("click", () => {
  document.getElementById("detail-panel").classList.add("hidden");
  state.selectedPair = null;
});

document.getElementById("btn-why").addEventListener("click", () => {
  document.getElementById("why-content").classList.toggle("hidden");
});

document.getElementById("btn-calc-size").addEventListener("click", async () => {
  const setup = state.scan.find((s) => s.pair === state.selectedPair);
  if (!setup || setup.direction === "NONE") return;

  const balance = parseFloat(document.getElementById("risk-balance").value) || 1000;
  const riskPct = parseFloat(document.getElementById("risk-pct").value) || 0.5;

  try {
    const res = await fetch("/api/position-size", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        balance,
        risk_percent: riskPct,
        entry: setup.entry,
        stop_loss: setup.stop_loss,
        pair: setup.pair,
      }),
    });
    const data = await res.json();
    document.getElementById("rec-lots").textContent = data.lots.toFixed(2);
    document.getElementById("rec-risk").textContent = data.risk_amount.toFixed(2);
    document.getElementById("risk-result").classList.remove("hidden");
  } catch (e) {
    console.error(e);
  }
});

document.getElementById("btn-refresh").addEventListener("click", async () => {
  const btn = document.getElementById("btn-refresh");
  btn.textContent = "Scanning…";
  btn.disabled = true;
  try {
    await fetch("/api/refresh");
    await fetchScan();
  } finally {
    btn.textContent = "↻ Rescan";
    btn.disabled = false;
  }
});

// Init
drawBackgroundChart();
fetchScan();
// Soft auto-refresh every 90s (demo)
setInterval(fetchScan, 90000);
