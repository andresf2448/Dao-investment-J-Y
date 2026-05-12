# DAO Investment J&Y

DAO Investment J&Y is a modular DeFi protocol built with Solidity and Foundry. The project models an investment DAO where governance controls protocol configuration, approved guardians create and manage ERC4626 vaults, and vault assets can be routed into external strategies through allowlisted adapters with oracle-based risk validation.

The repository is designed as a smart contract infrastructure project rather than a single contract demo. It includes governance, treasury custody, guardian onboarding, vault deployment, strategy execution, deployment scripts, local seeding, SDK generation, and a broad test suite covering unit, integration, invariant, and stateless/fuzz-style scenarios.

## What The Protocol Does

The protocol allows a DAO to coordinate capital allocation through controlled vault infrastructure.

At a high level:

1. Users can acquire governance tokens during the genesis phase.
2. Governance controls privileged protocol actions through a governor and timelock.
3. Guardians apply by locking a bond and must be approved before managing vaults.
4. Active guardians can create ERC4626 vaults for supported assets.
5. Investors deposit into vaults.
6. Guardians execute strategy allocations through a router.
7. The router only interacts with allowlisted adapters and checks risk conditions before investing.
8. Vault accounting tracks idle assets plus assets deployed through active adapters.

This makes the project useful as an example of how to design a permissioned but DAO-governed DeFi system with fund custody, role separation, strategy routing, and risk controls.

## Architecture

```text
Governance Token
      |
      v
DaoGovernor + TimeLock
      |
      v
ProtocolCore / Treasury / RiskManager
      |
      v
GuardianAdministrator + GuardianBondEscrow
      |
      v
VaultFactory + VaultRegistry
      |
      v
ERC4626 Vault Clones
      |
      v
StrategyRouter
      |
      v
Aave / Compound Adapters
```

## Main Components

### Governance

Contracts:

- `GovernanceToken`
- `DaoGovernor`
- `TimeLock`

The governance layer provides voting power, proposal creation, vote execution, and timelock-controlled administration. It is responsible for protocol-level decisions such as enabling assets, updating risk parameters, allowlisting adapters, and changing privileged configuration.

### Genesis And Treasury

Contracts:

- `GenesisBonding`
- `Treasury`

`GenesisBonding` handles the initial token distribution. Users buy governance tokens with allowed purchase assets, and the payment assets are sent to `Treasury`.

`Treasury` holds protocol funds and separates DAO-supported genesis assets from non-genesis assets using `ProtocolCore`.

### Core Protocol Configuration

Contract:

- `ProtocolCore`

`ProtocolCore` manages supported vault assets, supported genesis tokens, global vault creation pause state, global deposit pause state, and privileged manager/emergency roles.

### Guardians

Contracts:

- `GuardianAdministrator`
- `GuardianBondEscrow`

Guardians are strategy managers. They must apply, lock bond collateral, and be approved through governance/timelock-controlled flows before they can create or manage vaults.

Guardian lifecycle:

```text
Inactive -> Pending -> Active
                  |-> Rejected
Active   -> Resigned
Active   -> Banned
```

`GuardianBondEscrow` locks, refunds, releases, or slashes guardian bonds depending on lifecycle events.

### Vault Infrastructure

Contracts:

- `VaultFactory`
- `VaultRegistry`
- `VaultImplementation`

`VaultFactory` deploys deterministic ERC4626 vault clones. It checks that the caller is an active guardian, the asset is supported, and vault creation is not paused.

`VaultRegistry` stores canonical vault records, guardian/asset relationships, vault activity status, and query indexes.

`VaultImplementation` is the ERC4626 vault logic used by clones. It supports deposits, withdrawals, strategy execution, divestment, adapter tracking, and total asset accounting.

### Strategy Execution

Contracts:

- `StrategyRouter`
- `RiskManager`
- `AaveV3Adapter`
- `CompoundV3Adapter`

`StrategyRouter` is the execution gateway between vaults and external strategy adapters. It validates that:

- the caller is the vault;
- the vault is active in the registry;
- adapters are allowlisted;
- allocations are valid;
- risk checks pass before investment.

`RiskManager` validates oracle data, heartbeat freshness, price normalization, stable asset depeg bounds, and global execution pause state.

