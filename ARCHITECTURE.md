# Architecture

## Overview

The protocol is a modular DeFi system built around DAO governance, approved guardians, ERC4626 vaults, strategy routing, risk validation, adapter allowlisting, and treasury accounting.

It is not a single-contract application. It behaves as a protocol composed of several dependent subsystems. Because of that, the correct mental model is a layered architecture:

```text
Governance Layer
  ↓ controls
Core Protocol / Treasury / Risk / Registry
  ↓ authorizes
Guardian System
  ↓ creates
Vault Factory + ERC4626 Vault Clones
  ↓ executes through
Strategy Router
  ↓ validates with
Risk Manager
  ↓ connects through
Adapters
  ↓ allocates into
External Protocols
```

## 1. Governance Layer

### Contracts

- `GovernanceToken.sol`
- `DaoGovernor.sol`
- `TimeLock.sol`

### Purpose

This layer controls long-term protocol administration. Governance token holders participate in proposals and voting. Successful proposals are queued and executed through the timelock.

### Responsibilities

- manage privileged protocol configuration;
- upgrade contracts where applicable;
- manage allowlists;
- set caps and fees;
- pause and unpause protocol functionality;
- add or remove adapters;
- approve high-privilege role changes.

### Important Review Notes

`TimeLock` is mostly OpenZeppelin-based, so the main concern is not testing OpenZeppelin internals. The critical part is validating that the deployed governor/timelock configuration is operational:

- proposer role;
- executor role;
- canceller role;
- default admin handoff;
- proposal → vote → queue → execute flow.

## 2. Bootstrap and Treasury Layer

### Contracts

- `GenesisBonding.sol`
- `Treasury.sol`

### Purpose

This layer handles initial governance token distribution and protocol asset custody.

### GenesisBonding

`GenesisBonding` allows users to buy/mint governance tokens using allowed purchase tokens. It transfers payment tokens to `Treasury` and mints `GovernanceToken` to buyers until minting is finalized.

Important properties:

- purchase token allowlist;
- rate-based minting;
- treasury custody of payment assets;
- finalization of minting;
- prevention of sweeping core purchase/governance assets.

### Treasury

`Treasury` holds protocol revenue and bootstrap assets. It distinguishes genesis assets from non-genesis assets by querying `ProtocolCore`.

Important properties:

- genesis asset withdrawal control;
- non-genesis sweep permissions;
- native asset handling;
- dependency on `ProtocolCore` for asset classification.

### Important Review Notes

`Treasury` depends on `protocolCore` being configured. This must be validated as a deployment invariant because an unset `protocolCore` can break withdrawal logic.

## 3. Core Protocol Layer

### Contract

- `ProtocolCore.sol`

### Purpose

`ProtocolCore` is the central configuration and protocol control contract.

### Responsibilities

- supported vault asset management;
- genesis token tracking;
- global vault creation pause;
- global deposit pause;
- manager and emergency role controls;
- upgrade authorization if using UUPS upgradeability.

### Key Security Considerations

- only authorized roles should modify supported assets;
- pause controls must behave predictably;
- emergency roles should be narrowly scoped;
- upgrade authorization should be governed by timelock/admin only.

## 4. Guardian Layer

### Contracts

- `GuardianAdministrator.sol`
- `GuardianBondEscrow.sol`

### Purpose

This layer controls who is allowed to create and manage vaults.

### Guardian Lifecycle

```text
Inactive
  → Pending
    → Active
    → Rejected
  → Banned
  → Resigned
```

### GuardianAdministrator Responsibilities

- guardian application;
- proposal creation for approval;
- approval through governance/timelock;
- rejection based on proposal state;
- resignation;
- banning;
- status tracking.

### GuardianBondEscrow Responsibilities

- lock guardian stake;
- refund stake;
- release stake on resignation;
- slash stake to treasury;
- restrict bond operations to guardian administration.

### Important Review Notes

This subsystem should be tested as a state machine. A guardian should not become active without stake being locked, and a banned/resigned guardian should not be able to create vaults.

## 5. Vault Layer

### Contracts

- `VaultFactory.sol`
- `VaultRegistry.sol`
- `VaultImplementation.sol`

### Purpose

This layer creates and tracks ERC4626 vaults. Each vault is associated with an asset and a guardian.

### VaultFactory

Responsibilities:

