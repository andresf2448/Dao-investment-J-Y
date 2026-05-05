# Deployment

## Overview

The main deployment script reviewed is:

```text
script/deploy/DeployInvestmentDao.s.sol
```

There are also individual deployment scripts for specific components and a local seeding script:

```text
script/deploy/*.s.sol
script/local/SeedLocal.s.sol
```

The deployment is dependency-heavy. Several contracts require addresses of previously deployed contracts, and multiple post-deploy configuration calls are required to make the protocol usable.

## Main Deployment Order

The observed deployment order is approximately:

1. `TimeLock`
2. `GovernanceToken`
3. `Treasury`
4. `GenesisBonding`
5. `DaoGovernor`
6. `ProtocolCore`
7. `RiskManager`
8. `GuardianAdministrator`
9. governance token role configuration
10. `GuardianBondEscrow`
11. `VaultRegistry`
12. `StrategyRouter`
13. `VaultImplementation`
14. `VaultFactory`
15. `AaveV3Adapter`
16. `CompoundV3Adapter`
17. post-deploy protocol defaults
18. deployment JSON / SDK generation

## Contract Dependency Map

### TimeLock

Used by:

- `DaoGovernor`
- `Treasury`
- `ProtocolCore`
- `RiskManager`
- `VaultRegistry`
- `StrategyRouter`
- privileged role administration

Must be configured so governance can queue and execute privileged calls.

### GovernanceToken

Used by:

- `DaoGovernor` for voting power;
- `GenesisBonding` for minting;
- DAO holders for governance.

Required configuration:

- grant `MINTER_ROLE` to `GenesisBonding`;
- revoke temporary deployer minter role;
- transfer/default admin to `TimeLock`;
- revoke deployer default admin in production.

### Treasury

Used by:

- `GenesisBonding` as recipient of payment tokens;
- protocol fee accounting;
- governance-managed asset custody.

Required configuration:

- admin should be timelock/governance;
- `protocolCore` should be set if treasury uses it for asset classification.

### GenesisBonding

Depends on:

- `GovernanceToken`;
- `Treasury`;
- allowed purchase tokens;
- mint rate.

Required configuration:

- `GovernanceToken` must allow `GenesisBonding` to mint.

### DaoGovernor

Depends on:

- `GovernanceToken`;
- `TimeLock`.

Required configuration:

- timelock roles must allow governor to propose/queue/execute/cancel depending on governance design.

### ProtocolCore

Depends on:

- admin/timelock;
- allowed genesis tokens;
- allowed vault asset(s).

Used by:

- `Treasury`;
- `VaultFactory`;
- `VaultImplementation`;
- possibly frontend state checks.

### RiskManager

Depends on:

- admin/timelock;
- asset configuration;
- oracle price feeds.

Used by:

- `StrategyRouter`.

Required configuration:

- asset enabled;
- price feed set;
- heartbeat set;
- depeg/stability parameters set where applicable.

### GuardianAdministrator

Depends on:

- `DaoGovernor`;
- `TimeLock`;
- bond token.

Used by:

- `VaultFactory` to validate active guardians;
- `GuardianBondEscrow` for bond lifecycle.

Required configuration:

- `setBondEscrow(guardianBondEscrow)`.

### GuardianBondEscrow

Depends on:

- `GuardianAdministrator`;
- treasury;
- bond token.

Required configuration:

- must be recognized by `GuardianAdministrator`.

### VaultRegistry

Depends on:

- admin/timelock.

Used by:

- `VaultFactory` for registration;
- `StrategyRouter` for active vault validation;
- frontend vault discovery.

Required configuration:

- `setFactory(vaultFactory)` or equivalent factory role assignment.

### StrategyRouter

Depends on:

- `RiskManager`;
- `VaultRegistry`;
- admin/timelock.

Required configuration:

- adapters must be allowlisted before investment flows work;
- vaults must be registered and active.

### VaultImplementation

Used as:

- implementation target for minimal proxy clones.

Must not be used directly as a user-facing vault.

### VaultFactory

Depends on:

- `VaultImplementation`;
- `GuardianAdministrator`;
- `VaultRegistry`;
- `StrategyRouter`;
- `ProtocolCore`;
- admin/deployer/timelock.