Adapters abstract external protocols. The current implementation includes Aave V3 and Compound V3 style adapters with mocks for local testing.

## Technology Stack

Smart contract stack:

- Solidity `0.8.30`
- Foundry
- OpenZeppelin Contracts
- OpenZeppelin Upgradeable Contracts
- Chainlink Aggregator interfaces
- ERC20Votes governance
- OpenZeppelin Governor + TimelockController
- ERC4626 vault standard
- ERC1967 / UUPS upgradeable patterns
- Minimal proxy vault clones

Tooling:

- Foundry tests, scripts, coverage, and deployment tooling
- TypeScript SDK generation
- pnpm
- Slither and Aderyn security analysis
- Local Anvil deployment and seeding scripts

## Tools Used In This Project

The project combines protocol engineering tools, deployment automation, testing infrastructure, and documentation practices commonly used in professional Solidity development.

| Area | Tools / Libraries | Purpose |
|---|---|---|
| Smart contracts | Solidity `0.8.30` | Main language for protocol contracts. |
| Development framework | Foundry | Build, test, fuzz, invariant testing, coverage, and deployment scripts. |
| Governance | OpenZeppelin Governor, ERC20Votes, TimelockController | DAO voting, delegated voting power, proposal execution, and delayed privileged actions. |
| Token and access control | OpenZeppelin ERC20, AccessControl, SafeERC20 | Standard token behavior, role-based permissions, and safe token transfers. |
| Upgradeability | OpenZeppelin Upgradeable, ERC1967, UUPS | Upgradeable protocol components with initializer-based deployment. |
| Vault standard | ERC4626 | Standardized vault deposits, withdrawals, shares, and asset accounting. |
| Clone deployment | OpenZeppelin Clones | Deterministic minimal proxy vault deployment. |
| Oracle integration | Chainlink AggregatorV3Interface | Price validation, heartbeat checks, stale price detection, and decimal normalization. |
| External protocols | Aave V3-style adapter, Compound V3-style adapter | Strategy adapter abstraction for external yield venues. |
| Static analysis | Slither | Detector-based Solidity analysis for access control, reentrancy, initialization, low-level calls, and common vulnerability patterns. |
| Security review | Aderyn | Solidity-focused security analysis used as an additional review layer alongside manual review and tests. |
| Local network | Anvil | Local blockchain used for deployment, seeding, and integration flows. |
| SDK generation | TypeScript + `tsx` | Generates frontend/consumer-friendly contract SDK artifacts. |
| Coverage reports | `forge coverage`, `lcov`, `genhtml` | Produces terminal and HTML coverage reports. |

## Functional Flow

The protocol is designed around a full DAO-controlled investment lifecycle. This section explains the system from deployment to user withdrawals in a way that maps business behavior to the smart contract infrastructure.

### 1. Protocol Deployment And Bootstrap

The deployment flow starts with `DeployInvestmentDao.s.sol`. It deploys the protocol in dependency order because most contracts depend on previously deployed infrastructure.

Main sequence:

1. Deploy `TimeLock`.
2. Deploy `GovernanceToken`.
3. Deploy `Treasury` and `GenesisBonding`.
4. Deploy `DaoGovernor`.
5. Deploy `ProtocolCore` and `RiskManager`.
6. Deploy `GuardianAdministrator` and `GuardianBondEscrow`.
7. Deploy `VaultRegistry`, `StrategyRouter`, `VaultImplementation`, and `VaultFactory`.
8. Deploy strategy adapters.
9. Configure protocol defaults and generate deployment artifacts.

The purpose of this phase is to leave the protocol wired with the correct dependencies, roles, and initial configuration. The deployment tests validate that critical addresses are non-zero, timelock roles are assigned, the governor can execute privileged calls, the vault registry recognizes the factory, and deployed components point to the expected dependencies.

### 2. Genesis Token Distribution

Users can acquire governance tokens through `GenesisBonding`.

Flow:

1. A user receives or holds an allowed purchase token.
2. The user approves `GenesisBonding`.
3. The user calls `buy(token, amount)`.
4. The purchase token is transferred to `Treasury`.
5. `GovernanceToken` is minted to the buyer according to the configured rate.
6. Once the bootstrap phase ends, `finalize()` disables future minting.

