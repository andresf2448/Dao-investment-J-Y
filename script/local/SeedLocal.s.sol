// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../deploy/HelperConfig.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {MockERC20} from "../../test/mocks/MockERC20.sol";
import {GenesisBonding} from "../../contracts/bootstrap/GenesisBonding.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {GuardianBondEscrow} from "../../contracts/guardians/GuardianBondEscrow.sol";
import {VaultFactory} from "../../contracts/vaults/factory/VaultFactory.sol";

contract SeedLocal is Script {
  uint256 constant GAS_BUFFER = 1 ether;
  uint256 constant GUARDIAN_BOND = 100e18;
  uint256 constant INVESTOR1_GVT_BUY = 50e18;
  uint256 constant INVESTOR2_GVT_BUY = 30e18;
  uint256 constant INVESTOR1_DEPOSIT = 10e18;
  uint256 constant INVESTOR2_DEPOSIT = 5e18;

  struct Participant {
    address addr;
    uint256 privateKey;
    string label;
  }

  function run() external {
    require(block.chainid == 31337, "SeedLocal only supports Anvil");

    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
    string memory json = vm.readFile("deployments/anvil.json");

    address timeLock = abi.decode(vm.parseJson(json, ".timeLock"), (address));
    address guardianAdministrator = abi.decode(vm.parseJson(json, ".guardianAdministrator"), (address));
    address guardianBondEscrow = abi.decode(vm.parseJson(json, ".guardianBondEscrow"), (address));
    address genesisBonding = abi.decode(vm.parseJson(json, ".genesisBonding"), (address));
    address vaultFactory = abi.decode(vm.parseJson(json, ".vaultFactory"), (address));
    address mockUsdc = address(GuardianBondEscrow(guardianBondEscrow).guardianApplicationToken());

    (address guardianAddr, uint256 guardianPk) = makeAddrAndKey("seed-guardian");
    (address investor1Addr, uint256 investor1Pk) = makeAddrAndKey("seed-investor-1");
    (address investor2Addr, uint256 investor2Pk) = makeAddrAndKey("seed-investor-2");

    Participant memory guardian = Participant(guardianAddr, guardianPk, "guardian");
    Participant memory investor1 = Participant(investor1Addr, investor1Pk, "investor1");
    Participant memory investor2 = Participant(investor2Addr, investor2Pk, "investor2");

    console.log("========================================");
    console.log("Running Local Seed");
    console.log("========================================");

    _fundAccount(networkConfig.deployerPrivateKey, guardian.addr, GAS_BUFFER);
    _fundAccount(networkConfig.deployerPrivateKey, investor1.addr, GAS_BUFFER);
    _fundAccount(networkConfig.deployerPrivateKey, investor2.addr, GAS_BUFFER);

    _mintUsdc(networkConfig.deployerPrivateKey, mockUsdc, guardian.addr, GUARDIAN_BOND);
    _mintUsdc(networkConfig.deployerPrivateKey, mockUsdc, investor1.addr, INVESTOR1_GVT_BUY + INVESTOR1_DEPOSIT);
    _mintUsdc(networkConfig.deployerPrivateKey, mockUsdc, investor2.addr, INVESTOR2_GVT_BUY + INVESTOR2_DEPOSIT);

    _activateGuardian(
      networkConfig.deployerPrivateKey,
      guardian,
      mockUsdc,
      guardianBondEscrow,
      guardianAdministrator,
      timeLock
    );

    address vault = _createVault(guardian.privateKey, vaultFactory, mockUsdc);
    _buyGovernanceForInvestor(investor1, mockUsdc, genesisBonding, INVESTOR1_GVT_BUY);
    _buyGovernanceForInvestor(investor2, mockUsdc, genesisBonding, INVESTOR2_GVT_BUY);
    _depositToVault(investor1, mockUsdc, vault, INVESTOR1_DEPOSIT);
    _depositToVault(investor2, mockUsdc, vault, INVESTOR2_DEPOSIT);

    console.log("========================================");
    console.log("Local Seed Complete");
    console.log("========================================");
    console.log("Guardian:", guardian.addr);
    console.log("Investor1:", investor1.addr);
    console.log("Investor2:", investor2.addr);
    console.log("Vault:", vault);
  }

  function _fundAccount(uint256 deployerPrivateKey, address target, uint256 amount) internal {
    vm.startBroadcast(deployerPrivateKey);
    (bool ok,) = payable(target).call{value: amount}("");
    vm.stopBroadcast();
    require(ok, "Failed to fund account");
  }

  function _mintUsdc(uint256 deployerPrivateKey, address mockUsdc, address to, uint256 amount) internal {
    vm.startBroadcast(deployerPrivateKey);
    MockERC20(mockUsdc).mint(to, amount);
    vm.stopBroadcast();
  }

  function _activateGuardian(
    uint256 deployerPrivateKey,
    Participant memory guardian,
    address mockUsdc,
    address guardianBondEscrow,
    address guardianAdministrator,
    address timeLock
  ) internal {
    vm.startBroadcast(guardian.privateKey);
    MockERC20(mockUsdc).approve(guardianBondEscrow, GUARDIAN_BOND);
    GuardianAdministrator(guardianAdministrator).applyGuardian();
    vm.stopBroadcast();

    bytes32 salt = keccak256(abi.encodePacked("seed-local-guardian-approve", guardian.addr));
    bytes memory data = abi.encodeCall(GuardianAdministrator.guardianApprove, (guardian.addr));
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

  function _createVault(uint256 guardianPrivateKey, address vaultFactory, address mockUsdc) internal returns (address vault) {
    vm.startBroadcast(guardianPrivateKey);
    (vault,) = VaultFactory(vaultFactory).createVault(mockUsdc, "Seed Vault", "sVAULT");
    vm.stopBroadcast();
  }

  function _buyGovernanceForInvestor(
    Participant memory investor,
    address mockUsdc,
    address genesisBonding,
    uint256 amount
  ) internal {
    vm.startBroadcast(investor.privateKey);
    MockERC20(mockUsdc).approve(genesisBonding, amount);
    GenesisBonding(genesisBonding).buy(mockUsdc, amount);
    vm.stopBroadcast();
  }

  function _depositToVault(Participant memory investor, address mockUsdc, address vault, uint256 amount) internal {
    vm.startBroadcast(investor.privateKey);
    MockERC20(mockUsdc).approve(vault, amount);
    IERC4626(vault).deposit(amount, investor.addr);
    vm.stopBroadcast();
  }
}
