import React, { useEffect, useState } from "react";

export default function OperatorDashboard() {
  const [reserve, setReserve] = useState({});
  const [audits, setAudits] = useState([]);

  const headers = { "x-api-key": "demo-key" };

  useEffect(() => {
    fetch("/stablecoin/reserve", { headers })
      .then(res => res.json())
      .then(setReserve);

    fetch("/stablecoin/audits", { headers })
      .then(res => res.json())
      .then(setAudits);
  }, []);

  return (
    <div style={{ padding: 20 }}>
      <h1>Stablecoin Operator Dashboard</h1>

      <h2>Reserve Status</h2>
      <pre>{JSON.stringify(reserve, null, 2)}</pre>

      <h2>Audit Log</h2>
      <pre>{JSON.stringify(audits, null, 2)}</pre>
    </div>
  );
}