This tests the economic bootstrap path: accepted assets, payment custody, minting permissions, finalization, and sweep restrictions.

### 3. DAO Governance

Governance is implemented with `GovernanceToken`, `DaoGovernor`, and `TimeLock`.

Flow:

1. Token holders delegate voting power.
2. A proposal is created.
3. Voters cast votes during the voting period.
4. A successful proposal is queued in the timelock.
5. After the delay, the proposal is executed.
6. The target protocol state changes, for example enabling a new vault asset in `ProtocolCore`.

This validates that the DAO is not only deployed, but operational. The integration tests include a real proposal lifecycle that executes a privileged protocol configuration change.

### 4. Guardian Onboarding

Guardians are approved strategy operators. They cannot manage vaults by default.

Flow:

1. A candidate approves the bond token to `GuardianBondEscrow`.
2. The candidate calls `applyGuardian()` on `GuardianAdministrator`.
3. The escrow locks the required bond.
4. `GuardianAdministrator` creates a governance proposal for approval.
5. Governance/timelock approves the candidate.
6. The guardian becomes active.
7. An active guardian can later resign and recover the bond, or be banned and slashed by timelock-controlled action.

This models a controlled operator onboarding process. The test suite covers successful approval, rejection resolution, resignation, banning, slashing, and invalid lifecycle transitions.

### 5. Vault Creation

Only active guardians can create vaults.

Flow:

1. `ProtocolCore` marks an asset as supported.
2. An active guardian calls `VaultFactory.createVault(asset, name, symbol)`.
3. `VaultFactory` checks guardian status through `GuardianAdministrator`.
4. `VaultFactory` checks asset support and creation pause state through `ProtocolCore`.
5. A deterministic ERC4626 clone is deployed from `VaultImplementation`.
6. The clone is initialized with asset, guardian, factory, router, core, and admin references.
7. `VaultRegistry` records the new vault and indexes it by guardian and asset.

This prevents inactive guardians, unsupported assets, duplicate guardian/asset vault pairs, and unregistered vaults from participating in strategy execution.

### 6. User Deposit And Strategy Allocation

Once a vault exists, users can deposit assets using ERC4626 flows.

Flow:

1. The investor approves the vault.
2. The investor deposits assets into the ERC4626 vault.
3. The vault mints shares to the investor.
4. The guardian proposes a strategy allocation across adapters.
5. The vault forwards execution to `StrategyRouter`.
6. `StrategyRouter` validates the vault, adapter allowlist, allocation arrays, and risk state.
7. The selected adapter moves assets into the external strategy mock or protocol interface.

The strategy lifecycle tests validate deposit, invest, accounting, withdrawal, divestment, and rebalance behavior.

### 7. Risk Validation Before Investment

`RiskManager` is consulted before investment execution.

Validation includes:

- asset enabled status;
- oracle feed configured;
- positive price;
- valid Chainlink round data;
- heartbeat freshness;
- decimal normalization to 18 decimals;
- stable asset depeg bounds;
- global execution pause state.

If risk validation fails, investment is blocked. Divestment remains separately available so a vault can recover assets even when new investment is unsafe.

### 8. Withdrawals And Accounting

When users withdraw:

1. The vault checks idle liquidity.
2. If idle assets are sufficient, the withdrawal is served directly.
3. If idle liquidity is insufficient, the vault divests from active adapters.
4. The user receives assets according to ERC4626 share accounting.
5. The vault can rebalance remaining idle funds according to active allocation state.

The invariant suite repeatedly exercises deposits, withdrawals, investments, and divestments to ensure `totalAssets()` remains consistent with idle assets plus adapter-reported assets.

## Repository Structure

```text
contracts/
  adapters/          External protocol adapters
  bootstrap/         Genesis token distribution
  core/              Protocol configuration and treasury
  execution/         Strategy routing and risk checks
  governance/        DAO token, governor, timelock
  guardians/         Guardian lifecycle and bond escrow
  vaults/            Factory, registry, ERC4626 implementation

script/
  deploy/            Deployment scripts
  local/             Local seed script

test/
  unit/              Contract-level tests
  integration/       End-to-end protocol flow tests
  invariant/         Stateful invariant tests
  stateless/         Stateless/fuzz-style validation tests
  mocks/             Local testing mocks

contracts-sdk/       Generated contract SDK artifacts
deployments/         Deployment outputs
frontend/            Frontend workspace
```

