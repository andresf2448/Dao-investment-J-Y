# 🏛 Protocol Frontend — Governance, Vaults & Treasury System

## 🌐 Overview

This project is a **modular frontend architecture** designed for a DeFi protocol that integrates:

- Governance (DAO proposals & voting)
- Vault infrastructure (ERC4626-like)
- Treasury management
- Guardian-based execution layer
- Risk monitoring and operational controls

The system is designed to be:
- **Web3-agnostic at UI level**
- **Hook-driven for data and logic**
- **Ready for wagmi / viem integration**
- **Scalable with The Graph / indexing layers**

---

## 🧠 Architecture Principles

### 1. Separation of Concerns

| Layer        | Responsibility |
|-------------|----------------|
| UI (Pages)  | Rendering only |
| Hooks       | Data + logic |
| Contracts   | External integration (future) |

> UI never interacts directly with Web3.

---

### 2. Capability-Based Access Control

Instead of role checks:

```ts
// ❌ Avoid
if (role === "admin")

// ✅ Use
if (capabilities.canCreateProposal)