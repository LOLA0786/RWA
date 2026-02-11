import { useState, useEffect } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, ReferenceLine } from "recharts";

/**
 * SpreadDashboard
 * ───────────────
 * Live view of cross-chain RWA price spreads.
 * Polls /api/spreads every 30s.
 * Shows spread history chart + current opportunity table.
 */

const MOCK_PAIRS = [
  { symbol: "OUSG", srcChain: "Sepolia", destChain: "Mumbai" },
  { symbol: "OUSG", srcChain: "Mumbai",  destChain: "Sepolia" },
];

// Generate realistic mock spread data for demo
function genHistory(baseSpread) {
  return Array.from({ length: 20 }, (_, i) => ({
    t:      `${i * 2}m`,
    spread: Math.max(0, baseSpread + (Math.random() - 0.5) * 30),
  }));
}

function SpreadCard({ pair, threshold = 50 }) {
  const [history]    = useState(() => genHistory(pair.spread));
  const isOpportunity = pair.spread >= threshold;

  return (
    <div style={{
      background:   "#0d1219",
      border:       `1px solid ${isOpportunity ? "#00e5ff" : "#1e2d3d"}`,
      borderRadius: 4,
      padding:      20,
      boxShadow:    isOpportunity ? "0 0 20px rgba(0,229,255,0.1)" : "none",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
        <div>
          <div style={{ fontSize: 11, color: "#4a6478", letterSpacing: "0.12em", textTransform: "uppercase", marginBottom: 4 }}>
            {pair.symbol}
          </div>
          <div style={{ fontSize: 13, color: "#d4e6f0" }}>
            {pair.srcChain} → {pair.destChain}
          </div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{
            fontSize:   22,
            fontFamily: "'Space Mono', monospace",
            fontWeight: 700,
            color:      isOpportunity ? "#00e5ff" : "#7a99b0",
          }}>
            {pair.spread.toFixed(1)} <span style={{ fontSize: 12 }}>bps</span>
          </div>
          {isOpportunity && (
            <div style={{
              fontSize:    10,
              color:       "#7fff6e",
              background:  "rgba(127,255,110,0.08)",
              padding:     "2px 8px",
              borderRadius: 10,
              marginTop:   4,
            }}>
              ⚡ OPPORTUNITY
            </div>
          )}
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginBottom: 14 }}>
        {[
          ["Src Price", `$${pair.srcPrice?.toFixed(4) ?? "—"}`],
          ["Dst Price", `$${pair.destPrice?.toFixed(4) ?? "—"}`],
        ].map(([label, val]) => (
          <div key={label} style={{ background: "#080c10", padding: "8px 10px", borderRadius: 3 }}>
            <div style={{ fontSize: 10, color: "#4a6478", marginBottom: 2 }}>{label}</div>
            <div style={{ fontSize: 13, fontFamily: "'Space Mono',monospace", color: "#d4e6f0" }}>{val}</div>
          </div>
        ))}
      </div>

      <ResponsiveContainer width="100%" height={60}>
        <LineChart data={history}>
          <Line
            type="monotone"
            dataKey="spread"
            stroke={isOpportunity ? "#00e5ff" : "#1e2d3d"}
            dot={false}
            strokeWidth={1.5}
          />
          <ReferenceLine y={threshold} stroke="#7fff6e" strokeDasharray="3 3" />
          <Tooltip
            contentStyle={{ background: "#131c26", border: "1px solid #1e2d3d", fontSize: 11 }}
            formatter={v => [`${v.toFixed(1)} bps`, "Spread"]}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

export default function SpreadDashboard() {
  const [pairs, setPairs] = useState([]);
  const [lastUpdated, setLastUpdated] = useState(null);

  // Simulate live polling (replace with real fetch("/api/spreads"))
  useEffect(() => {
    function generatePairs() {
      return MOCK_PAIRS.map(p => ({
        ...p,
        srcPrice:  98.42 + (Math.random() - 0.5) * 0.5,
        destPrice: 98.42 + (Math.random() - 0.5) * 0.5 + Math.random() * 0.8,
        spread:    Math.random() * 120,
      }));
    }
    setPairs(generatePairs());
    setLastUpdated(new Date());

    const interval = setInterval(() => {
      setPairs(generatePairs());
      setLastUpdated(new Date());
    }, 10_000);
    return () => clearInterval(interval);
  }, []);

  const opportunities = pairs.filter(p => p.spread >= 50).length;

  return (
    <div style={{ fontFamily: "'IBM Plex Mono', monospace", color: "#d4e6f0" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
        <div>
          <h2 style={{ fontFamily: "'DM Serif Display',serif", fontWeight: 400, fontSize: 22, color: "#fff" }}>
            Live Spread Monitor
          </h2>
          <div style={{ fontSize: 11, color: "#4a6478", marginTop: 2 }}>
            Updates every 30s · Threshold: 50 bps
          </div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{ fontSize: 22, fontFamily: "'Space Mono',monospace", fontWeight: 700, color: "#f5c842" }}>
            {opportunities}
          </div>
          <div style={{ fontSize: 10, color: "#4a6478" }}>Active Opportunities</div>
        </div>
      </div>

      {lastUpdated && (
        <div style={{ fontSize: 11, color: "#4a6478", marginBottom: 16 }}>
          Last updated: {lastUpdated.toLocaleTimeString()}
        </div>
      )}

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px,1fr))", gap: 12 }}>
        {pairs.map(pair => (
          <SpreadCard
            key={`${pair.symbol}-${pair.srcChain}-${pair.destChain}`}
            pair={pair}
          />
        ))}
      </div>
    </div>
  );
}