## Tests Implemented

The test suite is organized by risk and responsibility.

Current test organization:

```text
test/unit/           Isolated contract behavior and revert paths
test/integration/    Multi-contract business flows
test/invariant/      Stateful accounting invariants
test/stateless/      Stateless/fuzz-style validation
test/mocks/          Mocks for tokens, oracles, adapters, registries, and routers
```

### Unit Tests

Unit tests cover contract-level permissions, validation, state changes, and revert paths.

Examples:

- governance token minting and finalization;
- treasury withdrawal and sweep rules;
- genesis bonding purchase/finalization/sweep behavior;
- guardian administrator lifecycle;
- bond escrow lock/refund/release/slash behavior;
- protocol core pause and asset configuration;
- risk manager oracle validation;
- strategy router allocation checks;
- Aave and Compound adapter execution;
- vault factory deterministic deployment;
- vault registry indexing and deactivation;
- vault implementation authorization, strategy allocation, and adapter status.

Representative files:

- `test/unit/core/ProtocolCoreUnitTest.t.sol`
- `test/unit/core/TreasuryUnitTest.t.sol`
- `test/unit/execution/RiskManagerUnitTest.t.sol`
- `test/unit/execution/StrategyRouterUnitTest.t.sol`
- `test/unit/vaults/VaultImplementationUnitTest.t.sol`
- `test/unit/adapters/AaveV3AdapterUnitTest.t.sol`
- `test/unit/adapters/CompoundV3AdapterUnitTest.t.sol`

### Integration Tests

Integration tests validate complete business flows across multiple contracts.

Implemented flows:

- deployment wiring and role checks;
- governance proposal, vote, queue, and execute flow;
- genesis bonding purchase into treasury;
- guardian onboarding through governance/timelock;
- active guardian vault creation;
- strategy lifecycle: deposit, invest, divest, withdraw, and rebalance.

Representative files:

- `test/integration/DeployInvestmentDaoTest.t.sol`
- `test/integration/governance/GovernanceExecutionFlowTest.t.sol`
- `test/integration/bootstrap/GenesisTreasuryFlowTest.t.sol`
- `test/integration/guardians/GuardianOnboardingFlowTest.t.sol`
- `test/integration/vaults/VaultCreationFlowTest.t.sol`
- `test/integration/strategies/StrategyLifecycleFlowTest.t.sol`

### Invariant Tests

Invariant tests focus on vault accounting.

Implemented invariants:

- `totalAssets()` matches idle vault balance plus adapter-managed assets;
- total shares do not exceed total assets in the no-yield mock environment;
- repeated deposits, withdrawals, investments, and divestments preserve accounting consistency.

Representative file:

- `test/invariant/VaultAccountingInvariant.t.sol`

### Stateless / Fuzz-Style Tests

Stateless tests validate price normalization and oracle behavior across input ranges.

Examples:

- Chainlink price normalization for feeds with decimals below, equal to, and above 18;
- stale price rejection;
- invalid round rejection;
- paused execution health behavior.

Representative file:

- `test/stateless/execution/RiskManagerStatelessTest.t.sol`

## Testing Strategy

The test suite was built around the protocol's highest-risk surfaces rather than only aiming for line coverage.

Main testing goals:

- prove deployment wiring leaves the protocol usable;
- prove governance can execute real privileged actions;
- prove treasury funds are classified and withdrawn through correct roles;
- prove guardians cannot bypass lifecycle approval;
- prove only active guardians can create vaults;
- prove vault deposits and withdrawals follow ERC4626 accounting;
- prove strategy execution passes through router, allowlist, registry, and risk checks;
- prove adapter accounting is included in `totalAssets()`;
- prove oracle and depeg checks block unsafe investment;
- prove repeated state transitions do not break vault accounting.

This gives the repository a security-oriented test profile that is closer to protocol engineering practice than a simple happy-path demo.

## Coverage

