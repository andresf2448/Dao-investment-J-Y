export type ProtocolCapabilities = {
  canBuyGovernanceTokens: boolean;
  canCreateProposal: boolean;
  canApplyAsGuardian: boolean;
  canAccessGuardianOperations: boolean;
  canCreateVault: boolean;
  canExecuteStrategy: boolean;
  canOpenTreasuryOperations: boolean;
  canPauseVaultCreation: boolean;
  canResumeVaultCreation: boolean;
  canPauseVaultDeposits: boolean;
  canResumeVaultDeposits: boolean;
  canPauseRiskExecution: boolean;
  canResumeRiskExecution: boolean;
  canAccessAdminConsole: boolean;
};

export type ProtocolCapabilityContext = {
  isWalletConnected: boolean;
  hasProposalThreshold: boolean;
  guardianStatus:
    | "inactive"
    | "pending"
    | "active"
    | "rejected"
    | "resigned"
    | "banned";
  isVaultCreationPaused: boolean;
  isDepositsPaused: boolean;
  isExecutionPaused: boolean;
  isManagerOperator: boolean;
  isEmergencyOperator: boolean;
  isTreasuryOperator: boolean;
  isAdminOperator: boolean;
};

export function useProtocolCapabilities(): ProtocolCapabilities {
  const context: ProtocolCapabilityContext = {
    isWalletConnected: false,
    hasProposalThreshold: false,
    guardianStatus: "inactive",
    isVaultCreationPaused: false,
    isDepositsPaused: false,
    isExecutionPaused: false,
    isManagerOperator: false,
    isEmergencyOperator: false,
    isTreasuryOperator: false,
    isAdminOperator: false,
  };

  // TODO: reemplazar este contexto mock por datos reales desde hooks fuente:
  // - estado de wallet
  // - threshold de governance
  // - estado de guardian
  // - pausas del ProtocolCore
  // - pausa del RiskManager
  // - capacidades derivadas de acceso operativo

  return deriveCapabilities(context);
}

export function deriveCapabilities(
  context: ProtocolCapabilityContext
): ProtocolCapabilities {
  const isGuardianActive = context.guardianStatus === "active";
  const canApplyAsGuardian =
    context.isWalletConnected && context.guardianStatus === "inactive";

  return {
    canBuyGovernanceTokens: true,
    // TODO: derivar desde GenesisBonding.isFinalized para bloquear compras si el bonding fue finalizado.

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
  };
}