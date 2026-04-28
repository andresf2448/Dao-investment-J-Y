import type { ProtocolReadDefinition } from "@/hooks/useProtocolReads";
import type { Address } from "viem";

export type DashboardProtocolReadContext = {
  treasuryToken?: Address;
};

export type BondingProtocolReadContext = {
  governanceToken?: Address;
};

export type GuardiansProtocolReadContext = {
  userAddress?: Address;
  proposalId?: number;
};

export const dashboardProtocolReadDefinitions = [
  {
    key: "totalVaults",
    contract: "getVaultRegistryContract",
    functionName: "totalVaults",
  },
  {
    key: "treasuryERC20Balance",
    contract: "getTreasuryContract",
    functionName: "erc20Balance",
    args: (context: DashboardProtocolReadContext) =>
      context.treasuryToken ? [context.treasuryToken] : undefined,
  },
  {
    key: "proposalThreshold",
    contract: "getDaoGovernorContract",
    functionName: "proposalThreshold",
  },
  {
    key: "isBondingFinalized",
    contract: "getGenesisBondingContract",
    functionName: "isFinalized",
  },
  {
    key: "isVaultCreationPaused",
    contract: "getProtocolCoreContract",
    functionName: "isVaultCreationPaused",
  },
  {
    key: "isDepositsPaused",
    contract: "getProtocolCoreContract",
    functionName: "isVaultDepositsPaused",
  },
  {
    key: "isExecutionPaused",
    contract: "getRiskManagerContract",
    functionName: "executionPaused",
  },
  {
    key: "guardianCount",
    contract: "getGuardianAdministratorContract",
    functionName: "totalActiveGuardians",
  },
] as const satisfies readonly ProtocolReadDefinition<
  string,
  DashboardProtocolReadContext
>[];

export const bondingProtocolReadDefinitions = [
  {
    key: "isFinalized",
    contract: "getGenesisBondingContract",
    functionName: "isFinalized",
  },
  {
    key: "rate",
    contract: "getGenesisBondingContract",
    functionName: "rate",
  },
  {
    key: "totalDistributed",
    contract: "getGenesisBondingContract",
    functionName: "totalGovernanceTokenPurchased",
  },
  {
    key: "assetsSupported",
    contract: "getProtocolCoreContract",
    functionName: "getSupportedGenesisTokens",
  },
  {
    key: "governanceTokenWalletBalance",
    contract: "getGovernanceTokenContract",
    functionName: "balanceOf",
    args: (context: BondingProtocolReadContext) =>
      context.governanceToken ? [context.governanceToken] : undefined,
  },
] as const satisfies readonly ProtocolReadDefinition<
  string,
  BondingProtocolReadContext
>[];

export const governanceProtocolReadDefinitions = [
  {
    key: "votingDelay",
    contract: "getDaoGovernorContract",
    functionName: "votingDelay",
  },
  {
    key: "votingPeriod",
    contract: "getDaoGovernorContract",
    functionName: "votingPeriod",
  },
  {
    key: "proposalThreshold",
    contract: "getDaoGovernorContract",
    functionName: "proposalThreshold",
  },
] as const satisfies readonly ProtocolReadDefinition<string, void>[];

export const useGuardiansModelProtocolReadDefinitions = [
  {
    key: "minStake",
    contract: "getGuardianAdministratorContract",
    functionName: "minStake",
  },
  {
    key: "totalActiveGuardians",
    contract: "getGuardianAdministratorContract",
    functionName: "totalActiveGuardians",
  },
  {
    key: "statusGuardian",
    contract: "getGuardianAdministratorContract",
    functionName: "getGuardianDetail",
    args: (context: { userAddress?: Address }) =>
      context.userAddress ? [context.userAddress] : undefined,
  },
  // {
  //   key: ""
  // },
  {
    key: "balanceBondEscrow",
    contract: "getGuardianBondEscrowContract",
    functionName: "getApplicationTokenBalance",
  }
] as const satisfies readonly ProtocolReadDefinition<
  string,
  GuardiansProtocolReadContext
>[];

export const useVaultsModelProtocolReadDefinitions = [
  {
    key: "vaultCount",
    contract: "getVaultRegistryContract",
    functionName: "totalVaults",
  },
  {
    key: "listVaults",
    contract: "getVaultRegistryContract",
    functionName: "getAllVaults",
  },
  {
    key: "totalGuardians",
    contract: "getGuardianAdministratorContract",
    functionName: "totalActiveGuardians",
  },
  {
    key: "isDepositsActiveVaults",
    contract: "getProtocolCoreContract",
    functionName: "isVaultDepositsPaused",
  },
  {
    key: "isCreationActiveVaults",
    contract: "getProtocolCoreContract",
    functionName: "isVaultCreationPaused",
  },
] as const satisfies readonly ProtocolReadDefinition<string, void>[];