Coverage can be generated with:

```bash
forge coverage --ir-minimum
```

The project uses `--ir-minimum` because plain `forge coverage` can hit a Solidity `stack too deep` issue when compiling deployment scripts for coverage.

Important production contracts currently have strong coverage, including:

- adapters: 100% line coverage for Aave and Compound adapters;
- core: high coverage on `ProtocolCore` and `Treasury`;
- execution: broad coverage for `RiskManager` and `StrategyRouter`;
- guardians: lifecycle and escrow behavior covered;
- vaults: factory, registry, implementation, strategy lifecycle, and accounting invariants covered.

Some deployment and local seed scripts are intentionally heavier and may lower total repository coverage if included in the global report.

## Security Analysis

Security work was approached from several layers instead of relying on a single tool.

Implemented security practices:

- Slither static analysis with a dedicated `slither.config.json` configuration.
- Aderyn security analysis as an additional automated review pass.
- Unit tests for role boundaries, zero-address checks, invalid state transitions, and revert paths.
- Integration tests for real protocol flows where several contracts must work together.
- Invariant tests focused on vault accounting and asset conservation across repeated operations.
- Stateless/fuzz-style tests for oracle normalization, stale prices, invalid rounds, and paused execution behavior.
- Deployment invariant tests for role handoff, timelock permissions, registry/factory wiring, and adapter configuration.

Main security areas reviewed:

- governance and timelock authorization;
- deployer role handoff;
- guardian approval, resignation, banning, and slashing;
- treasury asset classification and withdrawal permissions;
- ERC4626 vault accounting;
- adapter allowlisting;
- risk manager oracle validation;
- strategy execution routing;
- pause and emergency controls.

## Local Development

Install dependencies:

```bash
forge install
pnpm install
```

Build:

```bash
forge build
```

Run tests:

```bash
forge test
```

Run coverage:

```bash
forge coverage --ir-minimum
```

Generate HTML coverage report:

```bash
forge coverage --ir-minimum --report lcov
genhtml lcov.info --output-directory coverage
xdg-open coverage/index.html
```

## Local Deployment

Start Anvil in another terminal:

```bash
anvil
```

Deploy locally:

```bash
make s_deployLocal
```

Seed local protocol state:

```bash
make s_seedLocal
```

Run both:

```bash
make s_bootstrapLocal
```

The deployment scripts generate deployment artifacts in `deployments/` and regenerate the local `contracts-sdk`.

## Example Use Case

This project demonstrates how a DAO could manage investment vault infrastructure with multiple layers of control.

For example:

1. The DAO deploys the protocol.
2. Users acquire governance tokens during the genesis phase.
3. A guardian applies and locks a bond.
4. Governance approves the guardian.
5. The guardian creates a vault for a supported asset.
6. Investors deposit into the vault.
7. The guardian allocates vault capital into an Aave or Compound strategy.
8. The router checks adapter allowlists and risk conditions before executing.
9. Users can withdraw, and the vault divests if idle liquidity is insufficient.

The design shows practical Solidity patterns for governance-controlled DeFi infrastructure, access control, asset custody, and accounting safety.

## Security Notes

This repository represents a client-oriented DeFi protocol implementation with a security-focused development process. The codebase combines automated analysis, manual review, and a broad Foundry test suite to validate core behavior before deployment operations.

Important security themes covered by the code and tests:

- governance/timelock role handoff;
- no unsafe deployer permissions after production handoff;
- guardian lifecycle and bond enforcement;
- vault accounting during strategy execution;
- adapter allowlisting;
- oracle freshness and stable asset depeg checks;
- treasury asset classification;
- pause controls for emergency response.

## Why This Project Matters

For technical reviewers, this repository demonstrates:

- multi-contract protocol architecture;
- governance and timelock integration;
- ERC4626 vault design;
- deterministic clone deployment;
- upgradeable contract initialization;
- oracle-driven risk validation;
- strategy adapter abstraction;
- Foundry testing beyond simple unit tests.

For recruiters, this project highlights experience with:

- Solidity protocol engineering;
- DeFi architecture;
- security-oriented testing;
- deployment automation;
- role-based access control;
- technical documentation;
- professional repository organization.
