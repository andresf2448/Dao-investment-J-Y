import {
  getDaoGovernorContract,
  getGenesisBondingContract,
  getGovernanceTokenContract,
  getGuardianAdministratorContract,
  getProtocolCoreContract,
  getRiskManagerContract,
  getTreasuryContract,
} from "@dao/contracts-sdk";
import { useMemo } from "react";
import { useChainId, useConnection, useReadContracts } from "wagmi";
import type { Address } from "viem";
import { getGuardianStatus, isGuardianContractDetail } from "@/helpers";
import type { GuardianContractDetail } from "@/types/guardian";
import type {
  ProtocolCapabilities,
  ProtocolCapabilityContext,
} from "@/types/capabilities";
import { getReadContractResult } from "./shared/contractResults";
import { resolveOptionalContract } from "./shared/resolveContract";

export function useProtocolCapabilities(): ProtocolCapabilities {
  const chainId = useChainId();
  const connection = useConnection();
  const address = connection.address as Address | undefined;

  const daoGovernorConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getDaoGovernorContract);
  }, [chainId]);

  const genesisBondingConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getGenesisBondingContract);
  }, [chainId]);

  const governanceTokenConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getGovernanceTokenContract);
  }, [chainId]);

  const guardianAdministratorConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getGuardianAdministratorContract);
  }, [chainId]);

  const protocolCoreConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getProtocolCoreContract);
  }, [chainId]);

  const riskManagerConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getRiskManagerContract);
  }, [chainId]);

  const treasuryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getTreasuryContract);
  }, [chainId]);

  const { data: globalProtocolData } = useReadContracts({
    allowFailure: true,
    contracts: [
      ...(daoGovernorConfig
        ? [
            {
              abi: daoGovernorConfig.abi,
              address: daoGovernorConfig.address,
              functionName: "proposalThreshold" as const,
            },
          ]
        : []),
      ...(genesisBondingConfig
        ? [
            {
              abi: genesisBondingConfig.abi,
              address: genesisBondingConfig.address,
              functionName: "isFinalized" as const,
            },
            {
              abi: genesisBondingConfig.abi,
              address: genesisBondingConfig.address,
              functionName: "SWEEP_ROLE" as const,
            },
          ]
        : []),
      ...(protocolCoreConfig
        ? [
            {
              abi: protocolCoreConfig.abi,
              address: protocolCoreConfig.address,
              functionName: "isVaultCreationPaused" as const,
            },
            {
              abi: protocolCoreConfig.abi,
              address: protocolCoreConfig.address,
              functionName: "isVaultDepositsPaused" as const,
            },
            {
              abi: protocolCoreConfig.abi,
              address: protocolCoreConfig.address,
              functionName: "DEFAULT_ADMIN_ROLE" as const,
            },
            {
              abi: protocolCoreConfig.abi,
              address: protocolCoreConfig.address,
              functionName: "MANAGER_ROLE" as const,
            },
            {
              abi: protocolCoreConfig.abi,
              address: protocolCoreConfig.address,
              functionName: "EMERGENCY_ROLE" as const,
            },
          ]
        : []),
      ...(riskManagerConfig
        ? [
            {
              abi: riskManagerConfig.abi,
              address: riskManagerConfig.address,
              functionName: "executionPaused" as const,
            },
            {
              abi: riskManagerConfig.abi,
              address: riskManagerConfig.address,
              functionName: "DEFAULT_ADMIN_ROLE" as const,
            },
            {
              abi: riskManagerConfig.abi,
              address: riskManagerConfig.address,
              functionName: "MANAGER_ROLE" as const,
            },
            {
              abi: riskManagerConfig.abi,
              address: riskManagerConfig.address,
              functionName: "EMERGENCY_ROLE" as const,
            },
          ]
        : []),
      ...(treasuryConfig
        ? [
            {
              abi: treasuryConfig.abi,
              address: treasuryConfig.address,
              functionName: "DEFAULT_ADMIN_ROLE" as const,
            },
            {
              abi: treasuryConfig.abi,
              address: treasuryConfig.address,
              functionName: "SWEEP_NOT_ASSET_DAO_ROLE" as const,
            },
          ]
        : []),
    ],
    query: {
      enabled: Boolean(
        daoGovernorConfig ||
          genesisBondingConfig ||
          protocolCoreConfig ||
          riskManagerConfig ||
          treasuryConfig,
      ),
    },
  });

  let globalIndex = 0;
  const proposalThreshold = daoGovernorConfig
    ? getReadContractResult<bigint>(globalProtocolData?.[globalIndex++])
    : undefined;
  const isBondingFinalized = genesisBondingConfig
    ? getReadContractResult<boolean>(globalProtocolData?.[globalIndex++]) ?? false
    : false;
  const bondingSweepRole = genesisBondingConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const isVaultCreationPaused = protocolCoreConfig
    ? getReadContractResult<boolean>(globalProtocolData?.[globalIndex++]) ?? false
    : false;
  const isDepositsPaused = protocolCoreConfig
    ? getReadContractResult<boolean>(globalProtocolData?.[globalIndex++]) ?? false
    : false;
  const protocolCoreAdminRole = protocolCoreConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const protocolCoreManagerRole = protocolCoreConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const protocolCoreEmergencyRole = protocolCoreConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const isExecutionPaused = riskManagerConfig
    ? getReadContractResult<boolean>(globalProtocolData?.[globalIndex++]) ?? false
    : false;
  const riskManagerAdminRole = riskManagerConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const riskManagerManagerRole = riskManagerConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const riskManagerEmergencyRole = riskManagerConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const treasuryAdminRole = treasuryConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;
  const treasurySweepRole = treasuryConfig
    ? getReadContractResult<`0x${string}`>(globalProtocolData?.[globalIndex++])
    : undefined;

  const { data: userCapabilityData } = useReadContracts({
    allowFailure: true,
    contracts:
      address
        ? [
            ...(guardianAdministratorConfig
              ? [
                  {
                    abi: guardianAdministratorConfig.abi,
                    address: guardianAdministratorConfig.address,
                    functionName: "getGuardianDetail" as const,
                    args: [address as Address],
                  },
                ]
              : []),
            ...(governanceTokenConfig
              ? [
                  {
                    abi: governanceTokenConfig.abi,
                    address: governanceTokenConfig.address,
                    functionName: "getVotes" as const,
                    args: [address as Address],
                  },
                ]
              : []),
            ...(genesisBondingConfig && bondingSweepRole
              ? [
                  {
                    abi: genesisBondingConfig.abi,
                    address: genesisBondingConfig.address,
                    functionName: "hasRole" as const,
                    args: [bondingSweepRole, address as Address],
                  },
                ]
              : []),
            ...(protocolCoreConfig &&
            protocolCoreAdminRole &&
            protocolCoreManagerRole &&
            protocolCoreEmergencyRole
              ? [
                  {
                    abi: protocolCoreConfig.abi,
                    address: protocolCoreConfig.address,
                    functionName: "hasRole" as const,
                    args: [protocolCoreAdminRole, address as Address],
                  },
                  {
                    abi: protocolCoreConfig.abi,
                    address: protocolCoreConfig.address,
                    functionName: "hasRole" as const,
                    args: [protocolCoreManagerRole, address as Address],
                  },
                  {
                    abi: protocolCoreConfig.abi,
                    address: protocolCoreConfig.address,
                    functionName: "hasRole" as const,
                    args: [protocolCoreEmergencyRole, address as Address],
                  },
                ]
              : []),
            ...(riskManagerConfig &&
            riskManagerAdminRole &&
            riskManagerManagerRole &&
            riskManagerEmergencyRole
              ? [
                  {
                    abi: riskManagerConfig.abi,
                    address: riskManagerConfig.address,
                    functionName: "hasRole" as const,
                    args: [riskManagerAdminRole, address as Address],
                  },
                  {
                    abi: riskManagerConfig.abi,
                    address: riskManagerConfig.address,
                    functionName: "hasRole" as const,
                    args: [riskManagerManagerRole, address as Address],
                  },
                  {
                    abi: riskManagerConfig.abi,
                    address: riskManagerConfig.address,
                    functionName: "hasRole" as const,
                    args: [riskManagerEmergencyRole, address as Address],
                  },
                ]
              : []),
            ...(treasuryConfig && treasuryAdminRole && treasurySweepRole
              ? [
                  {
                    abi: treasuryConfig.abi,
                    address: treasuryConfig.address,
                    functionName: "hasRole" as const,
                    args: [treasuryAdminRole, address as Address],
                  },
                  {
                    abi: treasuryConfig.abi,
                    address: treasuryConfig.address,
                    functionName: "hasRole" as const,
                    args: [treasurySweepRole, address as Address],
                  },
                ]
              : []),
          ]
        : [],
    query: {
      enabled: Boolean(address),
    },
  });

  let userIndex = 0;
  const guardianDetail = guardianAdministratorConfig
    ? userCapabilityData?.[userIndex++]
    : undefined;
  const governanceVotes = governanceTokenConfig
    ? getReadContractResult<bigint>(userCapabilityData?.[userIndex++]) ?? 0n
    : 0n;
  const hasBondingSweepRole =
    genesisBondingConfig && bondingSweepRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasProtocolCoreAdminRole =
    protocolCoreConfig &&
    protocolCoreAdminRole &&
    protocolCoreManagerRole &&
    protocolCoreEmergencyRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasProtocolCoreManagerRole =
    protocolCoreConfig &&
    protocolCoreAdminRole &&
    protocolCoreManagerRole &&
    protocolCoreEmergencyRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasProtocolCoreEmergencyRole =
    protocolCoreConfig &&
    protocolCoreAdminRole &&
    protocolCoreManagerRole &&
    protocolCoreEmergencyRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasRiskManagerAdminRole =
    riskManagerConfig &&
    riskManagerAdminRole &&
    riskManagerManagerRole &&
    riskManagerEmergencyRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasRiskManagerManagerRole =
    riskManagerConfig &&
    riskManagerAdminRole &&
    riskManagerManagerRole &&
    riskManagerEmergencyRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasRiskManagerEmergencyRole =
    riskManagerConfig &&
    riskManagerAdminRole &&
    riskManagerManagerRole &&
    riskManagerEmergencyRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasTreasuryAdminRole =
    treasuryConfig && treasuryAdminRole && treasurySweepRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;
  const hasTreasurySweepRole =
    treasuryConfig && treasuryAdminRole && treasurySweepRole
      ? getReadContractResult<boolean>(userCapabilityData?.[userIndex++]) ?? false
      : false;

  const resolvedGuardianDetail = getReadContractResult<GuardianContractDetail>(
    guardianDetail,
  );
  const guardianStatus =
    resolvedGuardianDetail && isGuardianContractDetail(resolvedGuardianDetail)
      ? getGuardianStatus(resolvedGuardianDetail.status)
      : "inactive";

  const context = useMemo<ProtocolCapabilityContext>(() => {
    const isManagerOperator =
      hasProtocolCoreManagerRole || hasRiskManagerManagerRole;
    const isEmergencyOperator =
      hasProtocolCoreEmergencyRole || hasRiskManagerEmergencyRole;
    const isTreasuryOperator = hasTreasuryAdminRole || hasTreasurySweepRole;
    const isAdminOperator =
      hasProtocolCoreAdminRole ||
      hasRiskManagerAdminRole ||
      hasTreasuryAdminRole;

    return {
      isWalletConnected: Boolean(address),
      hasProposalThreshold:
        proposalThreshold !== undefined && governanceVotes >= proposalThreshold,
      guardianStatus,
      isVaultCreationPaused,
      isDepositsPaused,
      isExecutionPaused,
      isManagerOperator,
      isEmergencyOperator,
      isTreasuryOperator,
      isAdminOperator,
      hasBondingSweepRole,
      hasTreasurySweepRole,
    };
  }, [
    address,
    governanceVotes,
    guardianStatus,
    hasProtocolCoreAdminRole,
    hasProtocolCoreEmergencyRole,
    hasProtocolCoreManagerRole,
    hasRiskManagerAdminRole,
    hasRiskManagerEmergencyRole,
    hasRiskManagerManagerRole,
    hasTreasuryAdminRole,
    hasTreasurySweepRole,
    isDepositsPaused,
    isExecutionPaused,
    isVaultCreationPaused,
    proposalThreshold,
    hasBondingSweepRole,
  ]);

  return useMemo(() => {
    const capabilities = deriveCapabilities(context);
    const isWalletConnected = context.isWalletConnected;
    const canOpenTreasuryOperations =
      isWalletConnected && hasTreasuryAdminRole;
    const canPauseVaultCreation =
      isWalletConnected && hasProtocolCoreEmergencyRole;
    const canResumeVaultCreation =
      isWalletConnected && hasProtocolCoreManagerRole;
    const canPauseVaultDeposits =
      isWalletConnected && hasProtocolCoreEmergencyRole;
    const canResumeVaultDeposits =
      isWalletConnected && hasProtocolCoreManagerRole;
    const canPauseRiskExecution =
      isWalletConnected && hasRiskManagerEmergencyRole;
    const canResumeRiskExecution =
      isWalletConnected && hasRiskManagerManagerRole;
    const canAccessAdminConsole =
      isWalletConnected &&
      (context.isAdminOperator ||
        hasProtocolCoreManagerRole ||
        hasProtocolCoreEmergencyRole ||
        hasRiskManagerManagerRole ||
        hasRiskManagerEmergencyRole);

    return {
      ...capabilities,
      canBuyGovernanceTokens:
        isWalletConnected &&
        Boolean(genesisBondingConfig) &&
        !isBondingFinalized,
      canOpenTreasuryOperations,
      canWithdrawNonDaoAssets: isWalletConnected && hasTreasurySweepRole,
      canPauseVaultCreation,
      canResumeVaultCreation,
      canPauseVaultDeposits,
      canResumeVaultDeposits,
      canPauseRiskExecution,
      canResumeRiskExecution,
      canAccessAdminConsole,
      canSweepBondingTokens: isWalletConnected && hasBondingSweepRole,
    };
  }, [
    context,
    hasProtocolCoreEmergencyRole,
    hasProtocolCoreManagerRole,
    hasRiskManagerEmergencyRole,
    hasRiskManagerManagerRole,
    hasTreasuryAdminRole,
    hasTreasurySweepRole,
    genesisBondingConfig,
    isBondingFinalized,
  ]);
}