Required configuration:

- registry must recognize factory;
- active guardians and supported assets must exist before vault creation.

### Adapters

Current adapters:

- `AaveV3Adapter`
- `CompoundV3Adapter`

Depend on:

- `StrategyRouter`;
- external protocol address (`Aave pool`, `Compound comet`).

Required configuration:

- allowlist adapter in `StrategyRouter`;
- risk manager must allow execution for asset;
- production interfaces should be used.

## Post-Deploy Configuration to Validate

The deployment script schedules/configures at least:

- `GuardianAdministrator.setBondEscrow(guardianBondEscrow)`;
- `VaultRegistry.setFactory(vaultFactory)`.

The following should be explicitly validated and, if missing, added to deployment or documented as intentionally handled by seed/governance:

- `Treasury.setProtocolCore(protocolCore)`;
- timelock proposer/executor/canceller role configuration for `DaoGovernor`;
- adapter allowlisting in `StrategyRouter`;
- risk manager asset/oracle configuration;
- supported vault assets in `ProtocolCore`;
- removal of deployer/admin roles after production handoff.

## Base Deployment vs Local Seed

The project has a local seeding script:

```text
script/local/SeedLocal.s.sol
```

This script appears to configure many local/demo states such as:

- mock actors;
- governance actors;
- timelock roles;
- risk manager configuration;
- admin wallet permissions;
- vault creation;
- deposits and economic activity;
- proposal states.

This is useful for frontend and local demo development, but it should not be confused with production deployment.

### Recommended Separation

| State | Purpose |
|---|---|
| Base deployment | Production-like deployment. Should have safe governance and minimal required configuration. |
| Local seeded deployment | Frontend/demo environment with users, guardians, vaults, balances, proposals, and mock integrations. |

Tests should cover both separately.

## Deployment Invariant Checklist

After `DeployInvestmentDao.s.sol`, assert:

- all addresses are non-zero;
- no duplicate critical addresses;
- `GovernanceToken` minter/admin roles are correct;
- `TimeLock` roles are correct;
- `DaoGovernor` can execute a proposal through `TimeLock`;
- `Treasury.protocolCore` is configured or intentionally unset with documented reason;
- `ProtocolCore` has expected supported assets;
- `RiskManager` is connected to `StrategyRouter`;
- `RiskManager` assets/oracles are configured if strategy execution is expected;
- `GuardianAdministrator.bondEscrow` is configured;
- `GuardianBondEscrow.guardianAdministrator` is configured;
- `VaultRegistry.factory` or `FACTORY_ROLE` is configured;
- `VaultFactory` dependencies are correct;
- `StrategyRouter` dependencies are correct;
- adapters are deployed;
- adapters are allowlisted if immediate investing is expected;
- deployer has renounced or lost unsafe roles in production deployment.

## Frontend Deployment Outputs

Because the project has a frontend, every deployment should generate or update:

- deployed contract addresses per network;
- ABIs;
- TypeScript SDK/helper exports;
- network configuration;
- local demo accounts if using Anvil;
- seeded balances and vaults for development.

Existing scripts that support this:

- `script/generate-abis.ts`
- `script/generate-addresses.ts`
- `script/generate-contracts-sdk.ts`
- `script/generate-helpers.ts`
- `script/contracts.config.ts`

## Recommended Deployment Documentation

Each network should have a documented deployment section:

```text
Network:
Chain ID:
RPC:
Deployer:
Timelock:
Governor:
GovernanceToken:
Treasury:
ProtocolCore:
RiskManager:
GuardianAdministrator:
GuardianBondEscrow:
VaultRegistry:
StrategyRouter:
VaultImplementation:
VaultFactory:
Adapters:
Post-deploy transactions:
Known limitations:
```

## Production Readiness Gate

Do not treat a deployment as production-ready until:

- deployment invariants pass;
- governance can execute a proposal;
- timelock roles are validated;
- treasury configuration is validated;
- at least one full vault lifecycle flow passes;
- adapter allowlist policy is explicit;
- risk manager is configured for deployed assets;
- frontend reads generated deployment artifacts correctly;
- deployer roles are removed or explicitly documented.
