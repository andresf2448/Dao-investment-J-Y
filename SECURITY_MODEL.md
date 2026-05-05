# Security Model

## Scope

This document describes the security assumptions, trusted roles, privileged actions, and main risk areas for the governance and vault protocol.

The protocol contains governance, treasury custody, guardian-based vault management, ERC4626 accounting, strategy routing, oracle/risk checks, and external protocol adapters. Because multiple contracts depend on each other, security depends on both individual contract correctness and correct deployment wiring.

## Core Security Goals

1. Users should be able to deposit and withdraw according to ERC4626 accounting.
2. Vault accounting should remain correct across strategy execution, divestment, and rebalancing.
3. Only active/approved guardians should create and manage vaults.
4. Only allowlisted adapters should move vault assets into external protocols.
5. Risk checks should block unsafe strategy execution.
6. Governance should control privileged protocol actions through timelock delay.
7. Treasury assets should only be withdrawable or sweepable by authorized roles.
8. Production deployment should not leave unsafe permissions with deployer or local admin accounts.

## Trusted Roles

| Role | Trust Assumption |
|---|---|
| DAO / Governor | Controls long-term configuration and protocol upgrades. Must be secured by voting and timelock. |
| Timelock | Executes privileged actions after delay. Must own/administer critical roles. |
| Guardian | Trusted to manage vault strategy within constraints, but should not be able to bypass risk controls or steal funds. |
| Keeper / Bot | Operational actor for rebalances. Should have limited permissions. |
| Emergency Role | Can pause critical flows. Should not be able to drain funds. |
| Manager Role | Configures protocol/risk parameters. Should be DAO/timelock-controlled in production. |
| Adapter | Trusted connector once allowlisted. Bugs here can affect vault funds. |
| Oracle / Price Feed | External dependency. Must be validated for heartbeat, stale data, decimals, and invalid rounds. |

## Privileged Actions

High-risk actions should be timelock/governance controlled in production:

- grant/revoke roles;
- upgrade contracts;
- pause/unpause protocol operations;
- set supported vault assets;
- add/remove genesis tokens;
- configure risk manager assets/oracles;
- allowlist adapters;
- change vault factory or registry configuration;
- set treasury protocol core;
- approve, ban, slash guardians;
- change fees/caps;
- change strategy router or adapter registry logic.

## Contract Risk Areas

## GovernanceToken

Risks:

- unauthorized minting;
- minting after finalization;
- incorrect voting power if delegation/checkpoints are misunderstood;
- admin/minter role not handed off correctly.

Controls:

- restrict minting to `MINTER_ROLE`;
- permanently block minting after finish;
- test role handoff to timelock/governance;
- test governance proposal threshold with delegated votes.

## DaoGovernor / TimeLock

Risks:

- governor unable to queue/execute due to missing timelock roles;
- deployer retaining timelock admin;
- executor misconfigured;
- governance unable to modify protocol configuration;
- governance bypass if roles are too permissive.

Controls:

- deployment invariant tests for timelock roles;
- governance end-to-end execution test;
- production deployment checklist;
- avoid local/admin roles in production.

## GenesisBonding

Risks:

- unsupported purchase token accepted;
- wrong mint rate;
- payment not reaching treasury;
- minting continues after finalization;
- protected assets swept accidentally.

Controls:

- test allowed token checks;
- test rate math;
- test treasury receipt;
- test finalization;
- test sweep restrictions.

## Treasury

Risks:

- `protocolCore` not configured;
- genesis/non-genesis asset classification broken;
- unauthorized withdrawal;
- native asset handling errors;
- treasury assets inaccessible due to misconfiguration.

Controls:

- deployment invariant for `setProtocolCore`;
- role tests for withdrawals/sweeps;
- integration with `GenesisBonding`;
- treasury accounting tests.

## ProtocolCore

Risks:

- unsupported assets allowed;
- supported assets blocked incorrectly;
- pause logic bypassed;
- emergency role overpowered;
- upgrade authorization too broad.

Controls:

- access-control unit tests;
- pause/unpause behavior tests;
- supported asset tests;
- deployment role invariants.

## GuardianAdministrator

Risks:

- guardian active without locked bond;
- duplicate or invalid applications;
- unauthorized approval;
- banned/resigned guardian remains active;
- slashing/refund inconsistencies.

Controls:

- lifecycle state-machine tests;
- escrow integration tests;
- governance/timelock approval tests;
- invariant that active guardians satisfy bonding/approval requirements.

## GuardianBondEscrow

Risks:

- unauthorized lock/refund/slash;
- bond accounting mismatch;
- slashing to wrong address;
- release more than locked.

Controls:

- access-control tests;
- stake balance accounting tests;
- slash/refund/release integration tests.

## VaultFactory

Risks:

- inactive guardian creates vault;
- unsupported asset vault created;
- duplicate vaults for same guardian/asset;
- clone not initialized correctly;
- registry not updated.

Controls:

- integration tests with guardian/core/registry;
- deployment invariant for factory dependencies;
- duplicate asset/guardian pair tests.

## VaultRegistry

Risks:

- fake vault registration;
- duplicate vaults;
- stale/inactive vault treated as active;
- incorrect query results.

Controls:

- factory-only registration;
- uniqueness tests;
- active/inactive tests;
- router checks against registry.

## VaultImplementation

Risks:

- broken ERC4626 accounting;
- incorrect `totalAssets` across adapter positions;
- strategy rotation causing assets to disappear from accounting;
- unauthorized strategy execution;
- withdrawal failure when funds are invested;
- fee share dilution;
- active adapter list mismatch.

Controls:

- deposit/withdraw lifecycle tests;
- strategy lifecycle integration tests;
- accounting invariants;
- fee accounting tests;
- active/retired adapter tests;
- emergency withdrawal/divest tests if design supports them.

## StrategyRouter

Risks:

- unregistered vault executes strategy;
- adapter not allowlisted but called;
- risk checks bypassed;
- malformed batch actions;
- duplicate adapter execution side effects;
- divest blocked during oracle failure when users need withdrawals.

Controls:

- allowlist tests;
- registered vault tests;
- risk manager mock/failure tests;
- batch action validation tests;
- explicit policy for divest behavior under risk failure.

## RiskManager

Risks:

- stale oracle data accepted;
- invalid price accepted;
- decimals mishandled;
- depeg bounds incorrect;
- execution not paused during risk event;
- unhealthy asset treated as healthy.

Controls:

- mock oracle tests;
- fuzz decimals and prices;
- heartbeat/stale tests;
- depeg tests;
- pause tests.

## Adapters

Risks:

- production adapter depends on test-only interface;
- external protocol balance reporting incorrect;
- approvals not reset or over-approved;
- external call reentrancy or unexpected token behavior;
- adapter keeps permissions after being removed;
- fork behavior differs from mocks.

Controls:

- no production import from `test/`;
- production interfaces;
- unit tests with mocks;
- fork tests against actual/external protocol behavior;
- role revocation/adapter retirement tests;
- external call failure tests.

## Frontend Risk Considerations

The frontend can create operational risk if it hides important state.

The UI should clearly show:

- whether the user is on a base deployment or seeded local environment;
- whether a guardian is active;
- whether an asset is supported;
- whether vault creation/deposit is paused;
- whether an adapter is allowlisted;
- whether risk manager considers the asset healthy;
- whether a proposal is pending, queued, executable, executed, defeated, or canceled;
- whether a transaction requires timelock execution.

The frontend must not assume that a contract is configured just because it has an address.

## Known Trust Assumptions

- Governance is trusted to act in the protocol's long-term interest.
- Timelock delay gives users and guardians time to react to governance changes.
- Guardians are semi-trusted operators but constrained by vault permissions, router allowlists, and risk checks.
- Adapters are high-trust modules once allowlisted.
- Oracles are external dependencies and require validation.
- External protocols may fail, change behavior, pause, or suffer market stress.

## Minimum Security Testing Before Public Demo

Before presenting this as a serious protocol, the project should include:

- deployment invariants;
- governance execution integration tests;
- guardian lifecycle integration tests;
- vault accounting tests;
- strategy lifecycle tests;
- risk manager oracle tests;
- adapter allowlist tests;
- invariant tests for funds and permissions;
- fork tests for adapters;
- frontend local demo state smoke tests.
