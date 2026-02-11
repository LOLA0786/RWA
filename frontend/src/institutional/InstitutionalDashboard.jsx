import React, { useEffect, useState } from "react";

export default function InstitutionalDashboard() {
  const [risk, setRisk] = useState(0);
  const [status, setStatus] = useState("Loading");

  useEffect(() => {
    fetch("/institutional/risk/USDC", {
      headers: { "x-api-key": "demo-key" }
    })
      .then(res => res.json())
      .then(data => {
        setRisk(data.riskScore);
        setStatus(data.status);
      })
      .catch(() => setStatus("Error"));
  }, []);

  return (
    <div style={{ padding: 20 }}>
      <h1>Institutional Control Panel</h1>
      <div>
        <strong>Risk Score:</strong> {risk}
      </div>
      <div>
        <strong>Status:</strong> {status}
      </div>
    </div>
  );
}
