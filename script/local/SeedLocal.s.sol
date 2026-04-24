// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../deploy/HelperConfig.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";
import {DaoGovernor} from "../../contracts/governance/DaoGovernor.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";
import {ProtocolCore} from "../../contracts/core/ProtocolCore.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {MockERC20} from "../../test/mocks/MockERC20.sol";
import {GenesisBonding} from "../../contracts/bootstrap/GenesisBonding.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {GuardianBondEscrow} from "../../contracts/guardians/GuardianBondEscrow.sol";
import {VaultFactory} from "../../contracts/vaults/factory/VaultFactory.sol";
import {VaultRegistry} from "../../contracts/vaults/registry/VaultRegistry.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract SeedLocal is Script {
  // -------------------------------------------------------------------------
  // Seed configuration
  // -------------------------------------------------------------------------
  // This script is intentionally opinionated for Anvil only:
  // - it enriches the local environment with extra assets and actors
  // - it grants broad local testing permissions to the admin wallet from .env
  // - it creates observable protocol activity and governance proposal states
  // - it persists a local-only JSON snapshot consumed by frontend/dev tooling

  // ETH buffer used to fund every seeded account so they can sign transactions on local Anvil.
  uint256 constant GAS_BUFFER = 1 ether;
  uint256 constant BLOCK_ADVANCER_PRIVATE_KEY =
    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  // Bond required by GuardianAdministrator / GuardianBondEscrow for guardian applications.
  uint256 constant GUARDIAN_BOND = 100e18;

  // Economic activity seeded for GenesisBonding and vault deposits.
  uint256 constant INVESTOR1_PRIMARY_GVT_BUY = 50e18;
  uint256 constant INVESTOR2_SECONDARY_GVT_BUY = 30e18;
  uint256 constant INVESTOR1_PRIMARY_DEPOSIT = 10e18;
  uint256 constant INVESTOR2_PRIMARY_DEPOSIT = 5e18;
  uint256 constant INVESTOR2_SECONDARY_DEPOSIT = 7e18;

  // Governance balances large enough to comfortably exceed proposal threshold and quorum in local demos.
  uint256 constant GOVERNANCE_ACTOR_MINT = 100_000e18;
  uint256 constant BLOCK_TIME = 12;
  uint8 constant VOTE_AGAINST = 0;
  uint8 constant VOTE_FOR = 1;

  bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
  bytes32 constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
  bytes32 constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
  bytes32 constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
  bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 constant SWEEP_ROLE = keccak256("SWEEP_ROLE");
  bytes32 constant SWEEP_NOT_ASSET_DAO_ROLE = keccak256("SWEEP_NOT_ASSET_DAO_ROLE");
  bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
  bytes32 constant GUARDIAN_ADMINISTRATOR_ROLE = keccak256("GUARDIAN_ADMINISTRATOR_ROLE");
  bytes32 constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
  bytes32 constant ADAPTER_MANAGER_ROLE = keccak256("ADAPTER_MANAGER_ROLE");
  bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
  bytes32 constant STRATEGY_EXECUTOR_ROLE = keccak256("STRATEGY_EXECUTOR_ROLE");

  // Generic actor representation used for every seeded account.
  // The label helps traces and logs stay readable during local debugging.
  struct Participant {
    address addr;
    uint256 privateKey;
    string label;
  }

  // Canonical addresses loaded from deployments/anvil.json.
  // These come from the main deployment flow and are the base dependencies for the seed.
  struct Contracts {
    address timeLock;
    address daoGovernor;
    address guardianAdministrator;
    address guardianBondEscrow;
    address genesisBonding;
    address vaultFactory;
    address governanceToken;
    address treasury;
    address protocolCore;
    address riskManager;
    address vaultRegistry;
    address strategyRouter;
    address primaryToken;
  }

  // Full local cast of accounts used by the seed.
  // We keep groups separated so the resulting state is easier to reason about:
  // guardians, investors and governance-only actors.
  struct Participants {
    Participant guardian1;
    Participant guardian2;
    Participant adminGuardian;
    Participant investor1;
    Participant investor2;
    Participant proposerPending;
    Participant proposerActive;
    Participant proposerCanceled;
    Participant proposerDefeated;
    Participant proposerSucceeded;
    Participant proposerQueued;
    Participant proposerExecuted;
    Participant voter1;
    Participant voter2;
    Participant voter3;
  }

  // Vault topology generated by the seed.
  struct VaultSeeds {
    address guardian1PrimaryVault;
    address guardian2PrimaryVault;
    address guardian1SecondaryVault;
  }

  // Proposal ids generated during the seed.
  // We store both guardian onboarding proposals and the governance demo proposals.
  struct ProposalSeeds {
    uint256 guardian1Application;
    uint256 guardian2Application;
    uint256 adminGuardianApplication;
    uint256 governorProposalCountBeforeDemo;
    uint256 governorProposalCountAfterDemo;
    uint256 pending;
    uint256 active;
    uint256 canceled;
    uint256 defeated;
    uint256 succeeded;
    uint256 queued;
    uint256 executed;
  }

  function run() external {
    require(block.chainid == 31337, "SeedLocal only supports Anvil");

    // SeedLocal intentionally depends on the output of the deployment step.
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
    Contracts memory contracts = _loadContracts();
    Participants memory participants = _buildParticipants(vm.envUint("ADMIN_WALLET_ANVIL_PRIVATE_KEY"));

    console.log("========================================");
    console.log("Running Local Seed");
    console.log("========================================");

    // 1. Prepare accounts and admin access.
    _fundParticipants(networkConfig.deployerPrivateKey, participants);
    _grantAdminWalletFullAccess(
      networkConfig.deployerPrivateKey,
      participants.adminGuardian.addr,
      contracts.timeLock,
      contracts.governanceToken,
      contracts.treasury,
      contracts.protocolCore,
      contracts.riskManager,
      contracts.guardianAdministrator,
      contracts.guardianBondEscrow,
      contracts.vaultRegistry,
      contracts.strategyRouter,
      contracts.genesisBonding,
      contracts.vaultFactory
    );
    _grantGovernorTimelockRoles(participants.adminGuardian.privateKey, contracts.timeLock, contracts.daoGovernor);

    // 2. Extend the local asset universe with a second mock token.
    address secondaryToken = _loadOrDeploySecondaryToken(networkConfig.deployerPrivateKey);
    _configureAdditionalAssets(participants.adminGuardian.privateKey, contracts, secondaryToken);
    _mintSeedAssets(networkConfig.deployerPrivateKey, contracts, participants, secondaryToken);

    // 3. Activate guardians and create the local vault topology.
    ProposalSeeds memory proposalSeeds = _activateGuardians(networkConfig.deployerPrivateKey, contracts, participants);
    VaultSeeds memory vaultSeeds = _createVaults(networkConfig.deployerPrivateKey, contracts, participants, secondaryToken);

    // 4. Seed user activity and governance actors.
    _seedEconomicActivity(participants, contracts, vaultSeeds, secondaryToken);
    _mintAndDelegateGovernanceActors(participants.adminGuardian.privateKey, contracts.governanceToken, participants);

    // 5. Create demo governance proposals in different observable states.
    proposalSeeds.governorProposalCountBeforeDemo = DaoGovernor(payable(contracts.daoGovernor)).proposalCount();
    _seedProposalStates(participants, contracts, secondaryToken, proposalSeeds);
    proposalSeeds.governorProposalCountAfterDemo = DaoGovernor(payable(contracts.daoGovernor)).proposalCount();

    // 6. Validate, log and persist the final seeded state.
    _validateSeed(contracts, participants, vaultSeeds, proposalSeeds, secondaryToken);
    _logSeed(contracts, participants, vaultSeeds, proposalSeeds, secondaryToken);
    _writeSeedJson(contracts, participants, proposalSeeds, secondaryToken);
  }

  // Read every deployed dependency from deployments/anvil.json.
  // This script assumes the deploy step already ran successfully.
  function _loadContracts() internal view returns (Contracts memory contracts) {
    // Load the canonical deployment addresses produced by DeployInvestmentDao.
    string memory json = vm.readFile("deployments/anvil.json");

    contracts = Contracts({
      timeLock: abi.decode(vm.parseJson(json, ".timeLock"), (address)),
      daoGovernor: abi.decode(vm.parseJson(json, ".daoGovernor"), (address)),
      guardianAdministrator: abi.decode(vm.parseJson(json, ".guardianAdministrator"), (address)),
      guardianBondEscrow: abi.decode(vm.parseJson(json, ".guardianBondEscrow"), (address)),
      genesisBonding: abi.decode(vm.parseJson(json, ".genesisBonding"), (address)),
      vaultFactory: abi.decode(vm.parseJson(json, ".vaultFactory"), (address)),
      governanceToken: abi.decode(vm.parseJson(json, ".governanceToken"), (address)),
      treasury: abi.decode(vm.parseJson(json, ".treasury"), (address)),
      protocolCore: abi.decode(vm.parseJson(json, ".protocolCore"), (address)),
      riskManager: abi.decode(vm.parseJson(json, ".riskManager"), (address)),
      vaultRegistry: abi.decode(vm.parseJson(json, ".vaultRegistry"), (address)),
      strategyRouter: abi.decode(vm.parseJson(json, ".strategyRouter"), (address)),
      primaryToken: address(
        GuardianBondEscrow(
          abi.decode(vm.parseJson(json, ".guardianBondEscrow"), (address))
        ).guardianApplicationToken()
      )
    });
  }

  // Build the complete set of actors used by the seed.
  // The admin guardian is not generated here; it must be the wallet configured in .env
  // so the developer can manually interact with the protocol after seeding.
  function _buildParticipants(uint256 adminWalletPrivateKey) internal returns (Participants memory participants) {
    // The generated labels make the seeded actors deterministic and easier to identify in traces.
    participants.guardian1 = _participantFromGeneratedKey("seed-guardian-1", "guardian1");
    participants.guardian2 = _participantFromGeneratedKey("seed-guardian-2", "guardian2");
    participants.adminGuardian = Participant({
      addr: vm.addr(adminWalletPrivateKey),
      privateKey: adminWalletPrivateKey,
      label: "adminGuardian"
    });

    participants.investor1 = _participantFromGeneratedKey("seed-investor-1", "investor1");
    participants.investor2 = _participantFromGeneratedKey("seed-investor-2", "investor2");

    participants.proposerPending = _participantFromGeneratedKey("seed-proposer-pending", "proposerPending");
    participants.proposerActive = _participantFromGeneratedKey("seed-proposer-active", "proposerActive");
    participants.proposerCanceled = _participantFromGeneratedKey("seed-proposer-canceled", "proposerCanceled");
    participants.proposerDefeated = _participantFromGeneratedKey("seed-proposer-defeated", "proposerDefeated");
    participants.proposerSucceeded = _participantFromGeneratedKey("seed-proposer-succeeded", "proposerSucceeded");
    participants.proposerQueued = _participantFromGeneratedKey("seed-proposer-queued", "proposerQueued");
    participants.proposerExecuted = _participantFromGeneratedKey("seed-proposer-executed", "proposerExecuted");

    participants.voter1 = _participantFromGeneratedKey("seed-voter-1", "voter1");
    participants.voter2 = _participantFromGeneratedKey("seed-voter-2", "voter2");
    participants.voter3 = _participantFromGeneratedKey("seed-voter-3", "voter3");
  }

  // Generate deterministic local accounts from a label.
  // Reusing the same label always produces the same account in local script runs.
  function _participantFromGeneratedKey(string memory keyLabel, string memory participantLabel)
    internal
    returns (Participant memory participant)
  {
    (address addr, uint256 privateKey) = makeAddrAndKey(keyLabel);
    participant = Participant({addr: addr, privateKey: privateKey, label: participantLabel});
  }

  // Every account that signs transactions later must have ETH first.
  // This avoids random failures when the seed starts broadcasting from many actors.
  function _fundParticipants(uint256 deployerPrivateKey, Participants memory participants) internal {
    _fundAccount(deployerPrivateKey, participants.adminGuardian.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.guardian1.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.guardian2.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.investor1.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.investor2.addr, GAS_BUFFER);

    _fundAccount(deployerPrivateKey, participants.proposerPending.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.proposerActive.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.proposerCanceled.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.proposerDefeated.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.proposerSucceeded.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.proposerQueued.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.proposerExecuted.addr, GAS_BUFFER);

    _fundAccount(deployerPrivateKey, participants.voter1.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.voter2.addr, GAS_BUFFER);
    _fundAccount(deployerPrivateKey, participants.voter3.addr, GAS_BUFFER);
  }

  // Deploy the second local asset used to enrich GenesisBonding and vault coverage.
  function _loadOrDeploySecondaryToken(uint256 deployerPrivateKey) internal returns (address secondaryToken) {
    if (vm.exists("deployments/anvil-seed.json")) {
      string memory seedJson = vm.readFile("deployments/anvil-seed.json");
      secondaryToken = abi.decode(vm.parseJson(seedJson, ".secondaryGenesisToken"), (address));

      if (secondaryToken != address(0) && secondaryToken.code.length > 0) {
        return secondaryToken;
      }
    }

    vm.startBroadcast(deployerPrivateKey);
    secondaryToken = address(new MockERC20());
    vm.stopBroadcast();
  }

  function _configureAdditionalAssets(uint256 adminWalletPrivateKey, Contracts memory contracts, address secondaryToken)
    internal
  {
    // The second token is enabled everywhere it must be usable in local UX:
    // ProtocolCore genesis tokens, ProtocolCore vault assets and GenesisBonding purchase tokens.
    address[] memory allowedGenesisTokens = new address[](2);
    allowedGenesisTokens[0] = contracts.primaryToken;
    allowedGenesisTokens[1] = secondaryToken;

    vm.startBroadcast(adminWalletPrivateKey);
    ProtocolCore(contracts.protocolCore).setSupportedGenesisTokens(allowedGenesisTokens);
    ProtocolCore(contracts.protocolCore).setSupportedVaultAsset(secondaryToken, true);
    GenesisBonding(contracts.genesisBonding).setPurchaseTokens(allowedGenesisTokens);
    vm.stopBroadcast();
  }

  // Mint the exact balances needed for:
  // - guardian bonds
  // - governance token purchases through GenesisBonding
  // - deposits into the seeded vaults
  function _mintSeedAssets(
    uint256 deployerPrivateKey,
    Contracts memory contracts,
    Participants memory participants,
    address secondaryToken
  ) internal {
    _mintToken(deployerPrivateKey, contracts.primaryToken, participants.guardian1.addr, GUARDIAN_BOND);
    _mintToken(deployerPrivateKey, contracts.primaryToken, participants.guardian2.addr, GUARDIAN_BOND);
    _mintToken(deployerPrivateKey, contracts.primaryToken, participants.adminGuardian.addr, GUARDIAN_BOND);

    _mintToken(
      deployerPrivateKey,
      contracts.primaryToken,
      participants.investor1.addr,
      INVESTOR1_PRIMARY_GVT_BUY + INVESTOR1_PRIMARY_DEPOSIT
    );
    _mintToken(
      deployerPrivateKey,
      contracts.primaryToken,
      participants.investor2.addr,
      INVESTOR2_PRIMARY_DEPOSIT
    );
    _mintToken(
      deployerPrivateKey,
      secondaryToken,
      participants.investor2.addr,
      INVESTOR2_SECONDARY_GVT_BUY + INVESTOR2_SECONDARY_DEPOSIT
    );
  }

  // Activate all guardians that should exist in the local environment.
  // The returned proposal ids come from GuardianAdministrator onboarding proposals.
  function _activateGuardians(
    uint256 deployerPrivateKey,
    Contracts memory contracts,
    Participants memory participants
  ) internal returns (ProposalSeeds memory proposalSeeds) {
    proposalSeeds.guardian1Application = _activateGuardian(
      deployerPrivateKey,
      participants.guardian1,
      contracts.primaryToken,
      contracts.guardianBondEscrow,
      contracts.guardianAdministrator,
      contracts.timeLock
    );
    proposalSeeds.guardian2Application = _activateGuardian(
      deployerPrivateKey,
      participants.guardian2,
      contracts.primaryToken,
      contracts.guardianBondEscrow,
      contracts.guardianAdministrator,
      contracts.timeLock
    );
    proposalSeeds.adminGuardianApplication = _activateGuardian(
      deployerPrivateKey,
      participants.adminGuardian,
      contracts.primaryToken,
      contracts.guardianBondEscrow,
      contracts.guardianAdministrator,
      contracts.timeLock
    );
  }

  function _activateGuardian(
    uint256 deployerPrivateKey,
    Participant memory guardian,
    address bondToken,
    address guardianBondEscrow,
    address guardianAdministrator,
    address timeLock
  ) internal returns (uint256 proposalId) {
    GuardianAdministrator administrator = GuardianAdministrator(guardianAdministrator);

    if (administrator.isActiveGuardian(guardian.addr)) {
      return administrator.getGuardianDetail(guardian.addr).proposalId;
    }

    try administrator.getGuardianDetail(guardian.addr) returns (GuardianAdministrator.GuardianDetail memory detail) {
      proposalId = detail.proposalId;

      if (detail.status == GuardianAdministrator.Status.Pending) {
        _approveGuardianViaTimelock(deployerPrivateKey, guardian.addr, guardianAdministrator, timeLock);
        return proposalId;
      }

      revert("SeedLocal unsupported guardian state");
    } catch {
      // No existing guardian record. Continue with the fresh application flow below.
    }

    // Governor snapshots past votes, so we move one block before each guardian application.
    _advanceBlocks(1);

    vm.startBroadcast(guardian.privateKey);
    MockERC20(bondToken).approve(guardianBondEscrow, GUARDIAN_BOND);
    administrator.applyGuardian();
    vm.stopBroadcast();

    // GuardianAdministrator stores the onboarding proposal generated by applyGuardian().
    proposalId = administrator.getGuardianDetail(guardian.addr).proposalId;

    _approveGuardianViaTimelock(deployerPrivateKey, guardian.addr, guardianAdministrator, timeLock);
  }

  function _approveGuardianViaTimelock(
    uint256 deployerPrivateKey,
    address guardian,
    address guardianAdministrator,
    address timeLock
  ) internal {
    bytes32 salt = keccak256(abi.encodePacked("seed-local-guardian-approve", guardian));
    bytes memory data = abi.encodeCall(GuardianAdministrator.guardianApprove, (guardian));
    bytes32 predecessor = bytes32(0);

    vm.startBroadcast(deployerPrivateKey);
    TimeLock(payable(timeLock)).schedule(
      guardianAdministrator,
      0,
      data,
      predecessor,
      salt,
      TimeLock(payable(timeLock)).getMinDelay()
    );
    TimeLock(payable(timeLock)).execute(guardianAdministrator, 0, data, predecessor, salt);
    vm.stopBroadcast();
  }

  // Create the final vault layout and then grant the local admin wallet broad control
  // over each created vault so frontend/manual testing is not blocked by permissions.
  function _createVaults(
    uint256 deployerPrivateKey,
    Contracts memory contracts,
    Participants memory participants,
    address secondaryToken
  ) internal returns (VaultSeeds memory vaultSeeds) {
    // Final vault layout:
    // - guardian1: primary + secondary asset vaults
    // - guardian2: primary asset vault
    // - admin guardian: no vault
    vaultSeeds.guardian1PrimaryVault = _createVault(
      participants.guardian1.privateKey,
      contracts.vaultFactory,
      contracts.vaultRegistry,
      participants.guardian1.addr,
      contracts.primaryToken,
      "Seed Guardian1 Primary Vault",
      "sg1P"
    );
    vaultSeeds.guardian2PrimaryVault = _createVault(
      participants.guardian2.privateKey,
      contracts.vaultFactory,
      contracts.vaultRegistry,
      participants.guardian2.addr,
      contracts.primaryToken,
      "Seed Guardian2 Primary Vault",
      "sg2P"
    );
    vaultSeeds.guardian1SecondaryVault = _createVault(
      participants.guardian1.privateKey,
      contracts.vaultFactory,
      contracts.vaultRegistry,
      participants.guardian1.addr,
      secondaryToken,
      "Seed Guardian1 Secondary Vault",
      "sg1S"
    );

    _grantVaultRolesToAdmin(
      deployerPrivateKey, contracts.timeLock, vaultSeeds.guardian1PrimaryVault, participants.adminGuardian.addr
    );
    _grantVaultRolesToAdmin(
      deployerPrivateKey, contracts.timeLock, vaultSeeds.guardian2PrimaryVault, participants.adminGuardian.addr
    );
    _grantVaultRolesToAdmin(
      deployerPrivateKey, contracts.timeLock, vaultSeeds.guardian1SecondaryVault, participants.adminGuardian.addr
    );
  }

  function _createVault(
    uint256 guardianPrivateKey,
    address vaultFactory,
    address vaultRegistry,
    address guardian,
    address asset,
    string memory name,
    string memory symbol
  ) internal returns (address vault) {
    vault = VaultRegistry(vaultRegistry).getVaultByAssetAndGuardian(asset, guardian);
    if (vault != address(0)) {
      return vault;
    }

    vm.startBroadcast(guardianPrivateKey);
    (vault,) = VaultFactory(vaultFactory).createVault(asset, name, symbol);
    vm.stopBroadcast();
  }

  // Generate visible economic activity so the local app has balances, deposits and
  // user behavior to display immediately after seeding.
  function _seedEconomicActivity(
    Participants memory participants,
    Contracts memory contracts,
    VaultSeeds memory vaultSeeds,
    address secondaryToken
  ) internal {
    // Leave visible balances and vault activity for frontend consumption from the first load.
    _buyGovernanceForInvestor(
      participants.investor1, contracts.primaryToken, contracts.genesisBonding, INVESTOR1_PRIMARY_GVT_BUY
    );
    _buyGovernanceForInvestor(
      participants.investor2, secondaryToken, contracts.genesisBonding, INVESTOR2_SECONDARY_GVT_BUY
    );

    _depositToVault(
      participants.investor1, contracts.primaryToken, vaultSeeds.guardian1PrimaryVault, INVESTOR1_PRIMARY_DEPOSIT
    );
    _depositToVault(
      participants.investor2, contracts.primaryToken, vaultSeeds.guardian2PrimaryVault, INVESTOR2_PRIMARY_DEPOSIT
    );
    _depositToVault(
      participants.investor2, secondaryToken, vaultSeeds.guardian1SecondaryVault, INVESTOR2_SECONDARY_DEPOSIT
    );
  }

  // Mint governance voting power to actors dedicated to proposal-state demos.
  // Votes are self-delegated because Governor relies on historical voting checkpoints.
  function _mintAndDelegateGovernanceActors(
    uint256 adminWalletPrivateKey,
    address governanceToken,
    Participants memory participants
  ) internal {
    // These actors are dedicated to proposal-state demos and are kept separate from guardian/investor accounts.
    vm.startBroadcast(adminWalletPrivateKey);
    GovernanceToken(governanceToken).mint(participants.proposerPending.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.proposerActive.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.proposerCanceled.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.proposerDefeated.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.proposerSucceeded.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.proposerQueued.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.proposerExecuted.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.voter1.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.voter2.addr, GOVERNANCE_ACTOR_MINT);
    GovernanceToken(governanceToken).mint(participants.voter3.addr, GOVERNANCE_ACTOR_MINT);
    vm.stopBroadcast();

    _delegateVotes(participants.proposerPending, governanceToken);
    _delegateVotes(participants.proposerActive, governanceToken);
    _delegateVotes(participants.proposerCanceled, governanceToken);
    _delegateVotes(participants.proposerDefeated, governanceToken);
    _delegateVotes(participants.proposerSucceeded, governanceToken);
    _delegateVotes(participants.proposerQueued, governanceToken);
    _delegateVotes(participants.proposerExecuted, governanceToken);
    _delegateVotes(participants.voter1, governanceToken);
    _delegateVotes(participants.voter2, governanceToken);
    _delegateVotes(participants.voter3, governanceToken);

    _advanceBlocks(1);
  }

  // Self-delegation is required for the balance to become usable voting power.
  function _delegateVotes(Participant memory actor, address governanceToken) internal {
    vm.startBroadcast(actor.privateKey);
    GovernanceToken(governanceToken).delegate(actor.addr);
    vm.stopBroadcast();
  }

  // Create demo proposals that end in different observable states for the frontend.
  // The ordering matters because some states require block advancement while the final
  // pending proposal must remain untouched after creation.
  function _seedProposalStates(
    Participants memory participants,
    Contracts memory contracts,
    address secondaryToken,
    ProposalSeeds memory proposalSeeds
  ) internal {
    DaoGovernor governor = DaoGovernor(payable(contracts.daoGovernor));

    // All demo proposals use an idempotent call so they can be created, queued and executed safely.
    proposalSeeds.canceled = _createProposal(
      participants.proposerCanceled,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-canceled"
    );
    _cancelProposal(participants.proposerCanceled, governor, proposalSeeds.canceled);

    proposalSeeds.defeated = _createProposal(
      participants.proposerDefeated,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-defeated"
    );
    _advanceToActive(governor, proposalSeeds.defeated);
    _advancePastDeadline(governor, proposalSeeds.defeated);

    proposalSeeds.succeeded = _createProposal(
      participants.proposerSucceeded,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-succeeded"
    );
    _advanceToActive(governor, proposalSeeds.succeeded);
    _vote(participants.proposerSucceeded, governor, proposalSeeds.succeeded, VOTE_FOR, "seed vote for succeeded");
    _vote(participants.voter1, governor, proposalSeeds.succeeded, VOTE_FOR, "seed vote for succeeded");
    _advancePastDeadline(governor, proposalSeeds.succeeded);

    proposalSeeds.queued = _createProposal(
      participants.proposerQueued,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-queued"
    );
    _advanceToActive(governor, proposalSeeds.queued);
    _vote(participants.proposerQueued, governor, proposalSeeds.queued, VOTE_FOR, "seed vote for queued");
    _vote(participants.voter1, governor, proposalSeeds.queued, VOTE_FOR, "seed vote for queued");
    _advancePastDeadline(governor, proposalSeeds.queued);
    _queueProposal(participants.proposerQueued, governor, proposalSeeds.queued);

    proposalSeeds.executed = _createProposal(
      participants.proposerExecuted,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-executed"
    );
    _advanceToActive(governor, proposalSeeds.executed);
    _vote(participants.proposerExecuted, governor, proposalSeeds.executed, VOTE_FOR, "seed vote for executed");
    _vote(participants.voter1, governor, proposalSeeds.executed, VOTE_FOR, "seed vote for executed");
    _advancePastDeadline(governor, proposalSeeds.executed);
    _queueProposal(participants.proposerExecuted, governor, proposalSeeds.executed);
    _executeProposal(participants.proposerExecuted, governor, proposalSeeds.executed);

    proposalSeeds.active = _createProposal(
      participants.proposerActive,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-active"
    );
    _advanceToActive(governor, proposalSeeds.active);
    _vote(participants.proposerActive, governor, proposalSeeds.active, VOTE_FOR, "seed vote for active");

    proposalSeeds.pending = _createProposal(
      participants.proposerPending,
      governor,
      contracts.protocolCore,
      abi.encodeCall(ProtocolCore.setSupportedVaultAsset, (secondaryToken, true)),
      "seed-demo-pending"
    );
  }

  // Helper for building a single-target governor proposal.
  function _createProposal(
    Participant memory proposer,
    DaoGovernor governor,
    address target,
    bytes memory callData,
    string memory description
  ) internal returns (uint256 proposalId) {
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    string memory uniqueDescription =
      string.concat(description, "-proposal-count-", vm.toString(governor.proposalCount()));

    targets[0] = target;
    values[0] = 0;
    calldatas[0] = callData;

    vm.startBroadcast(proposer.privateKey);
    proposalId = governor.propose(targets, values, calldatas, uniqueDescription);
    vm.stopBroadcast();
  }

  // Cancel through the proposer path exposed by the current governor implementation.
  function _cancelProposal(Participant memory proposer, DaoGovernor governor, uint256 proposalId) internal {
    vm.startBroadcast(proposer.privateKey);
    governor.cancel(proposalId);
    vm.stopBroadcast();
  }

  // Queue the proposal in the timelock once it reaches Succeeded.
  function _queueProposal(Participant memory caller, DaoGovernor governor, uint256 proposalId) internal {
    vm.startBroadcast(caller.privateKey);
    governor.queue(proposalId);
    vm.stopBroadcast();
  }

  // Execute the queued operation through the governor's proposalId-based API.
  function _executeProposal(Participant memory caller, DaoGovernor governor, uint256 proposalId) internal {
    vm.startBroadcast(caller.privateKey);
    governor.execute(proposalId);
    vm.stopBroadcast();
  }

  // Cast a vote from a specific seeded voter with a readable on-chain reason.
  function _vote(
    Participant memory voter,
    DaoGovernor governor,
    uint256 proposalId,
    uint8 support,
    string memory reason
  ) internal {
    vm.startBroadcast(voter.privateKey);
    governor.castVoteWithReason(proposalId, support, reason);
    vm.stopBroadcast();
  }

  // Move the local chain until the proposal is actually Active.
  function _advanceToActive(DaoGovernor governor, uint256 proposalId) internal {
    // Governor becomes Active only after the snapshot block has passed.
    uint256 targetBlock = governor.proposalSnapshot(proposalId) + 1;
    if (block.number < targetBlock) {
      _advanceBlocks(targetBlock - block.number);
    }
  }

  // Move the local chain past the voting deadline so the proposal can settle into
  // Defeated, Succeeded or later states.
  function _advancePastDeadline(DaoGovernor governor, uint256 proposalId) internal {
    uint256 targetBlock = governor.proposalDeadline(proposalId) + 1;
    if (block.number < targetBlock) {
      _advanceBlocks(targetBlock - block.number);
    }
  }

  // Advance both block number and timestamp to keep local state coherent.
  function _advanceBlocks(uint256 blocksToAdvance) internal {
    if (blocksToAdvance == 0) {
      return;
    }

    // Mining via RPC can desynchronize Foundry's tx replay from the live node during broadcast.
    // Using real no-op transactions keeps block advancement ordered with the rest of the seed.
    address blockAdvancer = vm.addr(BLOCK_ADVANCER_PRIVATE_KEY);

    for (uint256 i = 0; i < blocksToAdvance; i++) {
      vm.startBroadcast(BLOCK_ADVANCER_PRIVATE_KEY);
      (bool ok,) = payable(blockAdvancer).call("");
      vm.stopBroadcast();
      require(ok, "Failed to advance block");
    }

    vm.roll(block.number + blocksToAdvance);
    vm.warp(block.timestamp + (blocksToAdvance * BLOCK_TIME));
  }

  // Even though the governor exposes queue/execute by proposal id, the underlying timelock
  // still checks proposer/executor/canceller permissions, so we grant them here.
  function _grantGovernorTimelockRoles(uint256 adminWalletPrivateKey, address timeLock, address daoGovernor) internal {
    // GovernorStorage exposes queue/execute by proposalId, but the governor still needs timelock permissions.
    vm.startBroadcast(adminWalletPrivateKey);

    if (!_hasRole(timeLock, PROPOSER_ROLE, daoGovernor)) {
      TimeLock(payable(timeLock)).grantRole(PROPOSER_ROLE, daoGovernor);
    }
    if (!_hasRole(timeLock, EXECUTOR_ROLE, daoGovernor)) {
      TimeLock(payable(timeLock)).grantRole(EXECUTOR_ROLE, daoGovernor);
    }
    if (!_hasRole(timeLock, CANCELLER_ROLE, daoGovernor)) {
      TimeLock(payable(timeLock)).grantRole(CANCELLER_ROLE, daoGovernor);
    }

    vm.stopBroadcast();
  }

  // This makes ADMIN_WALLET_ANVIL_PRIVATE_KEY the local super-admin across the protocol.
  // The goal is convenience in local development, not production-style least privilege.
  function _grantAdminWalletFullAccess(
    uint256 deployerPrivateKey,
    address adminWallet,
    address timeLock,
    address governanceToken,
    address treasury,
    address protocolCore,
    address riskManager,
    address guardianAdministrator,
    address guardianBondEscrow,
    address vaultRegistry,
    address strategyRouter,
    address genesisBonding,
    address vaultFactory
  ) internal {
    // The admin wallet from .env becomes the local super-admin so manual testing can reach every protected path.
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, timeLock, DEFAULT_ADMIN_ROLE, adminWallet, "timelock-default-admin");
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, timeLock, PROPOSER_ROLE, adminWallet, "timelock-proposer");
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, timeLock, EXECUTOR_ROLE, adminWallet, "timelock-executor");
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, timeLock, CANCELLER_ROLE, adminWallet, "timelock-canceller");

    _grantRoleViaTimelock(
      deployerPrivateKey,
      timeLock,
      governanceToken,
      DEFAULT_ADMIN_ROLE,
      adminWallet,
      "governance-token-default-admin"
    );
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, governanceToken, MINTER_ROLE, adminWallet, "governance-token-minter");

    _grantRoleViaTimelock(deployerPrivateKey, timeLock, treasury, DEFAULT_ADMIN_ROLE, adminWallet, "treasury-default-admin");
    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, treasury, SWEEP_NOT_ASSET_DAO_ROLE, adminWallet, "treasury-sweep-not-asset-dao"
    );

    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, protocolCore, DEFAULT_ADMIN_ROLE, adminWallet, "protocol-core-default-admin"
    );
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, protocolCore, MANAGER_ROLE, adminWallet, "protocol-core-manager");
    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, protocolCore, EMERGENCY_ROLE, adminWallet, "protocol-core-emergency"
    );

    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, riskManager, DEFAULT_ADMIN_ROLE, adminWallet, "risk-manager-default-admin"
    );
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, riskManager, MANAGER_ROLE, adminWallet, "risk-manager-manager");
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, riskManager, EMERGENCY_ROLE, adminWallet, "risk-manager-emergency");

    _grantRoleViaTimelock(
      deployerPrivateKey,
      timeLock,
      guardianBondEscrow,
      DEFAULT_ADMIN_ROLE,
      adminWallet,
      "guardian-bond-escrow-default-admin"
    );
    _grantRoleViaTimelock(
      deployerPrivateKey,
      timeLock,
      guardianBondEscrow,
      GUARDIAN_ADMINISTRATOR_ROLE,
      adminWallet,
      "guardian-bond-escrow-guardian-admin"
    );

    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, vaultRegistry, DEFAULT_ADMIN_ROLE, adminWallet, "vault-registry-default-admin"
    );
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, vaultRegistry, FACTORY_ROLE, adminWallet, "vault-registry-factory");

    _grantRoleViaTimelock(
      deployerPrivateKey,
      timeLock,
      strategyRouter,
      DEFAULT_ADMIN_ROLE,
      adminWallet,
      "strategy-router-default-admin"
    );
    _grantRoleViaTimelock(
      deployerPrivateKey,
      timeLock,
      strategyRouter,
      ADAPTER_MANAGER_ROLE,
      adminWallet,
      "strategy-router-adapter-manager"
    );

    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, genesisBonding, DEFAULT_ADMIN_ROLE, adminWallet, "genesis-bonding-default-admin"
    );
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, genesisBonding, SWEEP_ROLE, adminWallet, "genesis-bonding-sweep");

    _grantRoleViaTimelock(deployerPrivateKey, timeLock, vaultFactory, DEFAULT_ADMIN_ROLE, adminWallet, "vault-factory-default-admin");

    _checkAdminWalletCoverage(timeLock, guardianAdministrator, adminWallet);
  }

  // Grant broad vault-level permissions to the local admin wallet on every seeded vault.
  function _grantVaultRolesToAdmin(
    uint256 deployerPrivateKey,
    address timeLock,
    address vault,
    address adminWallet
  ) internal {
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, vault, DEFAULT_ADMIN_ROLE, adminWallet, "vault-default-admin");
    _grantRoleViaTimelock(deployerPrivateKey, timeLock, vault, GUARDIAN_ROLE, adminWallet, "vault-guardian");
    _grantRoleViaTimelock(
      deployerPrivateKey, timeLock, vault, STRATEGY_EXECUTOR_ROLE, adminWallet, "vault-strategy-executor"
    );
  }

  // Schedule a grantRole call through the timelock and execute it immediately in local Anvil.
  // The idempotency guard is important because many permissions are already owned by the deployer
  // or may have been granted in a previous fresh run design.
  function _grantRoleViaTimelock(
    uint256 deployerPrivateKey,
    address timeLock,
    address target,
    bytes32 role,
    address account,
    string memory saltLabel
  ) internal {
    // Role grants are idempotent so rerunning against a fresh Anvil deployment is safe.
    if (_hasRole(target, role, account)) {
      return;
    }

    bytes memory data = abi.encodeWithSignature("grantRole(bytes32,address)", role, account);
    _scheduleAndExecuteTimelockCall(
      deployerPrivateKey,
      timeLock,
      target,
      data,
      keccak256(abi.encodePacked("seed-local-role", saltLabel, target, role, account))
    );
  }

  // Shared helper for timelock-controlled configuration changes.
  function _scheduleAndExecuteTimelockCall(
    uint256 deployerPrivateKey,
    address timeLock,
    address target,
    bytes memory data,
    bytes32 salt
  ) internal {
    // In local Anvil the timelock delay is zero, so we can schedule and execute in the same seed transaction flow.
    bytes32 predecessor = bytes32(0);
    uint256 minDelay = TimeLock(payable(timeLock)).getMinDelay();

    vm.startBroadcast(deployerPrivateKey);
    TimeLock(payable(timeLock)).schedule(target, 0, data, predecessor, salt, minDelay);
    TimeLock(payable(timeLock)).execute(target, 0, data, predecessor, salt);
    vm.stopBroadcast();
  }

  // AccessControl-compatible role probe used across many protocol contracts and vaults.
  function _hasRole(address target, bytes32 role, address account) internal view returns (bool hasRole_) {
    (bool ok, bytes memory data) = target.staticcall(abi.encodeWithSignature("hasRole(bytes32,address)", role, account));

    if (!ok || data.length < 32) {
      return false;
    }

    hasRole_ = abi.decode(data, (bool));
  }

  // Minimal sanity checks for the admin wallet after the role-grant pass.
  function _checkAdminWalletCoverage(address timeLock, address guardianAdministrator, address adminWallet) internal view {
    require(_hasRole(timeLock, DEFAULT_ADMIN_ROLE, adminWallet), "Admin wallet missing timelock default admin role");
    require(_hasRole(timeLock, PROPOSER_ROLE, adminWallet), "Admin wallet missing timelock proposer role");
    require(_hasRole(timeLock, EXECUTOR_ROLE, adminWallet), "Admin wallet missing timelock executor role");
    require(_hasRole(timeLock, CANCELLER_ROLE, adminWallet), "Admin wallet missing timelock canceller role");
    require(GuardianAdministrator(guardianAdministrator).timelock() == timeLock, "GuardianAdministrator timelock mismatch");
  }

  // Send ETH from the deployer to a seeded actor.
  function _fundAccount(uint256 deployerPrivateKey, address target, uint256 amount) internal {
    vm.startBroadcast(deployerPrivateKey);
    (bool ok,) = payable(target).call{value: amount}("");
    vm.stopBroadcast();
    require(ok, "Failed to fund account");
  }

  // Mint a mock token balance to a target actor.
  function _mintToken(uint256 deployerPrivateKey, address token, address to, uint256 amount) internal {
    vm.startBroadcast(deployerPrivateKey);
    MockERC20(token).mint(to, amount);
    vm.stopBroadcast();
  }

  // Buy governance token through GenesisBonding using the chosen payment token.
  function _buyGovernanceForInvestor(
    Participant memory investor,
    address paymentToken,
    address genesisBonding,
    uint256 amount
  ) internal {
    vm.startBroadcast(investor.privateKey);
    MockERC20(paymentToken).approve(genesisBonding, amount);
    GenesisBonding(genesisBonding).buy(paymentToken, amount);
    vm.stopBroadcast();
  }

  // Deposit the chosen asset into the target ERC4626 vault.
  function _depositToVault(Participant memory investor, address asset, address vault, uint256 amount) internal {
    vm.startBroadcast(investor.privateKey);
    MockERC20(asset).approve(vault, amount);
    IERC4626(vault).deposit(amount, investor.addr);
    vm.stopBroadcast();
  }

  function _validateSeed(
    Contracts memory contracts,
    Participants memory participants,
    VaultSeeds memory vaultSeeds,
    ProposalSeeds memory proposalSeeds,
    address secondaryToken
  ) internal view {
    // These checks are the seed's contract-level acceptance tests.
    ProtocolCore core = ProtocolCore(contracts.protocolCore);
    GuardianAdministrator guardianAdministrator = GuardianAdministrator(contracts.guardianAdministrator);
    VaultRegistry registry = VaultRegistry(contracts.vaultRegistry);
    DaoGovernor governor = DaoGovernor(payable(contracts.daoGovernor));

    require(core.hasGenesisToken(contracts.primaryToken), "Primary token not registered as genesis token");
    require(core.hasGenesisToken(secondaryToken), "Secondary token not registered as genesis token");
    require(core.isVaultAssetSupported(contracts.primaryToken), "Primary token not supported as vault asset");
    require(core.isVaultAssetSupported(secondaryToken), "Secondary token not supported as vault asset");

    require(guardianAdministrator.isActiveGuardian(participants.guardian1.addr), "Guardian1 not active");
    require(guardianAdministrator.isActiveGuardian(participants.guardian2.addr), "Guardian2 not active");
    require(guardianAdministrator.isActiveGuardian(participants.adminGuardian.addr), "Admin guardian not active");

    require(registry.getVaultsByGuardian(participants.guardian1.addr).length == 2, "Guardian1 vault count mismatch");
    require(registry.getVaultsByGuardian(participants.guardian2.addr).length == 1, "Guardian2 vault count mismatch");
    require(registry.getVaultsByGuardian(participants.adminGuardian.addr).length == 0, "Admin guardian should not have vaults");

    require(registry.isActiveVault(vaultSeeds.guardian1PrimaryVault), "Guardian1 primary vault inactive");
    require(registry.isActiveVault(vaultSeeds.guardian2PrimaryVault), "Guardian2 primary vault inactive");
    require(registry.isActiveVault(vaultSeeds.guardian1SecondaryVault), "Guardian1 secondary vault inactive");

    require(
      GovernanceToken(contracts.governanceToken).balanceOf(participants.investor2.addr) >= INVESTOR2_SECONDARY_GVT_BUY * 100,
      "Secondary token governance purchase missing"
    );

    require(governor.state(proposalSeeds.pending) == IGovernor.ProposalState.Pending, "Pending proposal state mismatch");
    require(governor.state(proposalSeeds.active) == IGovernor.ProposalState.Active, "Active proposal state mismatch");
    require(governor.state(proposalSeeds.canceled) == IGovernor.ProposalState.Canceled, "Canceled proposal state mismatch");
    require(governor.state(proposalSeeds.defeated) == IGovernor.ProposalState.Defeated, "Defeated proposal state mismatch");
    require(governor.state(proposalSeeds.succeeded) == IGovernor.ProposalState.Succeeded, "Succeeded proposal state mismatch");
    require(governor.state(proposalSeeds.queued) == IGovernor.ProposalState.Queued, "Queued proposal state mismatch");
    require(governor.state(proposalSeeds.executed) == IGovernor.ProposalState.Executed, "Executed proposal state mismatch");

    require(
      proposalSeeds.governorProposalCountAfterDemo == proposalSeeds.governorProposalCountBeforeDemo + 7,
      "Governor demo proposal count mismatch"
    );
  }

  // Human-readable terminal output for developers after the seed completes.
  function _logSeed(
    Contracts memory contracts,
    Participants memory participants,
    VaultSeeds memory vaultSeeds,
    ProposalSeeds memory proposalSeeds,
    address secondaryToken
  ) internal view {
    DaoGovernor governor = DaoGovernor(payable(contracts.daoGovernor));

    console.log("========================================");
    console.log("Local Seed Complete");
    console.log("========================================");
    console.log("Primary Genesis Token:", contracts.primaryToken);
    console.log("Secondary Genesis Token:", secondaryToken);
    console.log("Guardian1:", participants.guardian1.addr);
    console.log("Guardian2:", participants.guardian2.addr);
    console.log("Admin Guardian:", participants.adminGuardian.addr);
    console.log("Guardian1 Primary Vault:", vaultSeeds.guardian1PrimaryVault);
    console.log("Guardian2 Primary Vault:", vaultSeeds.guardian2PrimaryVault);
    console.log("Guardian1 Secondary Vault:", vaultSeeds.guardian1SecondaryVault);
    console.log("Guardian1 Application Proposal:", proposalSeeds.guardian1Application);
    console.log("Guardian2 Application Proposal:", proposalSeeds.guardian2Application);
    console.log("Admin Guardian Application Proposal:", proposalSeeds.adminGuardianApplication);
    console.log("Pending Proposal:", proposalSeeds.pending);
    console.log("Active Proposal:", proposalSeeds.active);
    console.log("Canceled Proposal:", proposalSeeds.canceled);
    console.log("Defeated Proposal:", proposalSeeds.defeated);
    console.log("Succeeded Proposal:", proposalSeeds.succeeded);
    console.log("Queued Proposal:", proposalSeeds.queued);
    console.log("Executed Proposal:", proposalSeeds.executed);
    console.log("Governor Proposal Count Before Demo:", proposalSeeds.governorProposalCountBeforeDemo);
    console.log("Governor Proposal Count After Demo:", proposalSeeds.governorProposalCountAfterDemo);
    console.log("Pending Proposal State:", uint256(uint8(governor.state(proposalSeeds.pending))));
    console.log("Active Proposal State:", uint256(uint8(governor.state(proposalSeeds.active))));
    console.log("Canceled Proposal State:", uint256(uint8(governor.state(proposalSeeds.canceled))));
    console.log("Defeated Proposal State:", uint256(uint8(governor.state(proposalSeeds.defeated))));
    console.log("Succeeded Proposal State:", uint256(uint8(governor.state(proposalSeeds.succeeded))));
    console.log("Queued Proposal State:", uint256(uint8(governor.state(proposalSeeds.queued))));
    console.log("Executed Proposal State:", uint256(uint8(governor.state(proposalSeeds.executed))));
  }

  // Persist a local JSON snapshot with the most frontend-relevant seeded values.
  // This file is intentionally emitted only for Anvil because equivalent actions on
  // live networks should be governed/manual, not automatic.
  function _writeSeedJson(
    Contracts memory contracts,
    Participants memory participants,
    ProposalSeeds memory proposalSeeds,
    address secondaryToken
  ) internal {
    // The persisted JSON is intentionally local-only; on real networks those admin actions should be manual/governed.
    if (block.chainid != 31337) {
      return;
    }

    address[] memory supportedGenesisTokens = ProtocolCore(contracts.protocolCore).getSupportedGenesisTokens();
    address[] memory supportedVaultAssets = new address[](2);
    supportedVaultAssets[0] = contracts.primaryToken;
    supportedVaultAssets[1] = secondaryToken;

    address[] memory guardian1Vaults = VaultRegistry(contracts.vaultRegistry).getVaultsByGuardian(participants.guardian1.addr);
    address[] memory guardian2Vaults = VaultRegistry(contracts.vaultRegistry).getVaultsByGuardian(participants.guardian2.addr);
    address[] memory adminGuardianVaults =
      VaultRegistry(contracts.vaultRegistry).getVaultsByGuardian(participants.adminGuardian.addr);

    string memory guardiansJson = _guardiansJson(participants);
    string memory vaultsByGuardianJson = _vaultsByGuardianJson(guardian1Vaults, guardian2Vaults, adminGuardianVaults);
    string memory proposalIdsByStateJson = _proposalIdsByStateJson(proposalSeeds);
    string memory guardianApplicationProposalIdsJson = _guardianApplicationProposalIdsJson(proposalSeeds);

    string memory json = string(
      abi.encodePacked(
        "{",
        '"chainId":"', vm.toString(block.chainid), '",',
        '"primaryGenesisToken":"', vm.toString(contracts.primaryToken), '",',
        '"secondaryGenesisToken":"', vm.toString(secondaryToken), '",',
        '"supportedGenesisTokens":', _addressArrayToJson(supportedGenesisTokens), ",",
        '"supportedVaultAssets":', _addressArrayToJson(supportedVaultAssets), ",",
        '"guardians":', guardiansJson, ",",
        '"vaultsByGuardian":', vaultsByGuardianJson, ",",
        '"proposalIdsByState":', proposalIdsByStateJson, ",",
        '"guardianApplicationProposalIds":', guardianApplicationProposalIdsJson,
        "}"
      )
    );

    vm.writeJson(json, "deployments/anvil-seed.json");
  }

  // JSON fragment helpers kept separate to avoid a very large stack frame when composing
  // the final persisted file.
  function _guardiansJson(Participants memory participants) internal view returns (string memory json) {
    json = string(
      abi.encodePacked(
        "{",
        '"guardian1":"', vm.toString(participants.guardian1.addr), '",',
        '"guardian2":"', vm.toString(participants.guardian2.addr), '",',
        '"adminGuardian":"', vm.toString(participants.adminGuardian.addr), '"',
        "}"
      )
    );
  }

  function _vaultsByGuardianJson(
    address[] memory guardian1Vaults,
    address[] memory guardian2Vaults,
    address[] memory adminGuardianVaults
  ) internal view returns (string memory json) {
    json = string(
      abi.encodePacked(
        "{",
        '"guardian1":', _addressArrayToJson(guardian1Vaults), ",",
        '"guardian2":', _addressArrayToJson(guardian2Vaults), ",",
        '"adminGuardian":', _addressArrayToJson(adminGuardianVaults),
        "}"
      )
    );
  }

  // Proposal ids are serialized as strings to avoid frontend issues with large uint256 values.
  function _proposalIdsByStateJson(ProposalSeeds memory proposalSeeds) internal view returns (string memory json) {
    json = string(
      abi.encodePacked(
        "{",
        '"pending":"', vm.toString(proposalSeeds.pending), '",',
        '"active":"', vm.toString(proposalSeeds.active), '",',
        '"canceled":"', vm.toString(proposalSeeds.canceled), '",',
        '"defeated":"', vm.toString(proposalSeeds.defeated), '",',
        '"succeeded":"', vm.toString(proposalSeeds.succeeded), '",',
        '"queued":"', vm.toString(proposalSeeds.queued), '",',
        '"executed":"', vm.toString(proposalSeeds.executed), '"',
        "}"
      )
    );
  }

  function _guardianApplicationProposalIdsJson(ProposalSeeds memory proposalSeeds)
    internal
    view
    returns (string memory json)
  {
    json = string(
      abi.encodePacked(
        "{",
        '"guardian1":"', vm.toString(proposalSeeds.guardian1Application), '",',
        '"guardian2":"', vm.toString(proposalSeeds.guardian2Application), '",',
        '"adminGuardian":"', vm.toString(proposalSeeds.adminGuardianApplication), '"',
        "}"
      )
    );
  }

  // Lightweight address array serializer used by the local seed snapshot.
  function _addressArrayToJson(address[] memory values) internal view returns (string memory json) {
    json = "[";

    for (uint256 i = 0; i < values.length; i++) {
      if (i > 0) {
        json = string(abi.encodePacked(json, ","));
      }
      json = string(abi.encodePacked(json, '"', vm.toString(values[i]), '"'));
    }

    json = string(abi.encodePacked(json, "]"));
  }
}