export function deriveCapabilities(
  context: ProtocolCapabilityContext,
): ProtocolCapabilities {
  const isGuardianActive = context.guardianStatus === "active";
  const canApplyAsGuardian =
    context.isWalletConnected && context.guardianStatus === "inactive";

  return {
    canBuyGovernanceTokens: context.isWalletConnected,
    canOpenProposalComposer: context.isWalletConnected,

    canCreateProposal:
      context.isWalletConnected && context.hasProposalThreshold,

    canApplyAsGuardian,

    canAccessGuardianOperations: context.isWalletConnected && isGuardianActive,

    canCreateVault:
      context.isWalletConnected &&
      isGuardianActive &&
      !context.isVaultCreationPaused,

    canExecuteStrategy:
      context.isWalletConnected &&
      isGuardianActive &&
      !context.isExecutionPaused,

    canOpenTreasuryOperations:
      context.isWalletConnected &&
      (context.isTreasuryOperator || context.isAdminOperator),

    canPauseVaultCreation:
      context.isWalletConnected && context.isEmergencyOperator,

    canResumeVaultCreation:
      context.isWalletConnected && context.isManagerOperator,

    canPauseVaultDeposits:
      context.isWalletConnected && context.isEmergencyOperator,

    canResumeVaultDeposits:
      context.isWalletConnected && context.isManagerOperator,

    canPauseRiskExecution:
      context.isWalletConnected && context.isEmergencyOperator,

    canResumeRiskExecution:
      context.isWalletConnected && context.isManagerOperator,

    canAccessAdminConsole:
      context.isWalletConnected &&
      (context.isAdminOperator ||
        context.isManagerOperator ||
        context.isEmergencyOperator),
    canSweepBondingTokens: context.isWalletConnected && context.hasBondingSweepRole,
    canWithdrawNonDaoAssets:
      context.isWalletConnected && context.hasTreasurySweepRole,
  };
}
