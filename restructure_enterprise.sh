#!/bin/bash

set -e

echo "Creating enterprise-grade structure..."

# =========================
# CORE LAYERS
# =========================

mkdir -p contracts/core
mkdir -p contracts/vault
mkdir -p contracts/risk
mkdir -p contracts/compliance
mkdir -p contracts/reserve
mkdir -p contracts/router
mkdir -p contracts/governance
mkdir -p contracts/interfaces

# =========================
# BACKEND ARCHITECTURE
# =========================

mkdir -p backend/src/core
mkdir -p backend/src/compliance
mkdir -p backend/src/risk
mkdir -p backend/src/router
mkdir -p backend/src/settlement
mkdir -p backend/src/revenue
mkdir -p backend/src/institutional
mkdir -p backend/src/monitoring
mkdir -p backend/src/utils

# =========================
# SDK + EXTERNAL API
# =========================

mkdir -p sdk/js
mkdir -p sdk/python
mkdir -p api/openapi

# =========================
# INFRASTRUCTURE
# =========================

mkdir -p infra/docker
mkdir -p infra/k8s
mkdir -p infra/terraform

# =========================
# DOCUMENTATION
# =========================

mkdir -p docs/architecture
mkdir -p docs/compliance
mkdir -p docs/security
mkdir -p docs/tokenomics
mkdir -p docs/roadmap

# =========================
# DATA + ANALYTICS
# =========================

mkdir -p analytics
mkdir -p analytics/queries
mkdir -p analytics/dashboards

# =========================
# MOVE EXISTING CONTRACTS
# =========================

if [ -f contracts/src/RWALiquidityHub.sol ]; then
  mv contracts/src/RWALiquidityHub.sol contracts/core/
fi

if [ -f contracts/src/CCIPBridgeAdapter.sol ]; then
  mv contracts/src/CCIPBridgeAdapter.sol contracts/router/
fi

if [ -f contracts/src/SpreadOracle.sol ]; then
  mv contracts/src/SpreadOracle.sol contracts/risk/
fi

if [ -f contracts/src/FeeCollector.sol ]; then
  mv contracts/src/FeeCollector.sol contracts/revenue/
fi

if [ -d contracts/src/interfaces ]; then
  mv contracts/src/interfaces/* contracts/interfaces/ 2>/dev/null || true
fi

# =========================
# CLEANUP
# =========================

rm -rf contracts/src

echo "Enterprise structure ready."