- deploy minimal proxy vault clones;
- validate guardian status;
- validate supported vault asset;
- initialize vault clones;
- register vaults in `VaultRegistry`.

### VaultRegistry

Responsibilities:

- track registered vaults;
- map guardian/asset pairs to vaults;
- enforce factory-only registration;
- allow registry queries;
- support vault deactivation.

### VaultImplementation

Responsibilities:

- ERC4626 deposit/mint/withdraw/redeem;
- vault-level accounting;
- strategy execution hooks;
- active adapter tracking;
- fee share accounting;
- guardian-controlled strategy allocation;
- interaction with `StrategyRouter`.

### Important Review Notes

The vault layer is one of the highest-risk components because it directly touches user funds and accounting. The most important tests should validate:

- deposits;
- withdrawals;
- totalAssets;
- strategy investment;
- divestment;
- strategy rotation;
- fee accounting;
- pause behavior;
- role restrictions.

## 6. Execution and Risk Layer

### Contracts

- `StrategyRouter.sol`
- `RiskManager.sol`

### StrategyRouter

The router acts as the execution gateway between vaults and adapters.

Responsibilities:

- invest through adapters;
- divest from adapters;
- rebalance vault strategies;
- execute batched calls;
- enforce adapter allowlist;
- require vaults to be active and registered;
- interact with risk validation before investment.

### RiskManager

The risk manager validates whether strategy execution is safe.

Responsibilities:

- Chainlink-style price feed checks;
- stale price / heartbeat checks;
- depeg bounds;
- asset enablement;
- execution pause;
- circuit-breaker behavior;
- healthy/unhealthy asset state.

### Important Review Notes

The router should block investment if:

- the vault is not registered or inactive;
- the adapter is not allowlisted;
- the risk manager rejects execution;
- calldata is malformed;
- action arrays have inconsistent lengths;
- duplicate adapters are used when not allowed.

Divest flows may intentionally behave differently from invest flows because withdrawing from a strategy may need to remain possible even under degraded oracle conditions.

## 7. Adapter Layer

### Contracts Reviewed

- `AaveV3Adapter.sol`
- `CompoundV3Adapter.sol`

### Purpose

Adapters are protocol connectors. They isolate external protocol logic from the vault and router. This makes the architecture scalable because new protocols can be integrated by adding new allowlisted adapters.

### Current Adapters

| Adapter | Purpose |
|---|---|
| `AaveV3Adapter.sol` | Lending / supply integration. |
| `CompoundV3Adapter.sol` | Compound-style lending / supply integration. |

### Future Adapter Pattern

The architecture can scale toward:

- Uniswap V3 LP adapters;
- Pendle / Curve adapters;
- collateralized borrowing adapters;
- timelocked reward adapters;
- rebasing asset adapters;
- cross-chain bridge adapters;
- flash-loan rebalance adapters.

### Important Review Notes

Adapters should never depend on test-only interfaces in production contracts. They should use production interfaces under `contracts/adapters/.../interfaces` or `contracts/interfaces/...`.

Adapters require both unit tests with mocks and fork tests against real or realistic protocol deployments.

## 8. Frontend Architecture Considerations

The frontend should not be treated as separate from protocol correctness. It needs clear contract state integration.

Recommended frontend-facing artifacts:

- generated ABIs;
- generated deployed addresses;
- generated TypeScript SDK/helpers;
- local seeded data for demo flows;
- network-aware configuration;
- readable protocol status mapping.

The frontend should clearly display:

- active/inactive guardian status;
- vault active/inactive status;
- supported/unsupported asset status;
- adapter allowlist status;
- risk manager status;
- oracle health;
- paused states;
- pending governance proposals;
- timelock queued/executable actions.

## 9. Architectural Strengths

- Modular layers with separated responsibilities.
- Real DeFi patterns: governance, timelock, ERC4626, factories, registries, adapters, routers, risk modules.
- Extensible adapter architecture.
- Guardian-based operational model.
- Treasury and fee accounting concept.
- Upgradeable/protocol-governed configuration.

## 10. Architectural Risks

- Many dependencies make deployment correctness critical.
- Router/adapter/vault accounting requires strong invariants.
- Governance/timelock roles must be proven operational.
- Adapters must be production-grade, not mock-driven.
- Seed scripts may hide missing production configuration.
- Complexity may exceed current test coverage until a professional suite is added.
